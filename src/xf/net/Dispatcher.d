module xf.net.Dispatcher;

private {
	import xf.game.Misc : NetEndpoint;
	import xf.net.LowLevelComm;
	import xf.net.Misc : readTick;
	import xf.net.Log : log = netLog;
	import xf.utils.BitStream;
	import tango.io.Stdout;	// tmp
}



class Dispatcher {
	this (LowLevelComm comm, tick* lastTickRecvd) {
		this.comm = comm;
		this.lastTickRecvd = lastTickRecvd;
	}


	private {
		LowLevelComm	comm;
		tick*			lastTickRecvd;
	}


	public {
		bool delegate(playerId, BitStreamReader*)
			receiveEvent;
			
		void delegate(playerId, BitStreamReader*)
			receiveStateSnapshot;
	}



	void dispatch(
		tick curTick
	) {
		comm.recvPacketsForTick(
			curTick,
			delegate tick(playerId pid, BitStreamReader* bs, uint* retained) {
				bool receivedTick = *retained > 0;

				//log.trace("Dispatcher: receiving {} bits of data. Retained = {}.", bs.dataBlockSize, *retained);
				//Stdout.formatln("{}", bs.toString);

				bool eventInStream = 0 == *retained;

				while (!bs.isEmpty) {
					if (eventInStream && (bs.read(&eventInStream), eventInStream)) {
						//printf("event");
						if (!receiveEvent(pid, bs)) {
							//printf("donotwant");
							*retained = 0;
							return curTick;
						}
					} else {
						if (!receivedTick) {
							//printf("tick");
							receivedTick = true;

							lastTickRecvd[pid] = readTick(bs);
						}
						*retained = 0;
						
						version (Client) {
							if (lastTickRecvd[pid] > curTick) {
								//log.trace(`Retaining stream and returning... (recvd: {}, local: {})`\n, lastTickRecvd[pid], curTick);
								*retained = 1;
								return lastTickRecvd[pid];
							}
						}
						
						if (!bs.isEmpty) {
							//log.trace("Snapshot has {} bits", bs.dataBlockSize - bs.readOffset);
							//printf("snapshot");
							receiveStateSnapshot(pid, bs);
						}
					}
				}

				*retained = 0;
				return curTick;
			}
		);
	}
}
