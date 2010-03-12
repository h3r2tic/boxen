module Main;

private {
	version (StackTracing) {
		import tango.core.tools.TraceExceptions;
	}
	
	import xf.Common;
	import xf.core.Registry : create;
	import xf.core.JobHub;
	import xf.game.Misc : tick, playerId;
	import xf.game.MainProcess;
	import xf.game.TimeHub;
	import xf.utils.BitStream;
	import xf.net.LowLevelClient;
	import xf.net.LowLevelServer;

	import tango.io.Stdout;
}


bool			serverSide = true;
LowLevelServer	server;
LowLevelClient	client;


void main(char[][] args) {
	if (args.length > 1 && args[1] == "client") {
		serverSide = false;
		args = args[2..$];
	} else {
		args = args[1..$];
	}
	

	char[]	netBackend	= "ENet";
	u16		port		= 8000;

	if (serverSide) {
		cstring	netAddr = "0.0.0.0";
		
		server =	create!(LowLevelServer).named(netBackend~"Server")
					(32).start(netAddr, port);
	} else {
		cstring	netAddr = "127.0.0.1";
		
		client = 	create!(LowLevelClient).named(netBackend~"Client")
					().connect(0, netAddr, port);
	}

	tick curTick = 0;
	
	jobHub.addRepeatableJob({
		if (serverSide) {
			while (server.recvPacketForTick(curTick, (playerId pid, BitStreamReader* bsr) {
				return curTick;
			})) {
			}
		} else {
			if (client.connected) {
				while (client.recvPacketForTick(curTick, (BitStreamReader* bsr) {
					return curTick;
				})) {
				}
			}
		}
		++curTick;
	}, timeHub.ticksPerSecond);
	
	Stdout.formatln("starting MainProcess...");
	jobHub.exec(new MainProcess);
}
