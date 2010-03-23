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


version (Client) GameClient	client;
version (Server) GameServer	server;
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

enum : ushort { contactPersistence = 60 };

extern (C) void boxen_processGameObjInteraction(void* o1, void* o2) {
	final id1 = (cast(GameObj)cast(Object)o1).id();
	final id2 = (cast(GameObj)cast(Object)o2).id();

	assert (NetObjMngr.g_netObjects[id1] !is null);
	assert (NetObjMngr.g_netObjects[id2] !is null);

	if (id1 != id2) {
		InteractionQueueRegistry.register(&interactionQueue);
		interactionQueue.pushBack(Interaction(id1, id2));
	}
}


void iterInteractions(objId id0_, objId[] queue, void delegate(objId) sink) {
	assert (queue.length >= NetObjMngr.g_netObjects.length);
	
	uword queueLen = 1;
	queue[0] = id0_;
	AuthStorage.binStorage[id0_].setVisitedFlag();

	for (uword i = 0; i < queueLen; ++i) {
		final id = queue[i];
		final bs = &AuthStorage.binStorage[id];
		assert (true == bs.readVisitedFlag());
		sink(id);
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

	for (uword i = 0; i < queueLen; ++i) {
		final id = queue[i];
		final bs = &AuthStorage.binStorage[id];
		assert (true == bs.readVisitedFlag());
		bs.unsetVisitedFlag();
	}
}


void refreshInteractions() {
	foreach (thi, thq; InteractionQueueRegistry.each) {
		foreach (i, x; *thq) {
			serializedInteractions.pushBack(x);
		}
		(*thq).clear();
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
					it.ticks = .contactPersistence;
					return true;
				}
				return false;
			}, IdTicks(id2, .contactPersistence).packed);
		}

		{
			final id2 = x.id1;
			final id1 = x.id2;
			
			final bs = &AuthStorage.binStorage[id1];
			bs.iterOrAdd((ref u32 i) {
				final it = cast(IdTicks*)&i;
				if (it.id == id2) {
					it.ticks = .contactPersistence;
					return true;
				}
				return false;
			}, IdTicks(id2, .contactPersistence).packed);
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

	scope stack = new StackBuffer();
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
	}
}


void updateGame() {
	version (Server) {
		server.receiveData();
		timeHub.advanceTick(1);
		eventQueue.advanceTick(1);
		while (eventQueue.moreEvents) {
			Event ev = eventQueue.nextEvent;
			ev.handle();
		}

		GameObjMngr.update(timeHub.secondsPerTick);
		level.update(timeHub.secondsPerTick);
		Phys.update(timeHub.secondsPerTick);
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

		// tmp HACK
		if (timeHub.currentTick > 100) {
			NetObjMngr.dropStatesOlderThan(cast(tick)(timeHub.currentTick - 100));
		}
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
		}

		GameObjMngr.update(timeHub.secondsPerTick);
		level.update(timeHub.secondsPerTick);
		Phys.update(timeHub.secondsPerTick);
		refreshInteractions();

		/+if (client.connected) {
			NetObjMngr.storeNetObjStates(timeHub.currentTick);
			/+NetObjMngr.updateStateImportances();
			final writer = client.getWriter();
			Stdout.formatln("Bits in writer before states: {}.\n{}", writer.bsw.writeOffset, writer.bsw.toString);
			writer.bsw.write(false);		// end of events
			static assert (uint.sizeof == tick.sizeof);
			writer.bsw.write(cast(uint)timeHub.currentTick);
			writer.bsw.flush();
			Stdout.formatln("Sending:\n{}", writer.bsw.toString);
			/+NetObjMngr.writeStates(
				timeHub.currentTick,
				(NetObj) {
					return 1.0f;		// importance
				},
				writer
			);+/+/
		}+/
		
		client.sendData();
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
		final obj = GameObjMngr.createGameObj("PlayerController", vec3.zero, ServerAuthority/+pid+/);

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
		
		eventQueue = new LoggingEventQueue;

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
			LoginMngr.initialize();
			createGameWorld();
			
			server = new GameServer((
				create!(LowLevelServer).named(netBackend~"Server")(32)
			).start(netAddr, port));
		} else {
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
			});
		}

		jobHub.addRepeatableJob(&update, 60.f);
	}


	void update() {
		updateGame();
	}


	override void render() {
		final renderList = renderer.createRenderList();
		assert (renderList !is null);
		scope (success) renderer.disposeRenderList(renderList);

		//Stdout.formatln("Rendering {} meshes.", meshes.length);
		for (uword i = 0; i < meshes.length; ++i) {
			final mesh = meshes.mesh[i];
			final bin = renderList.getBin(mesh.effect);
			auto data = bin.add(mesh.effectInstance);
			mesh.toRenderableData(data);

			final obj = GameObjMngr.getObj(meshes.offsetFrom[i]);
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
