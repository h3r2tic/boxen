module xf.net.NetObjMngr;

private {
	import xf.Common;
	import xf.game.Misc;
	import xf.game.Defs;
	import xf.net.NetObj;
	import xf.net.Log : log = netLog, error = netError;
	import xf.net.BudgetWriter;
	import xf.mem.ChunkQueue;
	import xf.mem.FixedQueue;
	import xf.mem.MainHeap;
	import xf.mem.Array;
	import xf.utils.UidPool;
	import xf.utils.BitStream;
	import ArrayUtils = tango.core.Array;
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



objId allocId() {
	return _uidPool.alloc().id;
}


void freeId(objId id) {
	_uidPool.free(_uidPool.UID(id));
}


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

	if (_tickStateQueue.isEmpty) {
		_firstTickInQueue = curTick;
	}
	
	*_tickStateQueue.pushBack() = statePtrs;
	_curTickStates = statePtrs;
	_lastTickInQueue = curTick;
}


version (Client) void receiveStateSnapshot(playerId, BitStreamReader* bs) {
	assert (!bs.isEmpty);
	static assert (objId.sizeof == ushort.sizeof);
	objId id;
	ushort stateI;
	bs.read(cast(ushort*)&id);
	bs.read(&stateI);
	final obj = _netObjects[id];
	assert (obj !is null);
	final objInfo = obj.getNetObjInfo();
	final stateInfo = &objInfo.netStateInfo[stateI];
	final stateMemSize = stateInfo.size;
	final stateMem = _objDataMemCur.pushBack(stateMemSize);

	void delegate(BitStreamReader*) dg;
	dg.funcptr = stateInfo[stateI].unserialize;
	dg.ptr = stateMem;
	dg(bs);

	stateInfo.load(obj, stateMem);
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


void onNetObjCreated(NetObj o) {
	assert (o !is null);
	if (o.id < _netObjects.length) {
		if (_netObjects[o.id] !is null) {
			error(
				"NetObj already exists in the manager: {}",
				cast(Object)_netObjects[o.id]
			);
		}
	} else {
		size_t reqLen = o.id() + 1;
		const expandBy = 64;
		reqLen = ((reqLen + expandBy-1) / expandBy) * expandBy;
		_netObjects.length = reqLen;
		
		version (Server) {
			foreach (ref d; _netObjData) {
				d = cast(NetObjData*)
					mainHeap.reallocRaw(d, reqLen * NetObjData.sizeof);
			}
		} else {
			_netObjData = cast(NetObjData*)
				mainHeap.reallocRaw(_netObjData, reqLen * NetObjData.sizeof);
		}
	}

	_netObjects[o.id] = o;
	allocObjStates(o.id, o.numNetStateTypes);
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


version (Client) {
	void updateStateImportances() {
		updateStateImportances(_netObjData);
	}

	void resetStateImportances() {
		resetStateImportances(_netObjData);
	}

	void writeStates(
		tick curTick,
		float delegate(NetObj) objImportance,
		BudgetWriter* writer
	) {
		writeStates(curTick, _netObjData, objImportance, writer);
	}
}


version (Server) {
	void updateStateImportances(playerId pid) {
		updateStateImportances(_netObjData[pid]);
	}

	void resetStateImportances(playerId pid) {
		resetStateImportances(_netObjData[pid]);
	}

	void writeStates(
		playerId pid,
		tick curTick,
		float delegate(NetObj) objImportance,
		BudgetWriter* writer
	) {
		writeStates(curTick, _netObjData[pid], objImportance, writer);
	}
}



private {
	void withStateInfo(NetObj obj, void delegate(NetObjInfo*) sink) {
		sink(obj.getNetObjInfo());
	}


	// Pretty arbitrary, just large so unsent states get priority
	const float defaultStateImportance = 1e+10;

	void updateStateImportances(NetObjData* objData) {
		assert (_curTickStates !is null);
		
		foreach (id, obj; _netObjects) {
			if (obj is null) {
				continue;
			}

			final stateInfo = obj.getNetObjInfo.netStateInfo;
			final data = &objData[id];

			foreach (stateI, ref imp; data.stateImportances[0..data.numStates]) {
				assert (imp <>= 0.0f);

				auto wrState = data.lastWrittenStates[stateI];
				if (wrState && data.lastWrittenAtTick[stateI] >= _firstTickInQueue) {
					final curStateRaw = _curTickStates[id];
					final curState = curStateRaw + stateInfo[stateI].offset;
					
					final float diff = stateInfo[stateI]
						.calcDifference(wrState, curState);

					imp += diff;
				} else {
					imp += defaultStateImportance;
				}
			}
		}
	}


	void resetStateImportances(NetObjData* objData) {
		foreach (id, obj; _netObjects) {
			if (obj !is null) {
				final data = &objData[id];
				data.stateImportances[0..data.numStates] = defaultStateImportance;
			}
		}
	}


	struct ObjStateImportance {
		float	importance;
		objId	id;
		ushort	state;
	}
	static assert (8 == ObjStateImportance.sizeof);


	/// NOT thread safe  (FIXME?)
	void writeStates(
		tick curTick,
		NetObjData* objData,
		float delegate(NetObj) objImportance,
		BudgetWriter* writer
	) {
		static Array!(ObjStateImportance) osiMem;
		if (0 == osiMem.capacity) {
			// 32k objects*states should be enough for anyone :P
			osiMem.reserve(32 * 1024);
		}
		osiMem.clear();
		
		foreach (id, obj; _netObjects) {
			if (obj is null) {
				continue;
			}

			final objImp = objImportance(obj);
			if (0.0f == objImp) {
				continue;
			}

			version (Client) {
				if (!obj.keepServerUpdated) {
					continue;
				}
			}

			final numStates = obj.numNetStateTypes();
			final data = &objData[id];

			for (uword stateI = 0; stateI < numStates; ++stateI) {
				ObjStateImportance osi = void;
				osi.importance = data.stateImportances[stateI];
				osi.id = cast(objId)id;
				assert (stateI <= cast(uword)ushort.max);
				osi.state = cast(ushort)stateI;
				osiMem.pushBack(osi);
			}
		}

		ArrayUtils.sort(
			osiMem.ptr[0..osiMem.length],
			(ref ObjStateImportance a, ref ObjStateImportance b) {
				return a.importance > b.importance;
			}
		);

		foreach (ref s; osiMem) {
			if (writer.canWriteMore) {
				final obj = _netObjects[s.id];
				assert (obj !is null);

				final stateInfo = obj.getNetObjInfo.netStateInfo;
				final curStateRaw = _curTickStates[s.id];
				final curState = curStateRaw + stateInfo[s.state].offset;

				log.trace(
					"Writing state {} ({}) (i={}) of obj {} ({})",
					s.state,
					stateInfo[s.state].typeInfo.toString,
					s.importance,
					s.id,
					(cast(Object)obj).classinfo.name
				);

				void delegate(BitStreamWriter*) dg;
				dg.funcptr = stateInfo[s.state].serialize;
				dg.ptr = curState;

				writer.bsw.write(cast(ushort)s.id);
				writer.bsw.write(cast(ushort)s.state);
				dg(&writer.bsw);

				final data = &objData[s.id];
				data.stateImportances[s.state] = 0.0f;
				data.lastWrittenAtTick[s.state] = curTick;
				data.lastWrittenStates[s.state] = curState;
			}
		}
	}

	
	struct NetObjData {
		// Storage allocated from the scratch _objDataMemCur
		void**	lastWrittenStates;
		float*	stateImportances;

		// State ptrs invalid if refer to ticks earlier than _firstTickInQueue
		tick*	lastWrittenAtTick;
		uword	numStates;

		static uword memRequired(uword numStates) {
			return numStates * ((void*).sizeof + float.sizeof + tick.sizeof);
		}

		static NetObjData alloc(void* mem, uword numStates) {
			NetObjData res;
			uword size;
			final memOrig = mem;
			
			size = (void*).sizeof * numStates;
			res.lastWrittenStates = cast(void**)mem;
			memset(res.lastWrittenStates, 0, size);
			mem += size;

			size = float.sizeof * numStates;
			res.stateImportances = cast(float*)mem;
			memset(res.stateImportances, 0, size);
			mem += size;
			
			size = tick.sizeof * numStates;
			res.lastWrittenAtTick = cast(tick*)mem;
			memset(res.lastWrittenAtTick, 0, size);
			mem += size;

			assert (mem - memOrig == memRequired(numStates));

			res.numStates = numStates;
			return res;
		}

		static void copy(NetObjData* dst, NetObjData* src) {
			final ns = src.numStates;
			dst.numStates = ns;
			for (uword i = 0; i < ns; ++i) {
				dst.lastWrittenStates[i] = src.lastWrittenStates[i];
				dst.stateImportances[i] = src.stateImportances[i];
				dst.lastWrittenAtTick[i] = src.lastWrittenAtTick[i];
			}
		}
	}

	alias .g_netObjects _netObjects;

	version (Server) {
		// Storage in mainHeap. TODO: something less prone to fragmentation or prealloc.
		NetObjData*[maxPlayers]	_netObjData;
	} else {
		NetObjData*				_netObjData;
	}

	ScratchFIFO		_rawStateQueue;
	ScratchFIFO		_objStatePtrQueue;

	ScratchFIFO		_objDataMem1;
	ScratchFIFO		_objDataMem2;

	ScratchFIFO*	_objDataMemCur;
	ScratchFIFO*	_objDataMemPrev;

	static this() {
		_objDataMemCur = &_objDataMem1;
		_objDataMemPrev = &_objDataMem2;
	}

	void swapObjDataMem() {
		// Swap allocators
		
		final t = _objDataMemCur;
		_objDataMemCur = _objDataMemPrev;
		_objDataMemPrev = t;

		// Realloc storage using the new allocator, copy the data

		void reallocData(NetObjData* data) {
			foreach (id, ref no; _netObjects) {
				if (no) {
					final numStates = data[id].numStates;
					final memReq = NetObjData.memRequired(numStates);
					final nd = NetObjData.alloc(_objDataMemCur.pushBack(memReq), numStates);
					NetObjData.copy(&nd, &data[id]);
				}
			}
		}

		version (Server) {
			foreach (ref d; _netObjData) {
				reallocData(d);
			}
		} else {
			reallocData(_netObjData);
		}

		// Purge the old data

		_objDataMemPrev.clear();
	}

	void allocObjStates(objId id, uword numStates) {
		final memReq = NetObjData.memRequired(numStates);

		version (Server) {
			foreach (ref d; _netObjData) {
				d[id] = NetObjData.alloc(_objDataMemCur.pushBack(memReq), numStates);
			}
		} else {
			_netObjData[id] = NetObjData.alloc(_objDataMemCur.pushBack(memReq), numStates);
		}
	}
	
	FixedQueue!(void*[])	_tickStateQueue;
	void*[]					_curTickStates;
	tick					_firstTickInQueue;
	tick					_lastTickInQueue;

	static this() {
		const maxTicksInQueue = 1024;
		const memReq = maxTicksInQueue * (void*[]).sizeof;
		_tickStateQueue = FixedQueue!(void*[])(mainHeap.allocRaw(memReq)[0..memReq]);
	}

	UidPool!(objId)			_uidPool;
}
