module xf.net.Dispatcher;

private {
	import xf.game.Misc : NetEndpoint;
	import xf.net.LowLevelComm;
	import xf.net.Misc : readTick;
	import xf.net.Log : log = netLog;
	import xf.utils.BitStream;
}



class Dispatcher {
	this (LowLevelComm comm, tick* lastTickRecvd, NetEndpoint endpoint) {
		this.comm = comm;
		this.lastTickRecvd = lastTickRecvd;
		this.endpoint = endpoint;
	}


	private {
		LowLevelComm	comm;
		tick*			lastTickRecvd;
		NetEndpoint		endpoint;
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

				log.trace("Dispatcher: receiving data.");

				while (!bs.empty) {
					bool eventInStream = 0 == *retained;
					
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

							assert (false, "TODO outside of the Dispatcher");
							/+if (NetEndpoint.Client == endpoint) {
								if (curTick > lastTickRecvd[pid]) {
									timeHub.trimHistory(timeHub.currentTick - lastTickRecvd[pid]);
								}
							}+/
						}							
						*retained = 0;
						
						if (NetEndpoint.Client == endpoint) {
							if (lastTickRecvd[pid] > curTick) {
								debug printf(`retaining stream and returning... (recvd: %d, local: %d)`\n, lastTickRecvd, timeHub.currentTick);
								*retained = 1;
								return lastTickRecvd[pid];
							}
						}
						
						if (!bs.empty) {
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
