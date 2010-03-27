module xf.boxen.Main;

private {
	version (StackTracing) {
		import tango.core.tools.TraceExceptions;
	}
	
	import xf.boxen.Events;
	import xf.boxen.Rendering;
	import xf.boxen.Input;
	import xf.boxen.model.IPlayerController;
	import xf.boxen.model.ILevel;
	import xf.boxen.Vehicle;
	import Phys = xf.boxen.Phys;
	import xf.havok.Havok;
	import DebugDraw = xf.boxen.DebugDraw;

	import xf.Common;
	import xf.core.Registry : create;
	import xf.core.InputHub;
	import xf.core.JobHub;
	import xf.core.MessageHub;
	import xf.core.Message;

	import xf.game.Defs;
	import xf.game.GameObj;
	import xf.game.MainProcess;
	import xf.game.TimeHub;
	import xf.game.Event;
	import xf.game.EventQueue;
	import xf.game.GameObjEvents;
	import xf.game.LoginEvents;

	import xf.input.Input;
	
	import GameObjMngr = xf.game.GameObjMngr;
	import LoginMngr = xf.game.LoginMngr;
	import GameObjRegistry = xf.game.GameObjRegistry;
	import InteractionTracking = xf.game.InteractionTracking;
	import AuthStorage = xf.game.AuthStorage;

	import tango.core.Thread;
	import Integer = tango.text.convert.Integer;

	import xf.net.NetObj;
	
	version (Client) {
		import xf.net.LowLevelClient;
		import xf.net.GameClient;
		alias xf.net.GameClient.g_localPlayerId g_localPlayerId;

		import xf.game.TickTracker;
	}
	
	version (Server) {
		import xf.net.LowLevelServer;
		import xf.net.GameServer;
	}
	
	import xf.net.ControlEvents;
	import NetObjMngr = xf.net.NetObjMngr;

	import xf.utils.Meta : fn2dg;
	import xf.utils.GfxApp;
	import xf.utils.SimpleCamera;

	import xf.mem.ChunkQueue;
	import xf.utils.GlobalThreadDataRegistry;
	import xf.utils.LocalArray;
	import xf.mem.StackBuffer;

	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.CoordSys;

	import tango.io.Stdout;
	import tango.stdc.stdio : printf;
}


version (Client) {
	GameClient	client;
} else {
	GameServer	server;
}

ILevel		level;
EventQueue	eventQueue;


struct Interaction {
	objId id1;
	objId id2;
}

__thread ChunkQueue!(Interaction)							interactionQueue;
mixin GlobalThreadDataRegistryM!(typeof(interactionQueue)*)	InteractionQueueRegistry;
ChunkQueue!(Interaction)									serializedInteractions;



union IdTicks {
	static IdTicks opCall(objId id, ushort ticks) {
		IdTicks res = void;
		res.id = id;
		res.ticks = ticks;
		return res;
	}
	
	struct {
		objId	id;
		ushort	ticks;
	}

	u32	packed;
}
static assert (4 == IdTicks.sizeof);


extern (C) void boxen_processGameObjInteraction(void* o1, void* o2) {
	final id1 = (cast(GameObj)cast(Object)o1).id();
	final id2 = (cast(GameObj)cast(Object)o2).id();

	assert (NetObjMngr.g_netObjects[id1] !is null);
	assert (NetObjMngr.g_netObjects[id2] !is null);

	if (id1 != id2) {
		if (InteractionQueueRegistry.register(&interactionQueue)) {
			interactionQueue.clear();
		}
		
		interactionQueue.pushBack(Interaction(id1, id2));
	}
}


struct InteractionsFound {
	uword	queueLen;
	objId[]	queue;
	
	int opApply(int delegate(ref objId) dg) {
		foreach (ref x; queue[0..queueLen]) {
			if (int r = dg(x)) return r;
		}
		return 0;
	}
}


InteractionsFound findIteractions(objId id0_, objId[] queue) {
	assert (queue.length >= NetObjMngr.g_netObjects.length);
	
	uword queueLen = 1;
	queue[0] = id0_;
	AuthStorage.binStorage[id0_].setVisitedFlag();

	for (uword i = 0; i < queueLen; ++i) {
		final id = queue[i];
		final bs = &AuthStorage.binStorage[id];
		assert (true == bs.readVisitedFlag());

		foreach (rawIt; *bs) {
			final it = cast(IdTicks*)&rawIt;
			final id2 = it.id;
			final bs2 = &AuthStorage.binStorage[id2];
			if (false == bs2.readVisitedFlag()) {
				bs2.setVisitedFlag();
				queue[queueLen++] = id2;
			}
		}
	}

	return InteractionsFound(queueLen, queue);
}


void cleanupInteractionsFound(InteractionsFound* intf) {
	foreach (id; *intf) {
		final bs = &AuthStorage.binStorage[id];
		assert (true == bs.readVisitedFlag());
		bs.unsetVisitedFlag();
		assert (false == bs.readVisitedFlag());
	}
}



void refreshInteractions() {
	foreach (thi, thq; InteractionQueueRegistry.each) {
		foreach (i, x; *thq) {
			serializedInteractions.pushBack(x);
		}
	}
	
	InteractionQueueRegistry.clearRegistrations();

	foreach (x; serializedInteractions) {
		{
			final id1 = x.id1;
			final id2 = x.id2;
			
			final bs = &AuthStorage.binStorage[id1];
			bs.iterOrAdd((ref u32 i) {
				final it = cast(IdTicks*)&i;
				if (it.id == id2) {
					it.ticks = Phys.contactPersistence;
					return true;
				}
				return false;
			}, IdTicks(id2, Phys.contactPersistence).packed);
		}

		{
			final id2 = x.id1;
			final id1 = x.id2;
			
			final bs = &AuthStorage.binStorage[id1];
			bs.iterOrAdd((ref u32 i) {
				final it = cast(IdTicks*)&i;
				if (it.id == id2) {
					it.ticks = Phys.contactPersistence;
					return true;
				}
				return false;
			}, IdTicks(id2, Phys.contactPersistence).packed);
		}
	}

	serializedInteractions.clear();

	foreach (id_, obj; NetObjMngr.g_netObjects) {
		if (obj is null) {
			continue;
		}
		
		objId id = cast(objId)id_;
		final bs = &AuthStorage.binStorage[id];

		bs.updateRemove((ref uint rawIt) {
			final it = cast(IdTicks*)&rawIt;
			if (it.ticks > 0) {
				--it.ticks;
				return false;
			} else {
				return true;
			}
		});
	}

	/+scope stack = new StackBuffer();
	final arr = LocalArray!(objId)(NetObjMngr.g_netObjects.length, stack);
	scope (success) arr.dispose();

	foreach (id_, obj; NetObjMngr.g_netObjects) {
		if (obj is null) {
			continue;
		}

		objId id = cast(objId)id_;
		printf("Obj %d interactions:", cast(int)id);

		iterInteractions(id, arr.data, (objId id2) {
			printf(" %d", cast(int)id2);
		});
		
		printf("\n");
	}+/
}


void findTouchGroupInfo(
		ref InteractionsFound inter,
		out bool singleOwner, out bool singleAuth, out bool containsServerAuth,
		out playerId theAuth,
		out playerId theOwner
) {
	singleOwner = true;
	singleAuth = true;
	containsServerAuth = false;
	theAuth	= NoAuthority;
	theOwner = NoAuthority;

	foreach (id; inter) {
		final t = NetObjMngr.g_netObjects[id];
		
		if (t.realOwner != NoAuthority) {
			if (ServerAuthority == t.realOwner) {
				containsServerAuth = true;
			} else {
				if (NoAuthority == theOwner) {
					theOwner = t.realOwner;
				} else {
					if (theOwner != t.realOwner) {
						singleOwner = false;
					}
				}
			}
		}
		
		if (t.authOwner != NoAuthority) {
			if (ServerAuthority == t.authOwner) {
				containsServerAuth = true;
			} else {
				if (NoAuthority == theAuth) {
					theAuth = t.authOwner;
				} else {
					if (theAuth != t.authOwner) {
						singleAuth = false;
					}
				}
			}
		}
	}
}


void updateAuthority() {
	foreach (id_, obj; NetObjMngr.g_netObjects) {
		if (obj is null) {
			continue;
		}
		obj.authValid = false;
		obj.keepServerUpdated = false;
	}

	scope stack = new StackBuffer();
	final interactionsScratch = LocalArray!(objId)(NetObjMngr.g_netObjects.length, stack);
	scope (success) interactionsScratch.dispose();


	foreach (id_, obj; NetObjMngr.g_netObjects) {
		if (obj is null) {
			continue;
		}

		InteractionsFound intf = findIteractions(obj.id, interactionsScratch.data);
		findTouchingGroupAuth(obj, intf);
		cleanupInteractionsFound(&intf);
	}

	foreach (id_, obj; NetObjMngr.g_netObjects) {
		if (obj is null) {
			continue;
		}

		version (Client) {
			if (g_localPlayerId == obj.authOwner || obj.authRequested) {
				obj.keepServerUpdated = true;
			}
		} else if (obj.prevAuthOwner != obj.authOwner) {
			OverrideAuthority(obj.id, obj.authOwner).immediate;
			obj.setPrevAuthOwner(obj.authOwner);
		}
	}
}


bool isGroupAsleep(ref InteractionsFound intf) {
	foreach (t; intf) {
		final obj = NetObjMngr.g_netObjects[t];
		if (obj.isActive) {
			return false;
		}
	}
	return true;
}


version (Server) void findTouchingGroupAuth(NetObj obj, ref InteractionsFound intf) {
	if (obj.authValid) return;
	
	bool singleOwner, singleAuth, containsServerAuth;
	playerId theAuth, theOwner;
	findTouchGroupInfo(intf, singleOwner, singleAuth, containsServerAuth, theAuth, theOwner);

	alias NetObjMngr.g_netObjects _netObjects;
	
	void setAllAuthTo(playerId auth) {
		foreach (ref t; intf) {
			_netObjects[t].setAuthOwner(auth);
		}
	}
	
	void validateAllAuth() {
		foreach (ref t; intf) {
			_netObjects[t].authValid = true;
		}
	}
	
	if (singleOwner && singleAuth && containsServerAuth && NoAuthority == theOwner) {
		// a group of non-owned objects under the server auth
		// this is analogous to giving out client-side authority when the objects come to rest
		if (isGroupAsleep(intf)) {
			setAllAuthTo(NoAuthority);
		}
	} else if (singleOwner && !singleAuth && !containsServerAuth && theOwner != NoAuthority) {
		// if there's an important object touching a bunch of objects owned by other players
		// but none of them is important as well, give control of all the non-important objects
		// to the player owning the important one
		setAllAuthTo(theOwner);
	} else if (!singleOwner || !singleAuth || containsServerAuth) {
		// multiple owners, multiple temporary owners or some objects are controlled by the server
		
		bool canGiveBack = false;
		if (singleOwner && singleAuth && theOwner != NoAuthority) {
			// if all objects in the group are owned by one player, check if they can be given back
			canGiveBack = true;
			const float maxError = 0.15f;//.5f;

			foreach (t; intf) {
				final go = _netObjects[t];
				assert (go !is null);
				
				if (go.authOwner != NoAuthority) {
					void*[maxStates] foundStateData_;
					void*[] foundStateData = foundStateData_[0..go.numNetStateTypes];
					NetObjMngr.LastPlayerSnapshotData.find(theOwner, t, foundStateData);

					float err = 0.0f;
					char* reason = "";

					final objInfo = go.getNetObjInfo();
					foreach (stateI, clientState; foundStateData) {
						final stateInfo = objInfo.netStateInfo[stateI];

						if (clientState is null) {
							if (stateInfo.isCritical) {
								reason = "Critical state not found.";
								goto cantGiveBack;
							} else {
								continue;
							}
						}

						void* serverState = NetObjMngr.getStateStoredForObjectAtTick(
							t, cast(ushort)stateI, timeHub.currentTick
						);

						if (serverState is null) {
							reason = "State not found at server-side.";
							goto cantGiveBack;
						}

						err += stateInfo.calcDifference(
							clientState, serverState
						);

						if (err > maxError) {
							if (stateInfo.stringize !is null) {
								char[] delegate() d1, d2;
								d1.funcptr = stateInfo.stringize;
								d2.funcptr = stateInfo.stringize;
								d1.ptr = serverState;
								d2.ptr = clientState;

								auto s1 = d1().dup;
								auto s2 = d2();
								
								/+printf(
									"Critical state: %d. Server:\n  %.*s\nClient:\n  %.*s\n",
									cast(int)stateI,
									s1,
									s2
								);+/

								delete s1;
							}
							goto cantGiveBack;
						}
					}

					if (err > maxError) {
					cantGiveBack:
						/+printf(
							"Can't give back object %d: %s Error = %f\n",
							cast(int)t,
							reason,
							err
						);+/
						canGiveBack = false;
						break;
					}
				}
			}
		}
		
		if (canGiveBack) {
			// the player objects are within a tolerance threshold to the server state, give them all
			// to the player
			setAllAuthTo(theOwner);
		} else {
			// otherwise, server takes control
			setAllAuthTo(ServerAuthority);
		}
	} else if (theOwner != NoAuthority) {
		// the objects are owned by one player, plus there may be some without owners,
		// give them all to the player
		setAllAuthTo(theOwner);
	} else if (theAuth != NoAuthority) {
		// the objects are temporarily owned by one player, plus there may be some without owners,
		// give them all to the player
		setAllAuthTo(theAuth);
	} else {
		// do nothing, there is no auth or owner for this group
		assert (NoAuthority == theAuth);
		assert (NoAuthority == theOwner);
	}
	
	// mark objects in the touch group as processed
	validateAllAuth;
}

// ----------------------------------------------------------------

version (Client) void findTouchingGroupAuth(NetObj obj, ref InteractionsFound intf) {
	if (obj.authValid) return;

	alias NetObjMngr.g_netObjects _netObjects;

	void requestAllAuth() {
		foreach (t; intf) {
			if (!_netObjects[t].authRequested) {
				_netObjects[t].givingUpAuth = false;
				_netObjects[t].authRequested = true;
				printf("requesting auth of obj %d"\n, cast(int)t);
				RequestAuthority(t).immediate;
			}
		}
	}
	
	void giveUpAllAuth() {
		foreach (t; intf) {
			if (!_netObjects[t].givingUpAuth) {
				_netObjects[t].givingUpAuth = true;
				_netObjects[t].authRequested = false;
				printf("giving up auth of obj %d"\n, cast(int)t);
				GiveUpAuthority(t).immediate;
			}
		}
	}
	
	void validateAllAuth() {
		foreach (t; intf) {
			_netObjects[t].authValid = true;
		}
	}

	bool singleOwner, singleAuth, containsServerAuth;
	playerId theAuth, theOwner;
	findTouchGroupInfo(intf, singleOwner, singleAuth, containsServerAuth, theAuth, theOwner);
	
	bool touchesLocallyOwned = false;
	foreach (t; intf) {
		if (g_localPlayerId == _netObjects[t].realOwner) {
			touchesLocallyOwned = true;
		}
	}
	
	if (touchesLocallyOwned) {
		// try to take control over all the objects
		requestAllAuth;
	} else {
		bool groupAsleep = isGroupAsleep(intf);
		
		if (singleAuth && g_localPlayerId == theAuth) {
			// we're the only client that has any auth over objects in this group
			
			if (groupAsleep) {
				// we control the objects but since they fell asleep, we don't care anymore
				// give them back to the server
				giveUpAllAuth;
			}
		}
		
		if (!groupAsleep) {
			// if the group is active and we've requested control over some of its objects,
			// we'll also try to take control over the others, since the server might want
			// to give them to us and we want to keep it updated with out vision of their state
			
			bool touchesLocalAuth = false;
			foreach (t; intf) {
				if (g_localPlayerId == _netObjects[t].authOwner || _netObjects[t].authRequested) {
					touchesLocalAuth = true;
					break;
				}
			}
			
			if (touchesLocalAuth) {
				requestAllAuth;
			}
		}
	}
	
	// mark objects in the touch group as processed
	validateAllAuth;
}
// ----------------------------------------------------------------

NetObj getNetObj(objId id) {
	if (id < NetObjMngr.g_netObjects.length) {
		return NetObjMngr.g_netObjects[id];
	} else {
		return null;
	}
}


version (Server) {
	private void handleRequestAuthority(RequestAuthority e) {
		// TODO: security
		if (auto netObj = getNetObj(e.obj)) {
			if (NoAuthority == netObj.authOwner) {
				netObj.setAuthOwner(e.wishOrigin);
			} else {
				// TODO: tell the client they couldn't get the auth?
			}
		}
	}


	private void handleGiveUpAuthority(GiveUpAuthority e) {
		// TODO: security
		if (auto netObj = getNetObj(e.obj)) {
			if (e.wishOrigin == netObj.authOwner) {
				netObj.setAuthOwner(NoAuthority);
			}
		}
	}


	// ----

	protected void handleAcquireObject(AcquireObject e) {
		// TODO: security
		if (auto netObj = getNetObj(e.obj)) {
			if (NoAuthority == netObj.realOwner || e.wishOrigin == netObj.realOwner) {
				printf("AcquireObject: success"\n);
				netObj.setRealOwner = e.wishOrigin;
				ObjectOwnershipChange(e.obj, e.wishOrigin).immediate;
			} else {
				printf("AcquireObject: refused"\n);
				RefuseObjectAcquisition(e.obj).filter((playerId pid) {
					return pid == e.wishOrigin;
				}).immediate;
			}
		}
	}


	protected void handleReleaseObject(ReleaseObject e) {
		// TODO: security
		if (auto netObj = getNetObj(e.obj)) {
			if (e.wishOrigin == netObj.realOwner) {
				netObj.setRealOwner = NoAuthority;
				ObjectOwnershipChange(e.obj, NoAuthority).immediate;
			}
			if (e.wishOrigin == netObj.authOwner) {
				netObj.setAuthOwner(NoAuthority);
			}
		}
	}
}

// ----------------------------------------------------------------

version (Client) {
	private void handleOverrideAuthority(OverrideAuthority e) {
		printf("OverrideAuthority %d -> %d: ", cast(int)e.obj, cast(int)e.player);
		if (auto netObj = getNetObj(e.obj)) {
			printf("OK"\n);
			netObj.givingUpAuth = false;

			// There was a conflict, but we requested the auth anyway, so let's keep
			// updating the player with our state so the conflict may be resolved
			// and hopefully we get the object back
			if (e.player != ServerAuthority) {
				netObj.authRequested = false;
			}
			
			netObj.setAuthOwner(e.player);
			return;
		}
		printf("FAIL"\n);
	}

	protected void handleObjectOwnershipChange(ObjectOwnershipChange e) {
		printf("ObjectOwnershipChange %d -> %d: ", cast(int)e.obj, cast(int)e.player);
		if (auto netObj = getNetObj(e.obj)) {
			printf("OK"\n);
			netObj.setRealOwner = e.player;
		} else {
			printf("FAIL"\n);
		}
	}
	
	
	protected void handleRefuseObjectAcquisition(RefuseObjectAcquisition e) {
		// nothing here
	}
}

// ----------------------------------------------------------------

void updateGame() {
	version (Server) {
		server.receiveData();
		updateAuthority();
		
		timeHub.advanceTick(1);
		eventQueue.advanceTick(1);
		while (eventQueue.moreEvents) {
			Event ev = eventQueue.nextEvent;
			ev.handle();
			ev.unref();
		}

		level.update(timeHub.secondsPerTick);
		Phys.update(timeHub.secondsPerTick);
		GameObjMngr.update(timeHub.secondsPerTick);
		refreshInteractions();

		NetObjMngr.storeNetObjStates(timeHub.currentTick);

		for (playerId i = 0; i < maxPlayers; ++i) {
			if (LoginMngr.PlayerInfo.loggedIn[i]) {
				NetObjMngr.updateStateImportances(i);
				final writer = server.getWriterForPlayer(i);
				writer.bsw.write(false);		// end of events
				static assert (uint.sizeof == tick.sizeof);
				writer.bsw.write(cast(uint)timeHub.currentTick);
				NetObjMngr.writeStates(
					i,
					timeHub.currentTick,
					(NetObj) {
						return 1.0f;		// importance
					},
					writer
				);
			}
		}
		server.sendData();
		debug printf(`tick: %d`\n, timeHub.currentTick);
	} else {
		client.receiveData();

		updateAuthority();

		.synchronizeNetworkTicks(client);

		if (timeHub.currentTick > client.lastTickReceived) {
			timeHub.trimHistory(timeHub.currentTick - client.lastTickReceived);
		}

		timeHub.incInputTick();
		_playerInputMap.update();
		_playerInputSampler.sample();

		timeHub.advanceTick(1);
		eventQueue.advanceTick(1);
		while (eventQueue.moreEvents) {
			Event ev = eventQueue.nextEvent;
			ev.handle();
			ev.unref();
		}

		// unless rollback and catch-up gets implemented
		assert (timeHub.currentTick == timeHub.inputTick);

		level.update(timeHub.secondsPerTick);
		Phys.update(timeHub.secondsPerTick);
		GameObjMngr.update(timeHub.secondsPerTick);
		refreshInteractions();

		if (client.connectedAndReady) {
			NetObjMngr.storeNetObjStates(timeHub.currentTick);

			NetObjMngr.updateStateImportances();
			final writer = client.getWriter();
			//Stdout.formatln("Bits in writer before states: {}.\n{}", writer.bsw.writeOffset, writer.bsw.toString);
			writer.bsw.write(false);		// end of events
			static assert (uint.sizeof == tick.sizeof);
			writer.bsw.write(cast(uint)timeHub.currentTick);
			writer.bsw.flush();
			//Stdout.formatln("Sending:\n{}", writer.bsw.toString);
			NetObjMngr.writeStates(
				timeHub.currentTick,
				(NetObj) {
					return 1.0f;		// importance
				},
				writer
			);
		}
		
		client.sendData();
	}

	// tmp HACK
	if (timeHub.currentTick > 100) {
		NetObjMngr.dropStatesOlderThan(cast(tick)(timeHub.currentTick - 100));
	}

	NetObjMngr.swapObjDataMem();
}


version (Server) {
	void createGameWorld() {
		GameObjMngr.createGameObj("PlayerController", vec3(2, 0, -3), 5);
		GameObjMngr.createGameObj("PlayerController", vec3(-2, 0, -3), 6);

		for (int i = 0; i < 50; ++i) {
			GameObjMngr.createGameObj("DebrisObject", vec3(0, 0.5 + i, -6), NoAuthority);
		}
		
		GameObjMngr.createGameObj("Tank", vec3(-4, 0, -14), NoAuthority);
		GameObjMngr.createGameObj("Tank", vec3(4, 0, -14), NoAuthority);
	}


	GameObj[maxPlayers] 	_playerControllers;
	IVehicle[maxPlayers]	_controlledVehicle;
	playerId				_observedPlayer = playerId.max;


	void handlePlayerLogin(playerId pid) {
		final obj = GameObjMngr.createGameObj("PlayerController", vec3.zero, pid);

		_observedPlayer = pid;

		AssignController(
			obj.id
		).filter((playerId id) { return id == pid; }).immediate();

		_playerControllers[pid] = obj;
	}
}

version (Client) {
	IVehicle	_controlledVehicle;
}


void handleInputWish(InputWish e) {
	version (Server) {
		debug if (e.action) printf(`handling input from %d meant for tick %d (at tick %d)`\n, cast(int)e.wishOrigin, e.eventTargetTick, timeHub.currentTick);

		tick targetTick = e.eventTargetTick;
		tick recvTick = e.receptionTick;
		const uint desiredOffsetTicks = 1;

		// the event should have arrived this many ticks earlier
		int offset = recvTick + desiredOffsetTicks - targetTick;
		
		//printf(`Wish should've arrived %d ticks %s`\n, offset > 0 ? offset : -offset, offset > 0 ? `earlier`.ptr : `later`.ptr);
		TuneClientTiming(e.wishOrigin, offset).immediate;
	}

	if (e.eventTargetTick < timeHub.currentTick) {
		Stdout.formatln("Input wish arrived too late by {} ticks. Ignoring.", timeHub.currentTick - e.eventTargetTick);
		return;
	}
	
	float b2f(byte b) {
		return cast(float)b / 127.f;
	}

	bool useAction = (e.action & 2) != 0;
	bool shootAction = (e.action & 1) != 0;
	auto pid = e.wishOrigin;

	version (Server) {
		auto ctrl = cast(IPlayerController)_playerControllers[pid];
		auto vehicle = _controlledVehicle[pid];
	} else {
		auto ctrl = cast(IPlayerController)_playerController;
		auto vehicle = _controlledVehicle;
		assert (pid == g_localPlayerId);
	}

	if (vehicle is null) {
		float strafe = b2f(e.strafe);
		float fwd = b2f(e.thrust);

		/+version (Client) Stdout.newline().newline();
		Stdout.formatln(
			"Applying input {} (lr:{}, ud:{}) to ctrl @ {} @ tick {}",
			e.eventTargetTick,
			strafe,
			fwd,
			ctrl.worldPosition,
			timeHub.currentTick
		);+/

		// writeln("ctrl position: ", pos.x, " ", pos.y, " ", pos.z)
		float moveSpeed = 1.f;
		ctrl.move(vec3(strafe * moveSpeed, 0, fwd * moveSpeed));

		float rotSpeed = 10.f;
		float yawRot = e.rot.x * timeHub.secondsPerTick();
		float pitchRot = e.rot.y * timeHub.secondsPerTick();
		ctrl.yawRotate(yawRot * rotSpeed);
		ctrl.pitchRotate(pitchRot * rotSpeed);

		if (useAction) {
			const float maxDist = 3.0f;

			final rayFrom	= vec3.from(ctrl.worldPosition) + vec3.unitY * 1.5;
			final rayTo		= rayFrom + ctrl.cameraRotation.xform(-vec3.unitZ) * maxDist;

			Object hit;
			
			Phys.world.markForRead();
			scope (success) Phys.world.unmarkForRead();

			Phys.castRay(rayFrom, rayTo,
				(hkpWorldObject wo, float dist, hkVector4*, float* earlyOut) {
					void* ud;
					if (
							wo._impl
						&&	(ud = cast(void*)wo.getUserData()) !is null
						&&	ud !is cast(void*)cast(Object)ctrl
					) {
						*earlyOut = dist;
						hit = cast(Object)ud;
					}
				}
			);

			if (hit) {
				Stdout.formatln("\n\nHit a {}!\n", hit.classinfo.name);
			}

			version (Client) {
				if (auto vehicle = cast(IVehicle)hit) {
					EnterVehicleRequest((cast(GameObj)hit).id, -1).immediate();
				}
			}
		}
	} else {
		if (useAction) {
			version (Client) {
				LeaveVehicleRequest().immediate();
			}
		} else if (isVehiclePilot(vehicle, pid)) {
			if (e.action & e.Shoot) {
				vehicle.shoot;
			}

			float fwd = 0.f;
			float turn = 0.f;
			
			if (e.thrust > 0) {
				fwd += 25.f;
			} else if (e.thrust < 0) {
				fwd -= 25.f;
			}
			
			if (e.strafe > 0) {
				turn += 25.f;
			} else if (e.strafe < 0) {
				turn -= 25.f;
			}
			
			vehicle.move(turn, 0, fwd);
			
			float rotSpeed = 10.f;
			float yawRot = e.rot.x * timeHub.secondsPerTick();
			float pitchRot = e.rot.y * timeHub.secondsPerTick();
			vehicle.yawRotate(yawRot * rotSpeed);
			vehicle.pitchRotate(pitchRot * rotSpeed);
		}
	}
}


private void setVehiclePilot(IVehicle v, playerId pid) {
	(cast(NetObj)v).setRealOwner(pid);
}


bool isVehiclePilot(IVehicle v, playerId pid) {
	return v.getPlayerAtSeat(0) == pid;
}


private void leaveVehicle(playerId pid, vec3 pos) {
	version (Server) {
		final v = _controlledVehicle[pid];
	} else {
		final v = _controlledVehicle;
	}
	
	if (v !is null) {
		if (pid == v.getPlayerAtSeat(0)) {
			setVehiclePilot(v, NoPlayer);
		}
		
		v.removePlayerFromSeat(pid);
		/+pd.controller.teleport(pos);
		pd.currentVehicle = null;
		pd.camera.parent = pd.controller;+/

		version (Server) {
			_controlledVehicle[pid] = null;
		} else if (g_localPlayerId == pid) {
			_controlledVehicle = null;
		}
	}
}


version (Server) void handleEnterVehicleRequest(EnterVehicleRequest e) {
	final playerId pid = e.wishOrigin;

	printf("EnterVehicleRequest; pid=%d obj=%d seat=%d"\n, cast(int)pid, cast(int)e.obj, cast(int)e.seat);
	
	if (auto v = cast(IVehicle)getNetObj(e.obj)) {
		//if (v.alive) {
			final curV = _controlledVehicle[pid];
			if (curV is v || curV is null) {
				int seat = v.setPlayerAtSeat(pid, e.seat);
				if (seat != -1) {
					EnterVehicleOrder(pid, e.obj, cast(byte)seat).immediate;
				} else {
					printf("EnterVehicleRequest: seat occupied"\n);
				}
			} else {
				printf("EnterVehicleRequest: invalid vehicle"\n);
			}
		/+} else {
			printf("EnterVehicleRequest: the vehicle is destroyed"\n);
		}+/
	} else {
		printf("EnterVehicleRequest: invalid obj id"\n);
	}
}


version (Server) void handleLeaveVehicleRequest(LeaveVehicleRequest e) {
	printf("LeaveVehicleRequest: pid = %d"\n, cast(int)e.wishOrigin);
	
	final playerId pid = e.wishOrigin;
	final v = _controlledVehicle[pid];
	
	if (v !is null) {
		vec3 leavePos = void;
		if (v.getSafeLeavePosition(&leavePos)) {
			LeaveVehicleOrder(pid, leavePos).immediate;
		}
	}
}


// client- and server-side
void handleEnterVehicleOrder(EnterVehicleOrder e) {
	printf("EnterVehicleOrder"\n);
	
	final v = cast(IVehicle)getNetObj(e.obj);
	v.setPlayerAtSeat(e.player, e.seat);

	version (Server) {
		_controlledVehicle[e.player] = v;
	} else {
		if (g_localPlayerId == e.player) {
			_controlledVehicle = v;
		}
	}

	if (0 == e.seat) {
		setVehiclePilot(v, e.player);
	}

	/+auto vehicle = cast(Vehicle)idToGameObj(e.obj);
	playerData.camera.parent = vehicle.getSeatSgNode(e.seat);
	playerData.controller.destroyPhysics();
	playerData.controller.showGraphics(false);+/
}


// client- and server-side
void handleLeaveVehicleOrder(LeaveVehicleOrder e) {
	printf("LeaveVehicleOrder: pid=%d"\n, cast(int)e.player);
	leaveVehicle(e.player, e.pos);

	/+playerData.controller.createPhysics();
	if (serverSide || e.player != localPlayerId) {
		playerData.controller.showGraphics(true);
	}
	playerData.camera.parent = playerData.controller;+/
}




class PlayerInputReader : InputReader {
	void handle(PlayerInput* i) {
		const double delaySeconds = 0.04;
		tick targetTick = cast(tick)(timeHub.inputTick + timeHub.secondsToTicks(delaySeconds));
		
		ubyte action = 0;
		if (i.shoot) {
			action |= InputWish.Shoot;
		}
		if (i.use) {
			action |= InputWish.Use;
		}
		
		InputWish(i.thrust, i.strafe, i.rot, action).atTick(targetTick);
	}
	
	this() {
		registerReader!(PlayerInput)(&this.handle);
	}
}

version (Client) {
	PlayerInputMap		_playerInputMap;
	PlayerInputSampler	_playerInputSampler;	
	GameObj				_playerController;

	void handleAssignController(AssignController e) {
		_playerController = GameObjMngr.getObj(e.id);
		assert (_playerController !is null);
		Stdout.formatln("Got a controller assigned.");

		_playerInputSampler
			.outgoing.addReader(new PlayerInputReader);		// start reading inputs			
	}
}


struct login {
	static cstring nick = "Test";
}


version (Client) class QueueTrimmer : TickTracker {
	void advanceTick(uint ticks) {}
	
	void trimHistory(uint ticks) {
		eventQueue.trimHistory(ticks);
	}
	
	void rollback(uint ticks) {}
}


class TestApp : GfxApp {
	SimpleCamera			camera;
	SimpleKeyboardReader	keyboard;
	char[]					netAddr;


	this(char[][] args) {
		if (args.length > 0) {
			netAddr = args[0];
		} else {
			version (Client) {
				netAddr = "127.0.0.1";
			} else {
				netAddr = "0.0.0.0";
			}
		}
	}
	

	version (Client) override void configureWindow(Window wnd) {
		super.configureWindow(wnd);
		wnd.title = "Boxen Tech #1";
		wnd.interceptCursor = true;
		wnd.showCursor = false;
	}
	

	void initialize() {
		timeHub.overrideTicksPerSecond(60);
		
		camera = new SimpleCamera(vec3(0, 2, 5), 0, 0, window.inputChannel);
		keyboard = new SimpleKeyboardReader(window.inputChannel);
		
		camera.movementSpeed = vec3.one * 40.f;

		DebugDraw.initialize(renderer, window);
		version (Server) {
			window.title = "Boxen server";
		}

		version (Server) {
			eventQueue = new EventQueue;
		} else {
			eventQueue = new LoggingEventQueue;
		}

		char[]	netBackend = "ENet";
		u16		port = 8000;
		
		void queueEvent(Event ev, tick target) {
			/+Stdout.formatln(
				"Submitting {} for tick {} (current = {}).",
				ev.classinfo.name,
				target,
				timeHub.currentTick
			);+/
			eventQueue.addEvent(ev, cast(int)target - timeHub.currentTick);
		}
		Order.addSubmitHandler(&queueEvent);
		Wish.addSubmitHandler(&queueEvent);
		Local.addSubmitHandler(&queueEvent);

		GameObjMngr.initialize();

		Phys.initialize();
		InteractionTracking.initialize(Phys.world);
		.level = create!(ILevel).named("TestLevel")();

		version (Server) {
			RequestAuthority.addHandler(fn2dg(&handleRequestAuthority));
			GiveUpAuthority.addHandler(fn2dg(&handleGiveUpAuthority));
			AcquireObject.addHandler(fn2dg(&handleAcquireObject));
			ReleaseObject.addHandler(fn2dg(&handleReleaseObject));

			LoginMngr.initialize();
			createGameWorld();
			
			server = new GameServer((
				create!(LowLevelServer).named(netBackend~"Server")(32)
			).start(netAddr, port));

			server.receiveStateSnapshot = fn2dg(&NetObjMngr.receiveStateSnapshot);

			EnterVehicleRequest.addHandler(fn2dg(&handleEnterVehicleRequest));
			LeaveVehicleRequest.addHandler(fn2dg(&handleLeaveVehicleRequest));
		} else {
			timeHub.addTracker(new QueueTrimmer);

			OverrideAuthority.addHandler(fn2dg(&handleOverrideAuthority));
			ObjectOwnershipChange.addHandler(fn2dg(&handleObjectOwnershipChange));
			RefuseObjectAcquisition.addHandler(fn2dg(&handleRefuseObjectAcquisition));

			_playerInputMap = new PlayerInputMap(inputHub.mainChannel);
			_playerInputMap.outgoing.addReader(_playerInputSampler = new PlayerInputSampler);

			AssignController.addHandler(fn2dg(&handleAssignController));
			
			client = new GameClient((
				create!(LowLevelClient).named(netBackend~"Client")()
			).connect(0, netAddr, port));

			client.receiveStateSnapshot = fn2dg(&NetObjMngr.receiveStateSnapshot);
		}

		EnterVehicleOrder.addHandler(fn2dg(&handleEnterVehicleOrder));
		LeaveVehicleOrder.addHandler(fn2dg(&handleLeaveVehicleOrder));
		
		int playerNameId = 1;		// for further login requests when the name is already used
		
		version (Server) {
			server.setDefaultWishMask((Wish w) { return cast(LoginRequest)w !is null; });

			LoginAccepted.addHandler((LoginAccepted e) {
				handlePlayerLogin(e.pid);
				server.setWishMask(e.pid, null);
				server.setStateMask(e.pid, true);
			});
			
			KickPlayer.addHandler((KickPlayer e) {
				server.kickPlayer(e.pid);
			});
			
			server.registerDisconnectionHandler((playerId pid) {
				PlayerLogout(pid).atTick(0);
			});
		} else {
			client.registerConnectionHandler({
				Stdout.formatln("Sending a LoginRequest wish.");
				LoginRequest(login.nick).immediate;
			});
			
			LoginRejected.addHandler((LoginRejected e) {
				LoginRequest(login.nick ~ Integer.toString(++playerNameId)).immediate;		// TODO
			});
			
			LoginAccepted.addHandler((LoginAccepted e) {
				Stdout.formatln("Login accepted!");
				client.setLocalPlayerId(e.pid);
			});
		}

		InputWish.addHandler(fn2dg(&handleInputWish));

		jobHub.addRepeatableJob(&update, 60.f);
	}


	void update() {
		updateGame();
		if (keyboard.keyDown(KeySym.c)) {
			keyboard.setKeyState(KeySym.c, false);
			useColors ^= true;
		}
	}


	bool useColors = true;


	static vec4[] playerColors = [
		{ r: 0.1f, g: 1.0f, b: 0.2f, a: 1.0f },
		{ r: 0.1f, g: 0.2f, b: 1.0f, a: 1.0f },
		{ r: 0.7f, g: 0.9f, b: 0.2f, a: 1.0f },
		{ r: 0.6f, g: 0.2f, b: 0.9f, a: 1.0f }
	];


	override void render() {
		final renderList = renderer.createRenderList();
		assert (renderList !is null);
		scope (success) renderer.disposeRenderList(renderList);

		//Stdout.formatln("Rendering {} meshes.", meshes.length);
		for (uword i = 0; i < meshes.length; ++i) {
			final mesh = meshes.mesh[i];
			final bin = renderList.getBin(mesh.effect);
			final efInst = mesh.effectInstance;

			auto data = bin.add(efInst);
			mesh.toRenderableData(data);

			final obj = cast(NetObj)cast(Object)GameObjMngr.getObj(meshes.offsetFrom[i]);

			final auth = obj.authOwner();
			vec4 tintColor = vec4.one;

			if (useColors) {
				if (NoAuthority == auth) {
					tintColor = vec4.one;
				} else if (ServerAuthority == auth) {
					tintColor = vec4(1.0f, 0.0f, 0.0f, 1.0f);
				} else {
					tintColor = playerColors[auth % $];
				}

				if (!obj.isActive) {
					tintColor *= 0.5f;
				}
			}
			
			efInst.setUniform("FragmentProgram.tintColor", tintColor);

			data.coordSys =	meshes.offset[i] in CoordSys(
				obj.worldPosition,
				obj.worldRotation
			);
			data.scale = meshes.scale[i];
		}

		version (Server) {
			final observedCtrl =
				_observedPlayer != playerId.max
					? cast(IPlayerController)_playerControllers[_observedPlayer]
					: null;
		} else {
			final observedCtrl = cast(IPlayerController)_playerController;
		}

		if (observedCtrl !is null) {
			final ctrlCS = CoordSys(observedCtrl.worldPosition, observedCtrl.cameraRotation);
			final offCamCS = CoordSys(vec3fi[0, 2.2, 2.2], quat.identity) in ctrlCS;
			DebugDraw.setWorldToView(offCamCS.inverse.toMatrix);
		} else {
			DebugDraw.setWorldToView(mat4.identity);
		}

		renderList.sort();
		renderer.framebuffer.settings.clearColorValue[0] = vec4(0.1, 0.1, 0.1, 1.0);
		renderer.clearBuffers();
		renderer.render(renderList);
	}
}


void main(char[][] args) {
	(new TestApp(args[1..$])).run;
}
