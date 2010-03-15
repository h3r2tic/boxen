module xf.net.NetObjMngr;

private {
	import xf.game.Misc;
	import xf.game.Defs;
	import xf.net.NetObj;
	import xf.net.Log : log = netLog, error = netError;
	import xf.mem.ChunkQueue;
	import xf.mem.FixedQueue;
	import xf.utils.UidPool;
}



interface NetObjObserver {
	void onNetObjCreated(NetObj o);
	void onNetObjDestroyed(NetObj o);
}


enum StateOverrideMethod {
	Replace,
	ApplyDiff
}



// Managed by NetObjMngr. In GC memory. May contain null elements.
extern (C) NetObj[] g_netObjects;



struct NetObjMngr {
static:
	const maxClients = 32;


	objId allocId() {
		return _uidPool.alloc().id;
	}


	void freeId(objId id) {
		_uidPool.free(_uidPool.UID(id));
	}


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
				if (netObj !is null) {
					withStateInfo(netObj, (NetObjInfo* netObjInfo) {
						void* state = _rawStateQueue.pushBack(netObjInfo.totalStateSize);
						statePtrs[i] = state;
						foreach (nsi; netObjInfo.netStateInfo) {
							nsi.store(netObj, state);
							state += nsi.size;
						}
					});
				} else {
					statePtrs[i] = null;
				}
			}

			*_tickStateQueue.pushBack() = statePtrs;
			_lastTickInQueue = curTick;
		}


		void withStateInfo(NetObj obj, void delegate(NetObjInfo*) sink) {
			assert (false, "TODO");
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


		void onNetObjCreated(NetObj o){
			assert (o !is null);
			if (o.id < _netObjects.length) {
				if (_netObjects[o.id] !is null) {
					error(
						"NetObj already exists in the manager: {}",
						cast(Object)_netObjects[o.id]
					);
				} else {
					_netObjects[o.id] = o;
				}				
			} else {
				size_t reqLen = o.id() + 1;
				const expandBy = 64;
				reqLen = ((reqLen + expandBy-1) / expandBy) * expandBy;
				_netObjects.length = reqLen;
				_netObjects[o.id] = o;
			}
		}

		
		void onNetObjDestroyed(NetObj o) {
			assert (o !is null);
			if (o.id < _netObjects.length) {
				if (_netObjects[o.id] !is o) {
					error(
						"Destroying an object with ID pointing to another object"
						" in the NetObjMngr. Object passed to onNetObjDestroyed:"
						" {} (id={}). In manager: {} (id={}).",
						cast(Object)o,
						o.id,
						cast(Object)_netObjects[o.id],
						_netObjects[o.id].id
					);
				} else {
					_netObjects[o.id] = null;
				}
			} else {
				error(
					"NetObj unknown to the manager: {}",
					cast(Object)_netObjects[o.id]
				);
			}
		}

		
		struct NetObjData {
			float[]		stateImportances;
			void*[]		lastWrittenStates;
		}

		alias .g_netObjects			_netObjects;
		
		NetObjData[][maxClients]	_serverNetObjData;
		NetObjData[]				_clientNetObjData;

		ScratchFIFO				_rawStateQueue;
		ScratchFIFO				_objStatePtrQueue;
		FixedQueue!(void*[])	_tickStateQueue;
		tick					_firstTickInQueue;
		tick					_lastTickInQueue;

		UidPool!(objId)			_uidPool;
	}
}
