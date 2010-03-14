module xf.net.GameServer;

private {
	import xf.Common;
	import xf.net.ControlEvents;
	import xf.net.LowLevelServer;
	import xf.net.EventWriter;
	import xf.net.EventReader;
	import xf.net.Dispatcher;
	import xf.net.BudgetWriter;
	import xf.game.Misc;
	import xf.game.Event;
	import xf.game.TimeHub;
	import xf.utils.BitStream;
	import xf.mem.MainHeap;
}



class GameServer {
	// 1MB for bitstreams per player
	const bswPrealloc		= 1024 * 1024;

	// In bits per iteration   // TODO: make this per second
	const playerWriteBudget	= 1024 * 32;

	// Can't overflow this amount
	const playerWriteBudgetMax	= playerWriteBudget * 5;


	
	this (LowLevelServer comm, int maxPlayers) {
		assert (comm !is null);
		_comm = comm;

		_playerData.alloc(maxPlayers);
		_maxPlayers = maxPlayers;
		
		_eventReader = new EventReader;
		_eventReader.endpoint = NetEndpoint.Server;
		_eventReader.playerWishMask = &getPlayerWishMask;
		_eventReader.rollbackTimeToTick = &rollbackTimeToTick;

		_eventWriter = new EventWriter;
		_eventWriter.endpoint = NetEndpoint.Server;
		_eventWriter.iterPlayerStreams = &iterPlayerStreams;
		_eventWriter.playerOrderMask = &playerOrderMask;

		_dispatcher = new Dispatcher(
			_comm,
			_playerData.lastTickRecvd,
			NetEndpoint.Server
		);

		_dispatcher.receiveEvent = &_eventReader.readEvent;
		_dispatcher.receiveStateSnapshot = &receiveStateSnapshot;

		Order.addSubmitHandler(&_eventWriter.consume);
		
		comm.registerConnectionHandler(&this.onPlayerConnected);
		comm.registerDisconnectionHandler(&this.onPlayerDisconnected);
		
		TuneClientTiming.addHandler(&onTuneClientTiming);
	}


	void receiveData(tick curTick) {
		_dispatcher.dispatch(curTick);
	}


	void setDefaultOrderMask(bool delegate(Order) m) {
		_defaultOrderMask = m;
	}
	

	void setDefaultWishMask(bool delegate(Wish) m) {
		_defaultWishMask = m;
	}
	

	void setOrderMask(playerId pid, bool delegate(Order) m) {
		if (m is null) m = (Order) { return true; };
		_playerData.orderMask[pid] = m;
	}
	

	void setWishMask(playerId pid, bool delegate(Wish) m) {
		if (m is null) m = (Wish) { return true; };
		_playerData.wishMask[pid] = m;
	}
	
	
	void setStateMask(playerId pid, bool m) {
		_playerData.stateMask[pid] = m;
	}


	void kickPlayer(playerId pid) {
		_comm.kickPlayer(pid);
	}


	void registerConnectionHandler(void delegate(playerId) h) {
		return _comm.registerConnectionHandler(h);
	}
	
	
	void registerDisconnectionHandler(void delegate(playerId) h) {
		return _comm.registerDisconnectionHandler(h);
	}


	protected {
		void onPlayerConnected(playerId id) {
			_playerData.reset(id);
			_playerData.connected[id] = true;
			
			if (_defaultWishMask !is null) {
				_playerData.wishMask[id] = _defaultWishMask;
			} else {
				_playerData.wishMask[id] = (Wish) { return true; };
			}

			if (_defaultOrderMask !is null) {
				_playerData.orderMask[id] = _defaultOrderMask;
			} else {
				_playerData.orderMask[id] = (Order) { return true; };
			}

			/+assert (id >= players.length || players[id] is null);
			allocPlayers(id+1);
			
			foreach (o, ref d; netObjData) {
				d.importances[id].realloc(o.numStateTypes, false);		// dont init to float.init (NaN)
				d.importances[id][] = 0.f;
			}+/

			// tell the client which tick it's at the server side
			// send our currentTick + 1, to make the event tell about the tick that will happen in just a moment, when orders are dispatched
			// 	this is sort of a HACK, but I couldnt come up with anything else that would do the trick
			// 	the +1 might be simply removed and client's catch-up could handle the difference, but would be slightly less efficient
			_eventWriter.consume(
				AdjustTick(
					cast(tick)(timeHub.currentTick+1)
				).filter((playerId pid) { return id == pid; }), 0
			);
		}
			

		void onPlayerDisconnected(playerId id) {
			_playerData.connected[id] = false;
			assert (false, "TODO");
			// BUG: need to do this in a thread-safe manner. a snapshot task might be running.
			/+assert (id < players.length);
			assert (players[id] !is null);
			players[id] = null;+/
		}


		void onTuneClientTiming(TuneClientTiming e) {
			//players[e.pid].tickOffsetTuning = e.tickOffset;
			_comm.setPlayerTimeTuning(e.pid, e.tickOffset);
		}


		void receiveStateSnapshot(playerId, BitStreamReader*) {
			assert (false, "TODO");
		}
	}


	private {
		bool getPlayerWishMask(playerId pid, Wish wish) {
			if (auto m = _playerData.wishMask[pid]) {
				return m(wish);
			} else {
				return _defaultWishMask(wish);
			}
		}

		void rollbackTimeToTick(tick tck) {
			assert (false, "TODO");
		}

		int iterPlayerStreams(int delegate(ref playerId, ref BitStreamWriter) dg) {
			for (int pid = 0; pid < _maxPlayers; ++pid) {
				if (_playerData.connected[pid]) {
					playerId meh = cast(playerId)pid;
					if (int r = dg(meh, _playerData.writers.bsw)) {
						return r;
					}
				}
			}
			return 0;
		}
				
		bool playerOrderMask(playerId pid, Order order) {
			if (auto m = _playerData.orderMask[pid]) {
				return m(order);
			} else {
				return _defaultOrderMask(order);
			}
		}



		LowLevelServer	_comm;
		EventWriter		_eventWriter;
		EventReader		_eventReader;
		Dispatcher		_dispatcher;

		struct PlayerData {
			tick*					lastTickRecvd;
			bool delegate(Order)*	orderMask;
			bool delegate(Wish)*	wishMask;
			bool*					stateMask;
			bool*					connected;
			BudgetWriter*			writers;

			void reset(playerId pid) {
				writers[pid].reset();
			}

			void alloc(int num) {
				uword totalSize = 0;
				foreach (f; this.tupleof) {
					totalSize += typeof(*f).sizeof * num;
				}
				void* mem = mainHeap.allocRaw(totalSize);
				foreach (i, f; this.tupleof) {
					this.tupleof[i] = cast(typeof(f))mem;
					{
						uword size = typeof(*f).sizeof * num;
						memset(f, 0, size);
						mem += size;
					}
				}
				assert (lastTickRecvd !is null);
				assert (0 == *lastTickRecvd);


				void* bswStorage = mainHeap.allocRaw(bswPrealloc * num);
				foreach (i, ref w; writers[0..num]) {
					w.reset();
					w.bsw = BitStreamWriter(
						bswStorage[bswPrealloc * num .. bswPrealloc * (num+1)]
					);
					w.budgetInc = playerWriteBudget;
					w.budgetMax = playerWriteBudgetMax;
				}
			}
		}

		bool delegate(Order)	_defaultOrderMask;
		bool delegate(Wish)		_defaultWishMask;

		PlayerData		_playerData;
		uword			_maxPlayers;
	}
}
