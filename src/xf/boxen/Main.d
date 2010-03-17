module xf.boxen.Main;

private {
	version (StackTracing) {
		import tango.core.tools.TraceExceptions;
	}
	
	import xf.boxen.Events;
	import xf.boxen.Rendering;
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

	import tango.core.Thread;
	import Integer = tango.text.convert.Integer;

	import xf.net.GameClient;
	import xf.net.GameServer;
	import xf.net.ControlEvents;
	import xf.net.LowLevelClient;
	import xf.net.LowLevelServer;
	import NetObjMngr = xf.net.NetObjMngr;

	import xf.utils.Meta : fn2dg;
	import xf.utils.GfxApp;
	import xf.utils.SimpleCamera;

	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.CoordSys;

	import tango.io.Stdout;
	import tango.stdc.stdio : printf;
}


version (Client) GameClient	client;
version (Server) GameServer	server;
EventQueue	eventQueue;



void updateGame() {
	version (Server) {
		server.receiveData();
		timeHub.advanceTick(1);
		eventQueue.advanceTick(1);
		while (eventQueue.moreEvents) {
			Event ev = eventQueue.nextEvent;
			ev.handle();
		}
		server.sendData();
		debug printf(`tick: %d`\n, timeHub.currentTick);
	} else {
		client.receiveData();
		timeHub.advanceTick(1);
		eventQueue.advanceTick(1);
		while (eventQueue.moreEvents) {
			Event ev = eventQueue.nextEvent;
			ev.handle();
		}
		client.sendData();
	}
}


version (Server) void createGameWorld() {
	GameObjMngr.createGameObj("PlayerController", vec3(2, 0, 0), NoAuthority);
}


version (Server) void handlePlayerLogin(playerId pid) {
	final obj = GameObjMngr.createGameObj("PlayerController", vec3.zero, pid);

	AssignController(
		obj.id
	).filter((playerId id) { return id == pid; }).immediate();
}

version (Client) {
	GameObj	_playerController;

	void handleAssignController(AssignController e) {
		_playerController = GameObjMngr.getObj(e.id);
		assert (_playerController !is null);
		Stdout.formatln("Got a controller assigned.");
	}
}


struct login {
	static cstring nick = "Test";
}


class TestApp : GfxApp {
	SimpleCamera camera;
	
	void initialize() {
		camera = new SimpleCamera(vec3(0, 2, 5), 0, 0, window.inputChannel);
		camera.movementSpeed = vec3.one * 40.f;

		DebugDraw.initialize(renderer, window);
		version (Server) {
			window.title = "Boxen server";
		} else {
			window.title = "Boxen client";
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
			Stdout.formatln(
				"Submitting {} for tick {} (current = {}).",
				ev.classinfo.name,
				target,
				timeHub.currentTick
			);
			eventQueue.addEvent(ev, cast(int)target - timeHub.currentTick);
		}
		Order.addSubmitHandler(&queueEvent);
		Wish.addSubmitHandler(&queueEvent);
		Local.addSubmitHandler(&queueEvent);

		GameObjMngr.initialize();

		version (Server) {
			LoginMngr.initialize();
			createGameWorld();
			
			server = new GameServer((
				create!(LowLevelServer).named(netBackend~"Server")(32)
			).start(netAddr, port));
		} else {
			AssignController.addHandler(fn2dg(&handleAssignController));
			
			client = new GameClient((
				create!(LowLevelClient).named(netBackend~"Client")()
			).connect(0, netAddr, port));
		}
		
		int playerNameId = 1;		// for further login requests when the name is already used
		
		version (Server) {
			server.setDefaultWishMask((Wish w) { return cast(LoginRequest)w !is null; });

			LoginAccepted.addHandler((LoginAccepted e) {
				server.setWishMask(e.pid, null);
				server.setStateMask(e.pid, true);
				handlePlayerLogin(e.pid);
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

		jobHub.addRepeatableJob(&update, 60.f);
	}


	void update() {
		updateGame();
	}


	override void render() {
		final renderList = renderer.createRenderList();
		assert (renderList !is null);
		scope (success) renderer.disposeRenderList(renderList);

		Stdout.formatln("Rendering {} meshes.", meshes.length);
		for (uword i = 0; i < meshes.length; ++i) {
			final mesh = meshes.mesh[i];
			final bin = renderList.getBin(mesh.effect);
			auto data = bin.add(mesh.effectInstance);
			mesh.toRenderableData(data);
			data.coordSys =	meshes.offset[i] in CoordSys(
				GameObjMngr.getObj(meshes.offsetFrom[i]).worldPosition,
				quat.identity
			);
			data.scale = vec3.one;
		}


		/+void drawCube(vec3 position, quat rotation, vec3 size) {
			auto mesh = &meshes[0];
			final bin = renderList.getBin(mesh.effect);
			auto data = bin.add(mesh.effectInstance);
			mesh.toRenderableData(data);
			data.coordSys = CoordSys(vec3fi.from(position), rotation);
			data.scale = size;
		}

		void drawCylinder(vec3 position, quat rotation, vec3 size, CoordSys baseCS) {
			auto mesh = &meshes[1];
			final bin = renderList.getBin(mesh.effect);
			auto data = bin.add(mesh.effectInstance);
			mesh.toRenderableData(data);
			data.coordSys = baseCS in CoordSys(vec3fi.from(position), rotation);
			data.scale = size;
		}


		effect.setUniform("worldToView",
			camera.getMatrix
		);
		
		foreach (ref box; g_boxes) {
			//gl.Color3fv(box.color.ptr);
			drawCube(box.position, box.rotation, box.size);
		}
		
		foreach (ref cyl; g_cylinders) {
			//gl.Color3fv(cyl.color.ptr);
			drawCylinder(cyl.position, cyl.rotation, cyl.scale, cyl.baseCS);
		}+/

//	TODO
		DebugDraw.setWorldToView(camera.getMatrix);

		renderList.sort();
		renderer.framebuffer.settings.clearColorValue[0] = vec4(0.1, 0.1, 0.1, 1.0);
		renderer.clearBuffers();
		renderer.render(renderList);
	}
}


void main() {
	(new TestApp).run;
}
