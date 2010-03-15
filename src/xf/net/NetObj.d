module xf.net.NetObj;

private {
	import xf.game.Misc;
	import xf.game.GameObj;
	import xf.utils.BitStream;
	import xf.mem.Array;
	import tango.io.Stdout;
}




const maxStates = 256;

static assert (maxStates <= 256);
alias ubyte StateIdx;



/+
const maxClients = 32;


static bool _netObj_clientSideChecks = false;




interface NetObjObserver {
	void onNetObjCreated(NetObj o);
	void onNetObjDestroyed(NetObj o);
}


enum StateOverrideMethod {
	Replace,
	ApplyDiff
}+/


struct NetStateInfo {
	// These are to be used as delegates
	void function(BitStreamWriter*)
				serialize;
	void function(BitStreamReader*)
				unserialize;
	void function(void* b, void* dst, float)
				applyDiff;

	// Static functions of the game object
	void function(NetObj, void*)
				store;
	void function(NetObj, void*)
				load;

	// Free function operating on state instances
	float function(void*, void*)
				calcDifference;

	uword		size;
	TypeInfo	typeInfo;
}


struct NetObjInfo {
	NetStateInfo[]	netStateInfo;
	TypeInfo		typeInfo;
	size_t			totalStateSize;
}


void registerNetObjInfo(NetObjInfo info) {
	_netObjInfo.pushBack(info);
}


NetObjInfo* findNetObjInfo(TypeInfo ti) {
	foreach (ref info; _netObjInfo) {
		if (ti is info.typeInfo) {
			return &info;
		}
	}

	return null;
}


private {
	Array!(NetObjInfo)	_netObjInfo;
}


interface NetObj : GameObj {
	// Covered by MNetObj:
		uint	numNetStateTypes();
		void	getNetStateInfo(uint state, NetStateInfo* info);

		bool	isPredicted();
		void	overridePredicted(bool);

		/**
			A client-side NetObj may return true from keepServerUpdated,
			in such a case the client will keep updating the server with object
			data even though it doesn't own the object. This might be useful
			e.g. when the server takes control temporarily over
			the object but the client wants it back
		*/
		bool keepServerUpdated();

		bool netObjScheduledForDeletion();
		void netObjScheduleForDeletion();
	// ----

	void		dispose();

	playerId	authOwner();
	void		setAuthOwner(playerId pid);
	playerId	realOwner();
	void		setRealOwner(playerId pid);
}

void addNetObjScheduleForDeletionHandler(void delegate(NetObj) dg) {
	netObjScheduleForDeletionHandlers ~= dg;
}

private {
	void delegate(NetObj)[]	netObjScheduleForDeletionHandlers;
}


template MNetObj() {
	static if (!is(typeof(this._netStateInfo))) {
		protected {
			static {
				NetStateInfo[32]	_netStateInfo;
				int					_numNetStateInfo;
				bool				_netObjStaticFinalized;
			}

			NetEndpoint	_initializedForEndpoint;
			bool		_netObjInitialized;
			bool		_predicted;
			bool		_keepServerUpdated;
			bool		_netObjScheduledForDeletion;
		}


		static this() {
			assert (!_netObjStaticFinalized);
			_netObjStaticFinalized = true;
			size_t totalStateSize = 0;
			foreach (nsi; _netStateInfo[0.._numNetStateInfo]) {
				totalStateSize += nsi.size;
			}
			.registerNetObjInfo(NetObjInfo(
				_netStateInfo[0.._numNetStateInfo],
				typeid(typeof(this)),
				totalStateSize
			));
		}

		void	initializeNetObj(NetEndpoint endpt) {
			assert (!_netObjInitialized);
			_netObjInitialized = true;
			_initializedForEndpoint = endpt;
			// TODO: install a debug mechanism for detecing omission of disposal
		}

		void	disposeNetObj() {
			assert (_netObjInitialized);
		}

		uint	numNetStateTypes() {
			assert (_netObjInitialized);
			return _numNetStateInfo;
		}
		
		void	getNetStateInfo(uint state, NetStateInfo* info) {
			assert (_netObjInitialized);
			assert (state < _numNetStateInfo);
			*info = _netStateInfo[state];
		}
		


		bool	isPredicted() {
			return _predicted;
		}
		
		void	overridePredicted(bool p) {
			_predicted = p;
		}



		void keepServerUpdated(bool v) {
			_keepServerUpdated = v;
		}
		
		bool keepServerUpdated() {
			return _keepServerUpdated;
		}


		bool netObjScheduledForDeletion() {
			return _netObjScheduledForDeletion;
		}

		void netObjScheduleForDeletion() {
			synchronized (this) {
				if (!_netObjScheduledForDeletion) {
					_netObjScheduledForDeletion = true;
					foreach (h; .netObjScheduleForDeletionHandlers) {
						h(this);
					}
				}
			}
		}
	} else {
		static assert (false, "Cannot mixin MNetObj twice in " ~ typeof(this).stringof);
	}
}


template DeclareNetState(T) {
	static assert (is(typeof(this.storeState((T*).init)) == void));
	static assert (is(typeof(this.loadState((T*).init)) == void));
	static assert (
			is(typeof(T.applyDiff((T*).init, (T*).init, 0.0f)) == void)
		^	is(typeof(T.NotInterpolable))
	);
	static assert (is(typeof(T.serialize((BitStreamWriter*).init)) == void));
	static assert (is(typeof(T.unserialize((BitStreamReader*).init)) == void));
	static assert (is(typeof(T.calcDifference((T*).init, (T*).init)) == float));

	private {
		static void _storeStateImpl(NetObj o, void* s) {
			final obj = (cast(typeof(this))o);
			assert (obj !is null);
			obj.storeState(cast(T*)s);
		}

		static void _loadStateImpl(NetObj o, void* s) {
			final obj = (cast(typeof(this))o);
			assert (obj !is null);
			obj.loadState(cast(T*)s);
		}
	}

	static this() {
		auto nsi = &_netStateInfo[_numNetStateInfo++];
		nsi.serialize = &T.serialize;
		nsi.unserialize = &T.unserialize;
		static if (!is(typeof(T.NotInterpolable))) {
			nsi.applyDiff = cast(void function(void*, void*, float))&T.applyDiff;
		}
		nsi.store = &_storeStateImpl;
		nsi.load = &_loadStateImpl;
		nsi.calcDifference = cast(float function(void*, void*))&T.calcDifference;
		nsi.size = T.sizeof;
		nsi.typeInfo = typeid(T);
	}
}


/+struct SampleState {
	void serialize(BitStreamWriter*) {
	}
	
	void unserialize(BitStreamReader*) {
	}

	void applyDiff(SampleState* a, SampleState* b, float t) {
	}

	static float calcDifference(SampleState* a, SampleState* b) {
		return 1.0f;		// TODO
	}
}


struct SampleState2 {
	void serialize(BitStreamWriter*) {
	}
	
	void unserialize(BitStreamReader*) {
	}

	enum { NotInterpolable }

	static float calcDifference(SampleState2* a, SampleState2* b) {
		return 1.0f;		// TODO
	}
}


class SampleNetObj : NetObj {
	void storeState(SampleState*) {
		// TODO
	}
	
	void loadState(SampleState*) {
		// TODO
	}

	void storeState(SampleState2*) {
		// TODO
	}
	
	void loadState(SampleState2*) {
		// TODO
	}

	mixin DeclareNetState!(SampleState);
	mixin DeclareNetState!(SampleState2);
	mixin MNetObj;
}+/



//void delegate(NetObjBase)[]	netObjScheduleForDeletionHandlers;


/+interface NetObjSingle(State) : NetObjBase {
	void getState(State* ps);
	void setState(State ps, tick tck);
}


template NetObjMixImpl(States ...) {
	private import tango.stdc.stdio : printf;
	private import xf.utils.BitStream;
	private import xf.game.Misc : tick;
	
	private alias typeof(super) SuperType;
	//pragma (msg, typeof(this).stringof ~ `:` ~ SuperType.stringof);
	private const bool superNetObj = (is(typeof(SuperType._netObjPredicted)));


	static if (!superNetObj) {
		objId netObjId() {
			return this.netObjId_;
		}


		void overrideNetObjId(objId id) {
			this.netObjId_ = id;
		}
	}


	uint numStateTypes() {
		static if (superNetObj) {
			return super.numStateTypes + States.length;
		}
		else {
			return States.length;
		}
	}
	
	
	private {
		static if (superNetObj) {
			T superDo(T)(ref uint stateI, T delegate() sup, T delegate() notsup) {
				uint supStates = super.numStateTypes;
				if (stateI < supStates) return sup();
				else {
					stateI -= supStates;
					return notsup();
				}
			}
		} else {
			T superDo(T)(ref uint stateI, void delegate() sup, T delegate() notsup) {
				return notsup();
			}
		}
	}
	

	float	getStateImportance(playerId pid, uint stateI) {
		return superDo(stateI, {
			static if (superNetObj) {
				return super.getStateImportance(pid, stateI);
			}
		}, {
			float mult = 10.f;
			if (auto lws = pid in _lastWrittenStates) {
				foreach (i, dummy; States) {
					if (i == stateI) {
						if ((*lws).present[i]) {
							auto prevState = (*lws).states[i];
							typeof(prevState) curState = _currentlySetStates[i];
							//this.getState(&curState);
							mult = xf.game.StateUtils.compareStates(prevState, curState);
							//printf("* State importance mult = %f"\n, mult);
						}
					}
				}
			}
			return importances[stateI] * mult;
		});
	}
	

	void getCurrentStates() {
		static if (superNetObj) {
			super.getCurrentStates();
		}
		
		foreach (i, State; States) {
			State st;
			this.getState(&st);
			//this.setState(st, tick.init);
			_currentlySetStates[i] = st;
		}
	}

	
	void dumpStates(void delegate(char[]) dg) {
		static if (superNetObj) {
			super.dumpStates(dg);
		}
		
		foreach (i, State; States) {
			State st = _currentlySetStates[i];
			//this.getState(&st);
			st.dump(dg);
		}
	}


	void dumpState(uint stateI, void delegate(char[]) dg) {
		static if (superNetObj) {
			super.dumpState(stateI, dg);
		}
		
		foreach (i, dummy; States) {
			if (i == stateI) {
				States[i] state = _currentlySetStates[i];
				//this.getState(&state);
				state.dump(dg);
			}
		}
	}


	bool	getStateCriticalness(uint stateI) {
		return superDo(stateI, {
			static if (superNetObj) {
				return super.getStateCriticalness(stateI);
			}
		}, {
			return criticalness[stateI];
		});
	}


	void	writeStateToStream(playerId pid, uint stateI, BitStreamWriter bs, bool store) {
		if (_netObj_clientSideChecks) assert (0 == pid);
		
		return superDo(stateI, {
			static if (superNetObj) {
				return super.writeStateToStream(pid, stateI, bs, store);
			}
		}, {
			foreach (i, dummy; States) {
				if (i == stateI) {
					States[i] state = _currentlySetStates[i];
					//this.getState(&state);

					/+printf("Writing state:"\n);
					state.dump((char[] txt) {
						printf("%.*s", txt);
					});
					printf("State dump end"\n);+/
					
					xf.game.StateUtils.writeState(state, bs);
					if (!(pid in _lastWrittenStates)) {
						_lastWrittenStates[pid] = StateSTuple.init;
					}
					_lastWrittenStates[pid].states[i] = state;
					_lastWrittenStates[pid].present[i] = true;
				}
			}
		});
	}
	
	
	float	readStateFromStream(playerId pid, uint stateI, tick tck, tick dropEarlierThan, BitStreamReader bs, StateOverrideMethod som)	{	// returns an error level
		if (_netObj_clientSideChecks) assert (0 == pid);
	
		return superDo(stateI, {
			static if (superNetObj) {
				return super.readStateFromStream(pid, stateI, tck, dropEarlierThan, bs, som);
			}
		}, {
			foreach (i, dummy; States) {
				if (i == stateI) {
					synchronized (queueMutex) {
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
											
											if (this.predicted) {
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
			}

			assert (false);	// should never get here
		});
	}


	float	compareCurrentStateWithStored(playerId pid, tick tck) {
		if (_netObj_clientSideChecks) assert (0 == pid);
		
		float res = 0.f;
		
		static if (superNetObj) {
			res += super.compareCurrentStateWithStored(pid, tck);
		}
		
		foreach (i, State; States) {
			States[i]* localState = getLatestTimedState!(i)(pid, tck);
			if (localState !is null){
				State st = _currentlySetStates[i];
				//this.getState(&st);
				float diff = xf.game.StateUtils.compareStates(*localState, st);
				res += diff;
				/+localState.dump((char[] localTxt) {
					st.dump((char[] stTxt) {
						printf("comparing states\n\tstored=[%.*s]\n\tset=[%.*s]"\n, localTxt, stTxt);
					});
				});
				printf("state %.*s diff: %f"\n, typeid(State).toString, diff);+/
			} else {
				printf("state not found: %.*s"\n, typeid(State).toString);
				res += 99999f;
			}
		}
		
		return res;
	}
	
	
	bool	setToStoredState(playerId pid, uint stateI, tick tck){
		if (_netObj_clientSideChecks) assert (0 == pid);
		
		return superDo(stateI, {
			static if (superNetObj) {
				return super.setToStoredState(pid, stateI, tck);
			}
		}, {
			foreach (i, dummy; States) {
				if (i == stateI) {
					synchronized (queueMutex) {
						States[i]*	localState = getTimedState!(i)(pid, tck);
						if (localState !is null) {
							this.setState(*localState, tck);
							_currentlySetStates[i] = *localState;
							return true;
						}
					}
					return false;
				}
			}
			
			return true;
		});
	}
	
	
	void	storeCurrentStates(playerId pid, tick tck) {
		if (_netObj_clientSideChecks) assert (0 == pid);
		
		static if (superNetObj) {
			super.storeCurrentStates(pid, tck);
		}
		
		foreach (i, State; States) {
			State st = _currentlySetStates[i];
			//this.getState(&st);
			
			synchronized (queueMutex) {
				auto q = &stateQueues(pid).queues[i];
				q.addTail(StateQueueItem!(State)(st, tck));
				int qlen = q.length;
				const int maxQLen = 200;
				if (qlen > maxQLen) {
					//printf("2state queue len: %d :S removing some"\n, qlen);
					for (int j = maxQLen; j < qlen; ++j) {
						q.removeHead;
					}
				}
			}
		}
	}
	
	
	void	dropNewerStates(playerId pid, tick ti) {
		if (_netObj_clientSideChecks) assert (0 == pid);
		
		static if (superNetObj) {
			super.dropNewerStates(pid, ti);
		}

		foreach (i, dummy_; stateQueues(pid).queues) {
			while (!stateQueues(pid).queues[i].isEmpty && stateQueues(pid).queues[i][stateQueues(pid).queues[i].length-1].tck > ti) {
				stateQueues(pid).queues[i].removeTail();
			}
		}
	}
	
	
	static if (!superNetObj) {
		bool	predicted() {
			return _netObjPredicted;
		}
		
		
		void	overridePredicted(bool p) {
			_netObjPredicted = p;
		}
		

		void	netObjUnref() {
			bool d = false;
			
			synchronized (this) {
				if (0 >= --netObjRefCnt_ && netObjScheduledForDeletion_) {
					d = true;
				}
			}
			
			if (d) this.dispose();
		}


		bool	netObjRef() {
			synchronized (this) {
				if (netObjScheduledForDeletion_) {
					return false;
				} else {
					++netObjRefCnt_;
					return true;
				}
			}
		}
		
		
		bool	netObjScheduledForDeletion() {
			return netObjScheduledForDeletion_;
		}


		void	netObjScheduleForDeletion() {
			synchronized (this) {
				if (!netObjScheduledForDeletion_) {
					netObjScheduledForDeletion_ = true;
					foreach (h; netObjScheduleForDeletionHandlers) {
						h(this);
					}
				}
			}
		}
	}
	
	
	/+playerId netObjAuthOwner() {
		return _netObjAuthOwner;
	}
	

	void netObjAuthOwner(playerId id) {
		_netObjAuthOwner = id;
	}+/

	
	// ----
	
	
	private {
		import mintl.deque : Deque;		// TODO: replace it with a list-based queue that's safe for multithreaded code.
		import xf.utils.Bind : Tuple;
		import mintl.mem : Mallocator = Malloc;
		static import xf.game.StateUtils;
		

		template QueueTuple(int i = 0) {
			static if (States.length > i+1) {
				alias Tuple!(Deque!(StateQueueItem!(States[i]), false, Mallocator), QueueTuple!(i+1)).type QueueTuple;
			} else {
				alias Tuple!(Deque!(StateQueueItem!(States[i]), false, Mallocator)).type QueueTuple;
			}
		}
		
		struct StateQueueItem(State) {
			State	state;
			tick		tck;

			static StateQueueItem opCall(State st, tick tck){
				StateQueueItem qi;
				qi.state = st;
				qi.tck = tck;
				return qi;
			}
		}
		

		// no need to synchronize, only called in critical sections.
		/+void	dropEarlierStates(playerId pid, tick ti) {
			foreach (i, dummy_; stateQueues(pid).queues) {
				while (!stateQueues(pid).queues[i].isEmpty && stateQueues(pid).queues[i][0].tck < ti) {
					stateQueues(pid).queues[i].removeHead();
				}
			}
		}+/

		
		States[stateI]* getTimedState(int stateI)(playerId pid, tick tck) {
			synchronized (queueMutex) {
				//printf(`browsing through %d states`\n, stateQueues(pid).queues[stateI].length);
				foreach (i, ref item; stateQueues(pid).queues[stateI]) {
					if (item.tck == tck) {
						return &item.state;
					}
				}
			}
			
			return null;
		}


		States[stateI]* getLatestTimedState(int stateI)(playerId pid, tick tck) {
			synchronized (queueMutex) {
				int best = -1;
				
				//printf(`browsing through %d states`\n, stateQueues(pid).queues[stateI].length);
				foreach (i, ref item; stateQueues(pid).queues[stateI]) {
					if (item.tck <= tck) {
						best = i;
					}
				}
				
				if (best != -1) {
					foreach (i, ref item; stateQueues(pid).queues[stateI]) {
						if (i == best) {
							return &item.state;
						}
					}
				}
			}
			
			return null;
		}


		// BUG
		Object queueMutex() {
			volatile {
				if (queueMutexObj__ !is null) {
					return queueMutexObj__;
				}
			}
			
			synchronized (this) {
				if (queueMutexObj__ is null) {
					queueMutexObj__ = new Object;
				}
			}
			
			return queueMutexObj__;
		}


		objId								netObjId_;
		
		//playerId							_netObjAuthOwner = playerId.max;
	
		static float[States.length]	importances;
		static bool[States.length]	criticalness;
		

		struct QueueSTuple {
			QueueTuple!() queues;
		}
		
		struct StateSTuple {
			States						states;
			bool[States.length]		present;
		}

		QueueSTuple*					stateQueues(playerId pid) {
			if (0 == pid) {
				return &_defaultStateQueues;
			} else {
				if (auto sq = pid in _playerStateQueues) {
					return *sq;
				} else {
					_playerStateQueues[pid] = new QueueSTuple;
					return _playerStateQueues[pid];
				}				
			}
		}
		
		QueueSTuple						_defaultStateQueues;
		QueueSTuple*[playerId]		_playerStateQueues;
		
		StateSTuple[playerId]		_lastWrittenStates;
		States								_currentlySetStates;
		
		Object								queueMutexObj__;
		
		int									netObjRefCnt_;
		bool									netObjScheduledForDeletion_;
		
		bool									netObjCanBeGivenBack;
	}
	
	public {
		static if (!superNetObj) {
			bool	_netObjPredicted;
		}
	}
	
	static this() {
		foreach (i, state; States) {
			static if (is(typeof(state.importance))) {
				importances[i] = state.importance;
			} else {
				importances[i] = 1.f;
			}
			
			static if (is(typeof(state.critical))) {
				criticalness[i] = state.critical;
			} else {
				criticalness[i] = true;
			}
		}
	}
}



//  internal stuff -----------------------------------------------------------------------------

interface NetObj(States ...) : NetObjSingle!(States[0]), NetObj!(States[1..$]) {
	alias States NetObjStateTuple__;
}
interface NetObj() {}


template MNetObj() {
	static if (is(typeof(this) Bases == super)) {
		mixin NetObjMix_!(Bases);
	}
}


template NetObjMix_(Bases ...) {
	private alias Bases[0] BasesFirst;
	
	static if (is(BasesFirst.NetObjStateTuple__)) {
		mixin NetObjMixImpl!(BasesFirst.NetObjStateTuple__);
	} else {
		mixin NetObjMix_!(Bases[1..$]);
	}
}
template NetObjMix_() {}
+/
