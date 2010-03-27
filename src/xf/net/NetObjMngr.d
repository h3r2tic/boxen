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



// Managed by NetObjMngr. In GC memory. May contain null elements.
extern (C) NetObj[] g_netObjects;

enum { maxStatesPerSnapshot = 512 }

// TODO: maybe make it dynamically allocated not to stress the linker
// NOTE: always stores data for <= tick that was current at the time receiveData()
// was called on the client / server. Use the data before advancing the simulation
// or explicitly compare it to the data from the tick before the simulation.
struct LastPlayerSnapshotData {
static:
	objId[maxStatesPerSnapshot][maxPlayers]		id;
	ushort[maxStatesPerSnapshot][maxPlayers]	stateIdx;
	void*[maxStatesPerSnapshot][maxPlayers]		data;
	uword[maxPlayers]							length;
	tick[maxPlayers]							dataTick;

	void reset() {
		length[] = 0;
	}

	bool addSnapshot(playerId pid, objId oid, ushort stateI, tick t, void* d) {
		if (dataTick[pid] != t) {
			length[pid] = 0;
			dataTick[pid] = t;
		}
		if (length[pid] >= maxStatesPerSnapshot) {
			return false;
		}
		uword i = length[pid]++;
		id[pid][i] = oid;
		stateIdx[pid][i] = stateI;
		data[pid][i] = d;
		return true;
	}

	int find(playerId pid, objId oid, void*[] result) {
		final len = length[pid];
		int numFound = 0;
		foreach (i, storedOid; id[pid][0..len]) {
			if (storedOid == oid) {
				result[stateIdx[pid][i]] = data[pid][i];
				++numFound;
			}
		}
		return numFound;
	}
}

// Defined in xf.net.GameClient
version (Client) extern (C) extern {
	playerId	g_localPlayerId;
	tick		g_lastTickRecvd;
}


objId allocId() {
	return _uidPool.alloc().id;
}


void freeId(objId id) {
	_uidPool.free(_uidPool.UID(id));
}

import xf.boxen.model.IPlayerController;

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
		numStates > 0
		?	(cast(void**)_objStatePtrQueue.pushBack(
				numStates * (void*).sizeof
			))[0..numStates]
		: null;
	
	foreach (i, netObj; _netObjects) {
		if (netObj !is null) {
			withStateInfo(netObj, (NetObjInfo* netObjInfo) {
				void* state = _rawStateQueue.pushBack(netObjInfo.totalStateSize);
				statePtrs[i] = state;
				foreach (nsi; netObjInfo.netStateInfo) {
					nsi.store(netObj, state);

					/+char[] delegate() stringize;
					stringize.funcptr = nsi.stringize;
					stringize.ptr = state;
					log.trace("@tck {} storing state of obj {}:\n{}", curTick, i, stringize());+/
					
					// TMP
					// setPosition/setTransform/setRotation wreck internal havok state
					// and e.g. pushing a box by a controller is not smooth any more :(
					// reintegration doesn't help
					/+if (cast(IPlayerController)netObj is null) {
						nsi.load(netObj, state);
					}+/
					
					state += nsi.size;
				}
			});
		} else {
			statePtrs[i] = null;
		}
	}

	if (_tickStateQueue.isEmpty) {
		_firstTickInQueue = _lastTickInQueue = curTick;
	}
	
	*_tickStateQueue.pushBack() = statePtrs;
	_curTickStates = statePtrs;
	_lastTickInQueue = curTick;
}


/+float	readStateFromStream(playerId pid, uint stateI, tick tck, tick dropEarlierThan, BitStreamReader bs, StateOverrideMethod som)	{	// returns an error level
	if (_netObj_clientSideChecks) assert (0 == pid);
	
	foreach (i, dummy; States) {
		States[i]*	localState = getTimedState!(i)(pid, tck);
		States[i]	auth = States[i].init;
		
		xf.game.StateUtils.readState(auth, bs);
		/+printf("Received state:"\n);
		auth.dump((char[] txt) {
			printf("%.*s", txt);
		});
		printf("State dump end"\n);+/
		
		if (localState !is null) {
			/+printf("Local state:"\n);
			localState.dump((char[] txt) {
				printf("%.*s", txt);
			});
			printf("State dump end"\n);+/

			int numToRemove = 0;
			scope (exit) {
				while (numToRemove--) {
					stateQueues(pid).queues[i].removeHead();
				}
			}
			
			foreach (itemIdx, ref item; stateQueues(pid).queues[i]) {
				if (&item.state is localState) {
					break;
				} else {
					++numToRemove;
				}
			}

			float diff = xf.game.StateUtils.compareStates(*localState, auth);
			if (diff > 0.f) {
				switch (som) {
					case StateOverrideMethod.Replace:
						*localState = auth;		// store the state, for a future override
						break;
						
					case StateOverrideMethod.ApplyDiff:
						if (diff > 5.f) {
							*localState = auth;
							this.setState(auth, tck);
							_currentlySetStates[i] = auth;
							printf(\n"State difference too huge. Hard snapping"\n);
							break;
						}
					
						synchronized (queueMutex) {
							auto q = stateQueues(pid).queues[i];

							int qlen = q.length;
							
							const bool canApplyDiff = is(typeof(this.applyStateDiff(States[i].init, States[i].init, tick.init)));
							
							static if (canApplyDiff) {
								States[i] prev = *localState;
								this.setState(auth, tck);
								_currentlySetStates[i] = auth;
								*localState = auth;
								
								foreach (itemIdx, ref item; q) {
									if (item.tck > tck) {
										States[i] foo;
										this.getState(&foo);
										this.applyStateDiff(prev, item.state, tck);
										States[i] bar;
										this.getState(&bar);
										
										static if (is(typeof(bar.pos))) {
											auto diff = bar.pos - foo.pos;
											Stdout.formatln("moved {}; wanted {}", diff, item.state.pos - prev.pos);
										}
										
										prev = item.state;
										item.state = bar;
										//this.getState(&item.state);
										_currentlySetStates[i] = item.state;
									}
								}												
							} else {
								States[i]	prev = *localState;
								States[i]*	prevAuth = &auth;
								const constMult = 1.f;
								const multMult = 1.f;
								float mult = 1.f;
								foreach (itemIdx, ref item; q) {
									if (item.tck > tck) {
										auto backup = item.state;
										item.state = *prevAuth;
										item.state.applyDiff(prev, backup, mult * constMult);
										mult *= multMult;
										prev = backup;
										prevAuth = &item.state;
									}
									
									if (qlen-1 == itemIdx) {
										this.setState(item.state, item.tck);
										_currentlySetStates[i] = item.state;
										/+printf("Set delta'd state:"\n);
										item.state.dump((char[] txt) {
											printf("%.*s", txt);
										});
										printf("State dump end"\n);+/
										break;
									}
								}

								*localState = auth;
							}

							
							/+foreach (itemIdx, ref item; q) {
								if (item.tck > tck) {
									item.state.applyDiff(*localState, auth);
								}
								
								if (qlen-1 == itemIdx) {
									this.setState(item.state, item.tck);
								}
							}+/
							
							if (this.isPredicted) {
								//printf("* applied a state diff to a predicted object"\n);
							}
							
							diff = 0.f;
						}
						break;
				}
			}
			
			return diff;
		} else {
			//printf(`state not found!!!`\n);
			auto q = &stateQueues(pid).queues[i];

			while (!q.isEmpty && (*q)[0].tck < dropEarlierThan) {
				q.removeHead();
			}

			q.addTail(StateQueueItem!(States[i])(auth, tck));		// store the state, for a future override
			int qlen = q.length;
			const int maxQLen = 200;
			if (qlen > maxQLen) {
				//printf("1state queue len: %d :S removing some"\n, qlen);
				for (int j = maxQLen; j < qlen; ++j) {
					q.removeHead;
				}
			}
			return 1.f;
		}
	}
	}

			assert (false);	// should never get here
		});
	}+/


float applyObjectState(
		playerId pid,
		NetObj obj,
		tick stateForTick,
		void* auth,
		void* localStateMem,
		NetStateInfo* stateInfo,
		StateOverrideMethod som
) {
	float diff = stateInfo.calcDifference(auth, localStateMem);

	switch (som) {
		case StateOverrideMethod.Replace: {
			stateInfo.load(obj, auth);

			// store the state in case something might want to query it later
			memcpy(localStateMem, auth, stateInfo.size);
		} break;
		
		case StateOverrideMethod.ApplyDiff: {
			if (diff <= 0.0f) {
				return 0.0f;
			}

			const hardSnapErrorThresh = 5.0f;

			if (diff > hardSnapErrorThresh) {
				stateInfo.load(obj, auth);

				log.info("State difference is large ({}). Hard snapping.", diff);

				// store the state in case something might want to query it later

				for (
						tick tck = stateForTick;
						tck < _lastTickInQueue;
						++tck
				) {
					void*[] tickStatePtrs = *_tickStateQueue[tck - _firstTickInQueue];
					assert (tickStatePtrs !is null);
					assert (tickStatePtrs[obj.id] !is null);
					void* tickState = tickStatePtrs[obj.id] + stateInfo.offset;
					memcpy(tickState, auth, stateInfo.size);
				}

				break;
			}

			//auto q = stateQueues(pid).queues[i];

			//int qlen = q.length;
			
			if (stateInfo.applyDiffToObject !is null) {
				//log.trace("Running state fixup algorithm #1.");

//final foo = _objDataMemCur.pushBack(stateInfo.size);
				final bar = _objDataMemCur.pushBack(stateInfo.size);
				final prev = _objDataMemCur.pushBack(stateInfo.size);

				//void* prev = *localState;
				memcpy(prev, localStateMem, stateInfo.size);
				stateInfo.load(obj, auth);
				memcpy(localStateMem, auth, stateInfo.size);

				for (
						tick tck = cast(tick)(stateForTick+1);
						tck < _lastTickInQueue;
						++tck
				) {

					void*[] tickStatePtrs = *_tickStateQueue[tck - _firstTickInQueue];
					assert (tickStatePtrs !is null);
					assert (tickStatePtrs[obj.id] !is null);
					void* tickState = tickStatePtrs[obj.id] + stateInfo.offset;
				//foreach (itemIdx, ref item; q) {
					//if (item.tck > tck) {
						//States[i] foo;
//stateInfo.store(obj, foo);
						//this.getState(&foo);

						stateInfo.applyDiffToObject(obj, prev, tickState);
						//this.applyStateDiff(prev, item.state, tck);
						//States[i] bar;
						stateInfo.store(obj, bar);
						//this.getState(&bar);
						
						/+static if (is(typeof(bar.pos))) {
							auto diff = bar.pos - foo.pos;
							Stdout.formatln("moved {}; wanted {}", diff, item.state.pos - prev.pos);
						}+/

						memcpy(prev, tickState, stateInfo.size);
						//prev = item.state;
						memcpy(tickState, bar, stateInfo.size);
						//item.state = bar;
						//this.getState(&item.state);
						//_currentlySetStates[i] = item.state;
					//}
				}
			} else {
				//log.trace("Running state fixup algorithm #3.");

				/+final zero = _objDataMemCur.pushBack(stateInfo.size);
				memset(zero, 0, stateInfo.size);

				{
					void delegate(void* a, void* b, float) applyDiff;
					applyDiff.funcptr = stateInfo.applyDiff;
					applyDiff.ptr = zero;
					zero[0..stateInfo.typeInfo.init.length] = stateInfo.typeInfo.init;
					applyDiff(localStateMem, auth, 1.0f);

					char[] delegate() meh;
					meh.ptr = zero;
					meh.funcptr = stateInfo.stringize;
					log.trace("Diff: {}", meh());
				}+/

				//int spam = 1;

				const resetFactor = 0.1f;
				
				for (
						tick tck = cast(tick)(stateForTick+1);
						tck <= _lastTickInQueue;
						++tck
				) {
					void*[] tickStatePtrs = *_tickStateQueue[tck - _firstTickInQueue];
					assert (tickStatePtrs !is null);
					assert (tickStatePtrs[obj.id] !is null);
					void* tickState = tickStatePtrs[obj.id] + stateInfo.offset;

					void delegate(void* a, void* b, float) applyDiff;
					applyDiff.funcptr = stateInfo.applyDiff;
					applyDiff.ptr = tickState;
					applyDiff(localStateMem, auth, resetFactor);

					char[] delegate() meh;
					meh.ptr = tickState;
					meh.funcptr = stateInfo.stringize;

					/+if (spam-- > 0) {
						log.trace("Approx state for tck {}:\n{}", tck, meh());
					}+/

					if (tck == _lastTickInQueue) {
						// in case it might be needed somewhere
						applyDiff.ptr = localStateMem;
						applyDiff(localStateMem, auth, resetFactor);

						//assert (stateInfo.calcDifference(auth, localStateMem) < 0.001f);

						stateInfo.load(obj, tickState);
						break;
					}
				}

				memcpy(localStateMem, auth, stateInfo.size);
			}/+ else {
				log.trace("Running state fixup algorithm #2.");
				
				final prev = _objDataMemCur.pushBack(stateInfo.size);
				final backup = _objDataMemCur.pushBack(stateInfo.size);
				void* prevAuth = auth;

				memcpy(prev, localStateMem, stateInfo.size);
				
				float constMult = 0.98f;
				float multMult = 0.99f;
				float mult = 1.f;

				version (Client) {
					if (cast(IPlayerController)obj && obj.realOwner == g_localPlayerId) {
						constMult = multMult = 1.0f;
					}
				}

				for (
						tick tck = cast(tick)(stateForTick+1);
						tck <= _lastTickInQueue;
						++tck
				) {
					void*[] tickStatePtrs = *_tickStateQueue[tck - _firstTickInQueue];
					assert (tickStatePtrs !is null);
					assert (tickStatePtrs[obj.id] !is null);
					void* tickState = tickStatePtrs[obj.id] + stateInfo.offset;
				
					memcpy(backup, tickState, stateInfo.size);
					memcpy(tickState, prevAuth, stateInfo.size);

					void delegate(void* a, void* b, float) applyDiff;
					applyDiff.funcptr = stateInfo.applyDiff;
					applyDiff.ptr = tickState;
					applyDiff(prev, backup, mult * constMult);

					mult *= multMult;
					memcpy(prev, backup, stateInfo.size);
					prevAuth = tickState;
					
					if (tck == _lastTickInQueue) {
						stateInfo.load(obj, tickState);
						break;
					}
				}

				memcpy(localStateMem, auth, stateInfo.size);
			}+/

			
			/+foreach (itemIdx, ref item; q) {
				if (item.tck > tck) {
					item.state.applyDiff(*localState, auth);
				}
				
				if (qlen-1 == itemIdx) {
					this.setState(item.state, item.tck);
				}
			}+/
			
			if (obj.isPredicted) {
				//printf("* applied a state diff to a predicted object"\n);
			}
			
			diff = 0.f;
		} break;

		default: assert (false);
	}	

	return diff;
}


version (Server) void* getStateStoredForObjectAtTick(objId id, ushort stateI, tick tck) {
	assert (id < g_netObjects.length && g_netObjects[id] !is null);
	
	if (tck < _firstTickInQueue || tck > _lastTickInQueue || _tickStateQueue.isEmpty) {
		return null;
	}
	
	void*[] ptrs = *_tickStateQueue[tck - _firstTickInQueue];
	void* base = ptrs[id];
	
	if (base is null) {
		return null;
	}

	return base + g_netObjects[id].getNetObjInfo().netStateInfo[stateI].offset;
}


float applyObjectState(
		playerId pid,
		NetObj obj,
		tick stateForTick,
		void* stateMem,
		ushort stateI,
		NetStateInfo* stateInfo,
		StateOverrideMethod som
) {
	assert (obj !is null);
	
	if (
			stateForTick >= _firstTickInQueue
		&&	stateForTick <= _lastTickInQueue
		&& !_tickStateQueue.isEmpty
	) {
		void*[] localStatePtrs = *_tickStateQueue[stateForTick - _firstTickInQueue];
		
		if (localStatePtrs is null || localStatePtrs[obj.id] is null) {
			log.warn(
				"State {} for tick {} of net obj {} was not stored.",
				stateI,
				stateForTick,
				obj.id
			);

			stateInfo.load(obj, stateMem);

			return 0.0f;
		}

		void* localStateMem = localStatePtrs[obj.id] + stateInfo.offset;

		return applyObjectState(
			pid,
			obj,
			stateForTick,
			stateMem,
			localStateMem,
			stateInfo,
			som
		);
	} else {
		log.error(
			"State {} for tick {} of net obj {} not found.",
			stateI,
			stateForTick,
			obj.id
		);

		stateInfo.load(obj, stateMem);

		return 1e10;
	}
}


float receiveStateSnapshot(tick curTick, playerId pid, BitStreamReader* bs) {
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

	// Allocate off the per-tick memory storage so the states may be used within
	// the current tick (stored in LastPlayerSnapshotData later in this function)
	final stateMem = _objDataMemCur.pushBack(stateMemSize);

	void delegate(BitStreamReader*) dg;
	dg.funcptr = stateInfo[stateI].unserialize;
	dg.ptr = stateMem;
	dg(bs);

	version (Client) {
		tick tickRecvd = g_lastTickRecvd;
	} else {
		tick tickRecvd = curTick;
	}

	bool stored = LastPlayerSnapshotData.addSnapshot(pid, id, stateI, tickRecvd, stateMem);
	if (!stored) {
		// TODO: kick the player
		error("LastPlayerSnapshotData backlog overflow. Can't receive more snapshots than {}.", maxStatesPerSnapshot);
	}

	/+version (Client) {
		char[] delegate() stringize;
		stringize.funcptr = stateInfo.stringize;
		stringize.ptr = stateMem;
		log.trace("@tck {} recvd state for tck {} of obj {}:\n{}", curTick, g_lastTickRecvd, id, stringize());
	}+/

	// ----------------------------------------------------------------


	playerId objAuth = obj.authOwner;

	version (Server) {
		bool localAuthority = ServerAuthority == objAuth || NoAuthority == objAuth;
		bool locallyOwned = false;
		//printf("received obj %d state for tick %d. Current tick %d; localAuth: %.*s"\n, id, lastTickRecvd, timeHub.currentTick, localAuthority ? "true" : "false");
	} else {
		bool locallyOwned = obj.realOwner == g_localPlayerId;
		bool localAuthority =	g_localPlayerId == objAuth
								|| (obj.authRequested && NoAuthority == objAuth);
	}
	
	if (!localAuthority) {
		StateOverrideMethod som = StateOverrideMethod.Replace;
		version (Client) if (locallyOwned || (obj.authRequested && NoAuthority == obj.realOwner)) {
			som = StateOverrideMethod.ApplyDiff;
		}

		// TODO: drop some olde states (or maybe have a fixed queue of them?)

		version (Server) {
			if (pid != obj.authOwner) {
				log.warn(
					"Client {} tried to send a snapshot for object owned by {}.",
					pid,
					obj.authOwner
				);
				return 0.0f;
			}
		}

		float objError = applyObjectState(
			pid,
			obj,
			tickRecvd,
			stateMem,
			stateI,
			stateInfo,
			som
		);

		if (obj.isPredicted && true == stateInfo.isCritical) {
			//debug printf(`Obj state error: %f`\n, objError);
			return objError;
		}
	}

	return 0.0f;
}


void dropStatesOlderThan(tick tck) {
	int numToDrop = tck - _firstTickInQueue;
	while (numToDrop-- > 0 && !_tickStateQueue.isEmpty) {
		void*[] ptrs = *_tickStateQueue.popFront();
		++_firstTickInQueue;
		if (ptrs) {
			assert (!_objStatePtrQueue.isEmpty());
			foreach (p; ptrs) {
				if (p) {
					_rawStateQueue.popFront(p);
				}
			}
			_objStatePtrQueue.popFront(ptrs.ptr);
		}
	}
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


/// See the documentation of _objDataMem1, etc for more details on this function
void swapObjDataMem() {
	// Will be invalid after this step
	LastPlayerSnapshotData.reset();
	
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
				data[id] = nd;
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



private {
	void withStateInfo(NetObj obj, void delegate(NetObjInfo*) sink) {
		sink(obj.getNetObjInfo());
	}


	// Pretty arbitrary, just large so unsent states get priority
	const float _defaultStateImportance = 1e+10;

	// Not zero, so even still objects get updated sometimes to verify their states
	const float _minStateImportance = 1e-10;

	void updateStateImportances(NetObjData* objData) {
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
					assert (_curTickStates !is null);
					final curStateRaw = _curTickStates[id];
					final curState = curStateRaw + stateInfo[stateI].offset;
					
					final float diff = stateInfo[stateI]
						.calcDifference(wrState, curState);

					imp += diff;
				} else {
					imp += _defaultStateImportance;
				}
			}
		}
	}


	void resetStateImportances(NetObjData* objData) {
		foreach (id, obj; _netObjects) {
			if (obj !is null) {
				final data = &objData[id];
				data.stateImportances[0..data.numStates] = _defaultStateImportance;
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

		uword numWritten = 0;
		foreach (ref s; osiMem) {
			if (writer.canWriteMore && numWritten++ < .maxStatesPerSnapshot) {
				final obj = _netObjects[s.id];
				assert (obj !is null);

				final stateInfo = obj.getNetObjInfo.netStateInfo;
				final curStateRaw = _curTickStates[s.id];
				final curState = curStateRaw + stateInfo[s.state].offset;

				/+log.trace(
					"Writing state {} ({}) (i={}) of obj {} ({})",
					s.state,
					stateInfo[s.state].typeInfo.toString,
					s.importance,
					s.id,
					(cast(Object)obj).classinfo.name
				);+/

				void delegate(BitStreamWriter*) dg;
				dg.funcptr = stateInfo[s.state].serialize;
				dg.ptr = curState;

				writer.bsw.write(cast(ushort)s.id);
				writer.bsw.write(cast(ushort)s.state);
				dg(&writer.bsw);

				final data = &objData[s.id];
				data.stateImportances[s.state] = _minStateImportance;
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

	/**
	 * Memory for object states that are saved each tick is allocated off _rawStateQueue
	 * in chunks where all states of an object are a consecutive block. To get the
	 * memory for a particular state, add the .offset field of the NetStateInfo
	 * of said object.
	 * 
	 * Arrays of pointers to net object state data are allocated off _objStatePtrQueue.
	 * 
	 * Finally, pointers to state data of each particular tick are stored in
	 * _tickStateQueue, which is a fixed-size queue. The first and last ticks of
	 * states stored within it are _firstTickInQueue and _lastTickInQueue respectively.
	 * The maximal number of ticks that can be stored in the queue is maxTicksInQueue.
	 *
	 * Thus, in order to find the state ST of a NetObject OBJ at tick TCK, use the
	 * following approach:
	 *
	 * assert (TCK >= _firstTickInQueue && TCK <= _lastTickInQueue);
	 * if (!_tickStateQueue.isEmpty) {
	 * 		void*[] tickStatePtrs = *_tickStateQueue[TCK - _firstTickInQueue];
	 * 		final stateInfo = OBJ.getNetObjInfo().netStateInfo[ST];
	 *		void* tickState = tickStatePtrs[OBJ.id] + stateInfo.offset;
	 * } else {
	 *		// not available
	 * }
	 */

	ScratchFIFO		_rawStateQueue;
	ScratchFIFO		_objStatePtrQueue;

	FixedQueue!(void*[])	_tickStateQueue;
	void*[]					_curTickStates;
	tick					_firstTickInQueue;
	tick					_lastTickInQueue;

	/**
	 * The states last received from peers, as well as NetObjData for each NetObj
	 * and some scratch memory are stored in one of the two  FIFOs: _objDataMem1
	 * or _objDataMem2.
	 * 
	 * They should be swapped each tick (or every few ticks) using the function
	 * swapObjDataMem(). This function will remove all the last received states, since
	 * at the end of a tick they will not be required any more. On the other hand,
	 * NetObjData must be retained from tick to tick, thus swapObjDataMem() copies
	 * the memory.
	 *
	 * While this approach requires some shuffling of data, it only uses chunked
	 * allocation, thus keeps fragmentation and heap activity low, despite potentially
	 * very dynamic changes to NetObj states. The copying of data at each buffer swap
	 * also means that memory will be packed together instead of scattered around the
	 * heap, thus improving cache efficiency.
	 *
	 * The buffer currently used for allocation is _objDataMemCur, while the previous
	 * one (and thus also next) is _objDataMemPrev.
	 */

	ScratchFIFO		_objDataMem1;
	ScratchFIFO		_objDataMem2;

	ScratchFIFO*	_objDataMemCur;
	ScratchFIFO*	_objDataMemPrev;

	static this() {
		_objDataMemCur = &_objDataMem1;
		_objDataMemPrev = &_objDataMem2;
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


	static this() {
		const maxTicksInQueue = 1024;
		const memReq = maxTicksInQueue * (void*[]).sizeof;
		_tickStateQueue = FixedQueue!(void*[])(mainHeap.allocRaw(memReq)[0..memReq]);
	}

	UidPool!(objId)			_uidPool;
}
