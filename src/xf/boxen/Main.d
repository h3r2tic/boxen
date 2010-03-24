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
	import Phys = xf.boxen.Phys;
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
	
	version (Client) import xf.game.TickTracker;
	
	import GameObjMngr = xf.game.GameObjMngr;
	import LoginMngr = xf.game.LoginMngr;
	import GameObjRegistry = xf.game.GameObjRegistry;
	import InteractionTracking = xf.game.InteractionTracking;
	import AuthStorage = xf.game.AuthStorage;

	import tango.core.Thread;
	import Integer = tango.text.convert.Integer;

	import xf.net.NetObj;
	import xf.net.GameClient;
	import xf.net.GameServer;
	import xf.net.ControlEvents;
	import xf.net.LowLevelClient;
	import xf.net.LowLevelServer;
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
	playerId	_localPlayerId;
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
			if (_localPlayerId == obj.authOwner || obj.authRequested) {
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
			const float maxError = .5f;

			// TODO
			/+foreach (t; intf) {
				if (_netObjects[t].authOwner != NoAuthority) {
					auto go = cast(GameObj)t.userData;
					assert (go !is null);
					float err = go.compareCurrentStateWithStored(theOwner, timeHub.currentTick);
					if (err > maxError) {
						printf("can't give object back. error = %f"\n, err);
						canGiveBack = false;
						break;
					}
				}
			}+/
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
		if (_localPlayerId == _netObjects[t].realOwner) {
			touchesLocallyOwned = true;
		}
	}
	
	if (touchesLocallyOwned) {
		// try to take control over all the objects
		requestAllAuth;
	} else {
		bool groupAsleep = isGroupAsleep(intf);
		
		if (singleAuth && _localPlayerId == theAuth) {
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
				if (_localPlayerId == _netObjects[t].authOwner || _netObjects[t].authRequested) {
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
			netObj.authRequested = false;
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
		timeHub.advanceTick(1);
		eventQueue.advanceTick(1);
		while (eventQueue.moreEvents) {
			Event ev = eventQueue.nextEvent;
			ev.handle();
			ev.unref();
		}

		GameObjMngr.update(timeHub.secondsPerTick);
		level.update(timeHub.secondsPerTick);
		Phys.update(timeHub.secondsPerTick);
		refreshInteractions();
		updateAuthority();

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

		if (timeHub.currentTick > client.lastTickReceived) {
			timeHub.trimHistory(timeHub.currentTick - client.lastTickReceived);
		}

		_playerInputMap.update();
		_playerInputSampler.sample();

		timeHub.advanceTick(1);
		eventQueue.advanceTick(1);
		while (eventQueue.moreEvents) {
			Event ev = eventQueue.nextEvent;
			ev.handle();
			ev.unref();
		}

		GameObjMngr.update(timeHub.secondsPerTick);
		level.update(timeHub.secondsPerTick);
		Phys.update(timeHub.secondsPerTick);
		refreshInteractions();
		updateAuthority();

		/+if (client.connected) {
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
		}+/
		
		client.sendData();
	}

	// tmp HACK
	if (timeHub.currentTick > 100) {
		NetObjMngr.dropStatesOlderThan(cast(tick)(timeHub.currentTick - 100));
	}


	enum { stateSwapFreq = 10 }
	static int ticksToStateSwap = stateSwapFreq;
	if (--ticksToStateSwap < 0) {
		NetObjMngr.swapObjDataMem();
		ticksToStateSwap = stateSwapFreq;
	}
}


version (Server) {
	void createGameWorld() {
		GameObjMngr.createGameObj("PlayerController", vec3(2, 0, -3), NoAuthority);
		GameObjMngr.createGameObj("PlayerController", vec3(-2, 0, -3), NoAuthority);
		GameObjMngr.createGameObj("DebrisObject", vec3(0, 0.5, -6), NoAuthority);
		GameObjMngr.createGameObj("DebrisObject", vec3(0, 1.5, -6), NoAuthority);
		GameObjMngr.createGameObj("DebrisObject", vec3(0, 2.5, -6), NoAuthority);
	}


	GameObj[maxPlayers] _playerControllers;
	playerId			_observedPlayer = playerId.max;


	void handlePlayerLogin(playerId pid) {
		final obj = GameObjMngr.createGameObj("PlayerController", vec3.zero, pid);

		_observedPlayer = pid;

		AssignController(
			obj.id
		).filter((playerId id) { return id == pid; }).immediate();

		_playerControllers[pid] = obj;
	}

	void handleInputWish(InputWish e) {
		/+version (Server) {
			tuneClientTiming(e);
		}+/
		
		float b2f(byte b) {
			return cast(float)b / 127.f;
		}

		bool useAction = (e.action & 2) != 0;
		bool shootAction = (e.action & 1) != 0;
		auto pid = e.wishOrigin;
		auto ctrl = cast(IPlayerController)_playerControllers[pid];
			
		float strafe = b2f(e.strafe);
		float fwd = b2f(e.thrust);

		// writeln("ctrl position: ", pos.x, " ", pos.y, " ", pos.z)
		float moveSpeed = 1.f;
		ctrl.move(vec3(strafe * moveSpeed, 0, fwd * moveSpeed));

		float rotSpeed = 10.f;
		float yawRot = e.rot.x * timeHub.secondsPerTick();
		float pitchRot = e.rot.y * timeHub.secondsPerTick();
		ctrl.yawRotate(yawRot * rotSpeed);
		ctrl.pitchRotate(pitchRot * rotSpeed);
	}
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
	SimpleCamera camera;
	

	version (Client) override void configureWindow(Window wnd) {
		super.configureWindow(wnd);
		wnd.title = "Boxen Tech #1";
		wnd.interceptCursor = true;
		wnd.showCursor = false;
	}
	

	void initialize() {
		camera = new SimpleCamera(vec3(0, 2, 5), 0, 0, window.inputChannel);
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
		char[]	netAddr;
		
		version (Server) {
			netAddr = "0.0.0.0";
		} else {
			netAddr = "127.0.0.1";
		}

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

			InputWish.addHandler(fn2dg(&handleInputWish));
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
				._localPlayerId = e.pid;
			});
		}

		jobHub.addRepeatableJob(&update, 60.f);
	}


	void update() {
		updateGame();
	}


	static vec4[] playerColors = [
		{ r: 0.1f, g: 1.0f, b: 0.2f, a: 1.0f },
		{ r: 0.1f, g: 0.2f, b: 1.0f, a: 1.0f },
		{ r: 0.7f, g: 0.9f, b: 0.2f, a: 1.0f }
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
			vec4 tintColor = void;
			if (NoAuthority == auth) {
				tintColor = vec4.one;
			} else if (ServerAuthority == auth) {
				tintColor = vec4(1.0f, 0.0f, 0.0f, 1.0f);
			} else {
				assert (auth < 2);		// for now
				tintColor = playerColors[auth % $];
			}

			if (!obj.isActive) {
				tintColor *= 0.5f;
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


void main() {
	(new TestApp).run;
}
