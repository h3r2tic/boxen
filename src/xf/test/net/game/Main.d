module Main;

private {
	version (StackTracing) {
		import tango.core.tools.TraceExceptions;
	}
	
	import xf.Common;
	import xf.core.Registry : create;
	import xf.core.InputHub;
	import xf.core.JobHub;
	import xf.core.MessageHub;
	import xf.core.Message;

	import xf.game.MainProcess;
	import xf.game.TimeHub;
	import xf.game.Event;
	import xf.game.EventQueue;
	import xf.game.LoginEvents;

	import tango.core.Thread;
	import Integer = tango.text.convert.Integer;

	import xf.net.GameClient;
	import xf.net.GameServer;
	import xf.net.ControlEvents;
	import xf.net.LowLevelClient;
	import xf.net.LowLevelServer;

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

struct login {
	static cstring nick = "Test";
}


void main(char[][] args) {
	printf("Program started\n\n");
	
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
	

	version (Server) {
		server = new GameServer((
			create!(LowLevelServer).named(netBackend~"Server")(32)
		).start(netAddr, port));
	} else {
		client = new GameClient((
			create!(LowLevelClient).named(netBackend~"Client")()
		).connect(0, netAddr, port));
	}
	
	int playerNameId = 1;		// for further login requests when the name is already used
	
	version (Server) {
		server.setDefaultWishMask((Wish w) { return cast(LoginRequest)w !is null; });

		LoginRequest.addHandler((LoginRequest e) {
			auto filter = (playerId pid) {
				return pid == e.wishOrigin;
			};
			
			LoginAccepted(e.wishOrigin, e.nick).filter(filter).immediate;
		});
		
		LoginAccepted.addHandler((LoginAccepted e) {
			server.setWishMask(e.pid, null);
		});
		
		JoinGame.addHandler((JoinGame e) {
			server.setStateMask(e.wishOrigin, true);
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
			JoinGame().immediate;		// ask the server for state snapshots
		});
	}
	

	jobHub.addRepeatableJob({ updateGame; }, timeHub.ticksPerSecond);
	jobHub.exec(new MainProcess);
}
