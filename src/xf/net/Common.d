module xf.net.Common;

private {
	import xf.utils.BitStream;
	import xf.net.NetObj;
	//import xf.utils.StructClass : simpleStructCtor;
}

public {
	import xf.game.Misc : ServerAuthority, NoAuthority;
	
	import mintl.arrayheap : ArrayHeap;
	import mintl.sortedaa : SortedAA;
	import mintl.mem : MallocNoRoots;

	import xf.utils.Memory : alloc, realloc, free;
	import xf.utils.BitSet;


	const uint maxStates = 256;

	static if (maxStates <= 256) {
		alias ubyte StateIdx;
	} else
	static if (maxStates <= 65536) {
		alias ushort StateIdx;
	} else {
		alias ushort StateIdx;		// just so the compiler doesn't complain anywhere else
		static assert(false, `Are you nuts?!`);
	}

	alias BitSet!(maxStates) StateSet;
	alias ArrayHeap!(NetObjStateImportance, MallocNoRoots)	StateSorterHeap;
	alias SortedAA!(void*, StateSet, false, MallocNoRoots)	StateSorterHash;
}



struct NetObjStateImportance {
	NetObjBase	netObj;
	float		importance;
	StateIdx	stateIdx;
	
	int opCmp(NetObjStateImportance* rhs) {
		if (importance > rhs.importance) return 1;
		if (importance < rhs.importance) return -1;
		return 0;
	}
}



template MNetComm(bool serverSide) {
	private {
		import tango.stdc.stdio : printf;
		import Integer = tango.text.convert.Integer;
		//import xf.utils.GenericBitStream;
		//import tango.io.digest.Crc32;
	}
	
	const bool clientSide = !serverSide;
	

		static if (serverSide) {
			struct NetObjData {
				float[][]	importances;
				
				void destroy() {
					foreach (ref a; importances) {
						a.free();
					}
					
					importances.free();
				}
			}
		} else {
			struct NetObjData {
				float[]	importances;
				
				void destroy() {
					importances.free();
				}
			}
		}


	void onNetObjCreated(NetObjBase o) {
		printf(`Registering a netObj with id %d`\n, cast(int)o.netObjId);
		if (o.netObjRef()) {
			netObjects[o.netObjId] = o;
			netObjData[o] = constructNetObjData(o);
		}
	}
	
	
	void onNetObjDestroyed(NetObjBase o) {
		// remove the NetObjData ?
		// need to do that safely, because a snapshot thread might be running.
	}


	NetObjBase getNetObj(objId id) {
		debug printf(`getting a net obj with id %d`\n, cast(int)id);
		if (!(id in netObjects)) {
			printf(`WTF. no %d in netObjects`\n, cast(int)id);
		}
		return netObjects[id];
	}	
	
	NetObjData constructNetObjData(NetObjBase o) {
		NetObjData d;
		
		static if (serverSide) {
			d.importances.alloc(players.length);
			
			foreach (ref imp; d.importances) {
				imp.alloc(o.numStateTypes, false);		// dont init to float.init (NaN)
				imp[] = 0.f;
			}
		} else {
			d.importances.alloc(o.numStateTypes, false);		// dont init to float.init (NaN)
			d.importances[] = 0.f;
		}
		
		return d;
	}
	
	
	protected void consume(Event evt, tick target) {
		static if (serverSide) {
			if (auto order = cast(Order)evt) {
				
				auto mask = (playerId pid) {
					if (auto player = players[pid]) {
						if ((order.destinationFilter is null || order.destinationFilter(pid)) && player.orderMask(order)) {
							auto budgetWriter = playerBudgetWriters[pid];
							budgetWriter(true);
							budgetWriter(uint.init);
							writeEvent(budgetWriter, order);
							return true;
						}
					}
					
					return false;
				};
				
				impl.broadcast((BitStreamWriter bs) {
					bs(true /* event */);
					bs(cast(uint)target);
					writeEvent(bs, order);
				}, mask);
			}
		} else {
			if (auto wish = cast(Wish)evt) {
				impl.send = (BitStreamWriter bs) {
					bs(true /* event */);
					bs(cast(uint)target);
					writeEvent(bs, wish);
				};
			}
		}
	}
	
	
	//private {
		mixin MRemovePendingNetObjects;
		

		void updatePeer(playerId pid, StateSorter* sorter, BudgetWriter budgetWriter) {
			static if (serverSide) {
				auto player = players[pid];
				int updatesPerSecond = snapshotsPerSecond;
				int bbps = player.bitBudgetPerSecond;
			} else {
				int updatesPerSecond = timeHub.ticksPerSecond;
				int bbps = serverBitBudgetPerSecond;
			}
			
			budgetWriter.bitBudget += bbps / updatesPerSecond;
			if (budgetWriter.bitBudget > bbps) {
				budgetWriter.bitBudget = bbps;
			}

			debug printf(`Determining relevant NetObjects from %d total`\n, netObjects.keys.length);
			
			foreach (netObj, ref netObjData; netObjData) {
				/**
					Don't update objects not controlled by the local client
				*/
				static if (clientSide) {
					if (!netObj.keepServerUpdated) {
						continue;
					}
				}
				
				static if (serverSide) {
					float objRelevance = calculateRelevance(pid, netObj);
				} else {
					// TODO
					float objRelevance = 1.f;
				}
				
				if (0.f == objRelevance) continue;		// TODO: maybe it could use an epsilon?
				
				int numStates = netObj.numStateTypes;
				for (int state = 0; state < numStates; ++state) {
					static if (serverSide) {
						float scaledImp = netObjData.importances[pid][state] * objRelevance;
					} else {
						float scaledImp = netObjData.importances[state] * objRelevance;
					}
					if (0.f == scaledImp) continue;
					
					sorter.heap.addTail(NetObjStateImportance(netObj, scaledImp, state));
				}
			}
			
			int bitBudget = budgetWriter.bitBudget;

			debug printf(`Determining important states from %d total`\n, sorter.heap.length);
			while (budgetWriter.canWriteMore && !sorter.heap.isEmpty) {
				auto state = sorter.heap.takeHead();
				
				int budgetBefore = budgetWriter.bitBudget;
				
				budgetWriter(true);		// writes one bit
				state.netObj.writeStateToStream(pid, state.stateIdx, budgetWriter, false);
				
				// TODO: replace this and budget writers with just checking how many bits the real bitstream stored
				// BUG: the net object will save its last written state in writeStateToStream, thinking that it got transmitted
				// this will break delta update prioritization
				if (budgetWriter.bitBudget < 0) {		// no more writes, sorry :P
					budgetWriter.bitBudget = budgetBefore;
					break;
				}
				
				debug printf(`important netobj: %d state: %d importance: %f`\n, cast(int)state.netObj.netObjId, cast(int)state.stateIdx, state.importance);
				StateSet* stateSet = sorter.hash.get(cast(void*)state.netObj);
				if (stateSet is null) {
					stateSet = sorter.hash.put(cast(void*)state.netObj);
					*stateSet = StateSet.init;		// TODO: check if this is already initialized here
				}
				
				(*stateSet)[state.stateIdx] = true;
			}
			
			int sendingBits = bitBudget - budgetWriter.bitBudget;
			
			static if (serverSide) {
				//printf(`Sending %d bits to player %d. Player budget: %d`\n, sendingBits, cast(int)pid, budgetWriter.bitBudget);
			}
			
			if (sendingBits > 0) {
				static if (serverSide) {
					sendSnapshotToPlayer(sorter.hash, pid);
				} else {
					sendSnapshotToServer(sorter.hash);
				}
			}
		}

	
		static if (serverSide) {
			void updatePlayer(playerId pid) {
				getStateSorter((StateSorter* sorter) {
					auto player = players[pid];
					auto budgetWriter = playerBudgetWriters[pid];
					updatePeer(pid, sorter, budgetWriter);
				});

				// update importances of states for this net object
				foreach (netObj, ref netObjData; netObjData) {
					foreach (i, ref imp; netObjData.importances[pid]) {
						imp += netObj.getStateImportance(pid, i);
					}
				}
			}
		} else {
			void updateServer() {
				getStateSorter((StateSorter* sorter) {
					updatePeer(0/*ignored*/, sorter, serverBudgetWriter);
				});

				// update importances of states for this net object
				foreach (netObj, ref netObjData; netObjData) {
					foreach (i, ref imp; netObjData.importances) {
						imp += netObj.getStateImportance(0, i);
					}
				}
			}
		}
		
		
		void sendSnapshotToPeer(playerId pid, ref StateSorterHash sorterHash, BudgetWriter budgetWriter_, BitStreamWriter bsw_) {
			bool tickSent = false;
			void sendTickData() {
				budgetWriter_(false);
				bsw_(false);		// not an event

				if (!tickSent) {
					bsw_(cast(uint)timeHub.currentTick+1);
					budgetWriter_(uint.init);

					tickSent = true;
					debug printf(`Wrote a tick`\n);
				}
			}

			foreach (ref void* netObj__, ref StateSet states; sorterHash) {
				/+budgetWriter(false);
				bsw(false);		// not an event+/
				
				sendTickData();

				NetObjBase netObj = cast(NetObjBase)netObj__;
				
				// group states by object, white state bits and serialize states into real bit stream writers
				
				//printf(`Sending a NetObj snapshot...`\n);
				
				static if (is(objId Tmp == typedef) || true) {		// write the NetObj's id
					bsw_(cast(Tmp)netObj.netObjId());
					budgetWriter_(Tmp.init);
				}
				
				void writeObjStates(BitStreamWriter bsw) {
					int numStates = netObj.numStateTypes;
					
					int nextState = 0;
					void writeZeroes(int curState) {
						while (nextState < curState) {
							bsw(false);		// 0 => this state is skipped in the snapshot
							++nextState;
						}
					}
					
					auto netObjData = netObj in this.netObjData;
					
					states.iter((uint state) {
						writeZeroes(state);
						bsw(true);				// 1 => this state is being serialized
						debug (Networking) bsw(nextState);
						++nextState;		// will prevent writing a zero for this state
						
						//printf(`Writing state %d`\n, state);
						netObj.writeStateToStream(pid, state, bsw, false);
						
						static if (serverSide) {
							netObjData.importances[pid][state] = 0;		// sent, so reset the importance
						} else {
							netObjData.importances[state] = 0;		// sent, so reset the importance
						}
					});
					
					writeZeroes(numStates);		// for the trailing states that are not getting sent
				}
				
				// TODO: TLS me
				static GenericBitStreamWriter subWriter;
				if (subWriter is null) {
					subWriter = new GenericBitStreamWriter;
				} else {
					subWriter.reset;
				}
				
				writeObjStates(subWriter);
				void[] data = subWriter.data;
				ushort bytes = data.length;
				bsw_(bytes);
				
				if (bytes > 0) {
					bsw_.raw(data);
					/+scope crc = new Crc32;
					crc.update(cast(ubyte[])data);
					printf("Written a snapshot with %d bytes (%d bits) crc = %d\n", cast(int)bytes, subWriter.length, crc.crc32Digest);+/
				}
				/+foreach (b; cast(ubyte[])data) {
					printf("%2.2x ", cast(int)b);
				}
				printf("\n");+/
				
				writeObjStates(budgetWriter_);
				
				debug printf(`NetObj done`\n);
			}
			
			if (!tickSent) {
				sendTickData();
			}
		}

		
		static if (serverSide) {
			void sendSnapshotToPlayer(ref StateSorterHash sorterHash, playerId pid) {
				auto player = players[pid];
				auto budgetWriter = playerBudgetWriters[pid];
				
				impl.send((BitStreamWriter bs) {
					sendSnapshotToPeer(pid, sorterHash, budgetWriter, bs);
				}, pid);
			}
		} else {
			void sendSnapshotToServer(ref StateSorterHash sorterHash) {
				impl.send((BitStreamWriter bs) {
					sendSnapshotToPeer(0/*ignored*/, sorterHash, serverBudgetWriter, bs);
				});
			}
		}
		
		
		static if (serverSide) {
			float calculateRelevance(playerId pid, NetObjBase netObj) {
				if (relevanceCalcFunc !is null) {
					return relevanceCalcFunc(pid, netObj);
				}
				else return 1.f;
			}
		}



		tick readTick(BitStreamReader bs) {
			uint tmp;
			bs(&tmp);
			return cast(tick)tmp;
		}


	void receiveData() {
		//printf("NetComm: receiveData@ %d"\n, cast(int)timeHub.currentTick);
		if (clientSide) {
			//printf("receiveData"\n);
		}
		
		synchronized (this) {	// if at func level, dmd 1.031 complains
			// it's handled elsewhere in the server
			static if (clientSide) {
				removePendingNetObjects();
			}
			
			static if (serverSide) {
				auto recvPacket = &impl.recvPacket;
			} else {
				bool recvPacket(StreamFate delegate(playerId, BitStreamReader) dg) {
					return impl.recvPacket((BitStreamReader bsr) {
						return dg(0/*ignored*/, bsr);
					});
				}
			}
			
			while (recvPacket((playerId pid, BitStreamReader bs) {
				//printf("packet: ");
				//scope (exit) printf("\n");
				float	accumulatedError = 0;
				const float errorEpsilon = 0.0001f;
				
				static if (serverSide) {
					bool streamRetained = false;
					
					void lastTickRecvd(tick t) {
						if (pid < players.length) {
							players[pid].lastTickRecvd = t;
						}
					}
				}
				
				bool receivedTick = streamRetained;
				
				while (bs.moreBytes) {
					bool eventInStream = !streamRetained;
					
					if (eventInStream && (bs(&eventInStream), eventInStream)) {
						//printf("event");
						if (!receiveEvent(pid, bs)) {
							//printf("donotwant");
							streamRetained = false;
							return StreamFate.Dispose;		// do not want
						}
					} else {
						if (!receivedTick) {
							//printf("tick");
							receivedTick = true;
							/+static if (clientSide) {
								bs(&tickOffsetTuning);		// read the tick offset the server gives us for synchronization
							}+/
							
							lastTickRecvd = readTick(bs);
							
							static if (clientSide) {
								if (timeHub.currentTick > lastTickRecvd) {
									timeHub.trimHistory(timeHub.currentTick - lastTickRecvd);
								}
							}
						}							
						streamRetained = false;
						
						static if (clientSide) {
							if (lastTickRecvd > timeHub.currentTick) {
								debug printf(`retaining stream and returning... (recvd: %d, local: %d)`\n, lastTickRecvd, timeHub.currentTick);
								streamRetained = true;
								return StreamFate.Retain;
							}
						}
						
						if (bs.moreBytes) {
							//printf("snapshot");
							receiveStateSnapshot(pid, bs, &accumulatedError);
						}
					}
				}
				
				static if (clientSide) {
					if (connectedToServer) {
						if (accumulatedError >= errorEpsilon && lastTickRecvd < timeHub.currentTick) {
							printf(`Accum error: %f`\n, accumulatedError);
							accumulatedError = 0.f;
							this.rollbackTo(lastTickRecvd);
						}
					}
				}
				
				streamRetained = false;
				return StreamFate.Dispose;		// continues the loop if there are more packets to handle
			})) {}
		}
	}


	void receiveStateSnapshot(playerId pid, BitStreamReader bs, float* accumulatedError) {
		debug printf(`reading a state snapshot from %d...`\n, cast(int)pid);
		
		static if (clientSide) {
			assert (timeHub.currentTick >= lastTickRecvd);
		}
		
		objId id; /* now read it: */ static if (is(objId Tmp == typedef) || true) {
			bs(cast(Tmp*)&id);
		} else static assert (false);
		
		//printf(`object id = %d`\n, cast(int)id);
		
		ushort snapshotBytes;
		bs(&snapshotBytes);
		//printf(`snapshotBytes = %d`\n, cast(int)snapshotBytes);

		if (0 == snapshotBytes) {
			return;
		}
		
		// TODO: TLS me
		static ubyte[] snapshotData;
		snapshotData.length = snapshotBytes;
		bs.raw(cast(void[])snapshotData);
		scope newBs = new GenericBitStreamReader(snapshotData);
		
		/+scope crc = new Crc32;
		crc.update(snapshotData);+/
		//printf(`snapshot bits = %d; crc = %d`\n, newBs.length, crc.crc32Digest);
		bs = newBs;
		
		if (!(id in netObjects)) {
			static if (clientSide) {
				throw new Exception("Received a state snapshot of a non-existing net object with id = " ~ Integer.toString(id));
			} else {
				/*
					It's possible that an object is destroyed at server-side but the client sends
					a state snapshot of it to the server. This is a valid situation and must be handled gracefully.
					In such a case, the state snapshot must be skipped and standard processing must resume
					
					Since we're creating a sub-stream to read the snapshot, we'll just do nothing here
				*/
				
				printf("Received a state snapshot of a non-existent object. Ignoring it.\n");
				return;
			}
		} else {
			NetObjBase obj = getNetObj(id);
			
			// get the obj and unserialize its state
			
			int numObjStates = obj.numStateTypes;
			for (int i = 0; i < numObjStates; ++i) {
				bool statePresent = false;
				bs(&statePresent);
				
				if (statePresent) {
					//printf(`Found state %d`\n, i);
					
					debug (Networking) {
						int writtenState;
						bs(&writtenState);
						assert (i == writtenState, "Buggy data transmission. Read state id = " ~ Integer.toString(writtenState));
					}
					
					static if (serverSide) {
						tick lastTickRecvd = players[pid].lastTickRecvd;
					}

					playerId objAuth = obj.authOwner;

					static if (serverSide) {
						bool localAuthority = ServerAuthority == objAuth || NoAuthority == objAuth;
						bool locallyOwned = false;
						//printf("received obj %d state for tick %d. Current tick %d; localAuth: %.*s"\n, id, lastTickRecvd, timeHub.currentTick, localAuthority ? "true" : "false");
					} else {
						bool locallyOwned = obj.realOwner == localPlayerId;
						bool localAuthority = localPlayerId == objAuth;
					}
					
					
					// TODO: don't use the diff method if the error is too large
					// this may result in huge discrepancies between server and client state
					// for instance, a controller might get stuck at server side but released at client
					// in such a case, diffs would probably faill, although they will work great for most cases
					StateOverrideMethod som = StateOverrideMethod.Replace;
					if (clientSide && !localAuthority && /+obj.predicted+/locallyOwned) {
						som = StateOverrideMethod.ApplyDiff;
					}
					
					static if (clientSide) {
						tick dropEarlier = lastTickRecvd;
					} else {
						tick dropEarlier = timeHub.currentTick;
					}
					float objError = obj.readStateFromStream(pid, i, lastTickRecvd, dropEarlier, bs, som);
					
					if (!localAuthority) {
						if (obj.predicted && true == obj.getStateCriticalness(i)) {
							debug printf(`Obj state error: %f`\n, objError);
							*accumulatedError += objError;
						} else if (StateOverrideMethod.Replace == som && clientSide) {
							obj.setToStoredState(pid, i, lastTickRecvd);
						}
					}
				} else {
					//printf(`No state %d`\n, i);
				}
			}
		}
		
		assert (!newBs.moreBits, Integer.toString(newBs.bitsRemaining) ~ " unread bits");
		//printf(`shapshot processed`\n);
	}



	bool receiveEvent(playerId player, BitStreamReader bs) {
		//printf("receiveEvent"\n);
		tick evtTargetTick = readTick(bs);

		static if (serverSide) {
			Event evt = readEventOr(bs, EventType.Wish, {
				printf(`Client tried to send an invalid event. Kicking.`\n);
				KickPlayer(player).delayed(5);
			});
			if (evt is null) return false;
			
			if (!players[player].wishMask(cast(Wish)evt)) {
				printf(`Wish blocked: %.*s`\n, evt.classinfo.name);
				return true;
			}
			
			with (cast(Wish)evt) {
				wishOrigin = player;
				//eventTargetTick = evtTargetTick;
				receptionTimeMillis = cast(uint)(hardwareTimer.timeMicros / 1000);
			}
			
			if (evtTargetTick < timeHub.currentTick) {
				//printf(`Wish targeted at %d arrived too late. currentTick: %d`\n, evtTargetTick, timeHub.currentTick);
			}
			
			evt.atTick(evtTargetTick);
		} else {
			Event evt = readEventOr(bs, EventType.Order, {
				throw new Exception(`Received an invalid event from the server`);
			});

			//printf(`Event for tick %d`\n, evtTargetTick);
			if (evtTargetTick < timeHub.currentTick) {
				printf(`# evtTargetTick < timeHub.currentTick`\n);
				if ((cast(Order)evt).strictTiming) {
					rollbackTo(evtTargetTick);
				} else {
					evt.eventTargetTick = evtTargetTick;
					// TODO: is this valid? perviously only control ImmediateEvents would be executed like this
					evt.handle();
					return true;
				}
			}
			
			if (cast(ImmediateEvent)evt) {
				debug printf(`handling the control event`\n);
				evt.handle();
			} else {
				debug printf(`submitting the %.*s...`\n, evt.classinfo.name);
				evt.atTick(evtTargetTick);
			}
		}
		
		return true;
	}


	int iterNetObjects(int delegate(ref NetObjBase) dg) {
		foreach (o, od; netObjData) {
			NetObjBase cpy = o;	// stupid foreach :F
			if (auto r = dg(cpy)) return r;
		}
		return 0;
	}
	
	
	void removeNetObject(NetObjBase o) {
		netObjData[o].destroy();
		netObjData.remove(o);
		netObjects.remove(o.netObjId);
		o.netObjUnref();
	}


	NetObjData[NetObjBase]	netObjData;
	NetObjBase[objId]				netObjects;


	// ----
		struct StateSorter {
			StateSorterHeap	heap;
			StateSorterHash	hash;
		}
	
/+		public static StateSorter createStateSorter__() {
			return StateSorter.init;
		}
		public static void reuseStateSorter__(StateSorter* s) {
			s.heap.eraseNoDelete();		// like .clear but doesnt free the internal storage
			s.hash.clear();
		}+/
		__thread StateSorter t_stateSorter;
		
		void getStateSorter(void delegate(StateSorter*) sink) {
			auto s = &t_stateSorter;
			s.heap.eraseNoDelete();		// like .clear but doesnt free the internal storage
			s.hash.clear();
			sink(&s);
		}
	//ScopedResource!(ThreadsafePool!(createStateSorter__, reuseStateSorter__)) getStateSorter;
	// ----
}
