module xf.net.NetObjMngr;

private {
	import xf.game.Misc;
	import xf.net.NetObj;
	import xf.net.Log : log = netLog, error = netError;
	import xf.mem.ChunkQueue;
	import xf.mem.FixedQueue;
}



interface NetObjObserver {
	void onNetObjCreated(NetObj o);
	void onNetObjDestroyed(NetObj o);
}


enum StateOverrideMethod {
	Replace,
	ApplyDiff
}


struct NetObjMngr {
static:
	const maxClients = 32;


	private {
		void storeNetObjStates(tick curTick) {
			assert (_lastTickInQueue < curTick);
			final numStates = _netObjects.length;

			{
				size_t reqBytes = numStates * (void*).sizeof;
				size_t maxBytes = _objStatePtrQueue.chunkCapacity;
				if (reqBytes * 3 > maxBytes * 2) {
					log.warn(
						"NetObjMngr._objStatePtrQueue might be using too small chunks."
						" Max chunk capacity: {}. Currently required capacity: {}",
						maxBytes,
						reqBytes
					);
				}
			}
			
			void*[] statePtrs =
				(cast(void**)_objStatePtrQueue.pushBack(
					numStates * (void*).sizeof
				))[0..numStates];
			
			foreach (i, netObj; _netObjects) {
				final NetObjInfo netObjInfo;		// TODO
				void* state = _rawStateQueue.pushBack(netObjInfo.totalStateSize);
				statePtrs[i] = state;
				foreach (nsi; netObjInfo.netStateInfo) {
					nsi.store(netObj, state);
					state += nsi.size;
				}
			}

			*_tickStateQueue.pushBack() = statePtrs;
			_lastTickInQueue = curTick;
		}


		void dropStatesOlderThan(tick tck) {
			assert (tck >= _firstTickInQueue);
			int numToDrop = tck - _firstTickInQueue;
			while (numToDrop--) {
				void*[] ptrs = *_tickStateQueue.popFront();
				foreach (p; ptrs) {
					_rawStateQueue.popFront(p);
				}
				_objStatePtrQueue.popFront(ptrs.ptr);
			}
			_firstTickInQueue = tck;
		}

		
		struct NetObjData {
			float[]		stateImportances;
			void*[]		lastWrittenStates;
		}

		NetObj[]	_netObjects;		// TODO
		
		NetObjData[][maxClients]	_serverNetObjData;
		NetObjData[]				_clientNetObjData;

		RawChunkQueue			_rawStateQueue;
		RawChunkQueue			_objStatePtrQueue;
		FixedQueue!(void*[])	_tickStateQueue;
		tick					_firstTickInQueue;
		tick					_lastTickInQueue;
	}
}
