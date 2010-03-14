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
			server.recvPacketsForTick(curTick, (playerId pid, BitStreamReader* bs, uint*) {
				uword a, b;
				bool c;
				bs.read(&a);
				bs.read(&b);
				bs.read(&c);

				Stdout.formatln("Received {} {} {}", a, b, c);
				
				return curTick;
			});
		} else {
			if (client.connected) {
				client.recvPacketsForTick(curTick, (playerId, BitStreamReader* bsr, uint*) {
					return curTick;
				});

				ubyte[128] data;
				auto bs = BitStreamWriter(data[]);
				{
					uword a = curTick;
					uword b = 2 * a;
					bool c = a % 2 == 0;
					bs.write(a);
					bs.write(b);
					bs.write(c);
				}
				client.send(bs.asBytes);
			}
		}
		++curTick;
	}, 5);
	
	Stdout.formatln("starting MainProcess...");
	jobHub.exec(new MainProcess);
}
