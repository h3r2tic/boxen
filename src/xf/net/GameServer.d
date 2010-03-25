module xf.net.GameServer;

private {
	import xf.Common;
	import xf.net.ControlEvents;
	import xf.net.LowLevelServer;
	import xf.net.EventWriter;
	import xf.net.EventReader;
	import xf.net.Dispatcher;
	import xf.net.BudgetWriter;
	import xf.net.GameComm;
	import xf.game.Defs;
	import xf.game.Misc;
	import xf.game.Event;
	import xf.game.TimeHub;
	import xf.utils.BitStream;
	import xf.mem.MainHeap;
}



class GameServer : IGameComm {
	// 1MB for bitstreams per player
	const bswPrealloc		= 1024 * 1024;

	// In bits per iteration   // TODO: make this per second
	const playerWriteBudget	= 128;

	// Can't overflow this amount
	const playerWriteBudgetMax	= playerWriteBudget * 5;


	float delegate(tick, playerId, BitStreamReader*) receiveStateSnapshot;


	
	this (LowLevelServer comm) {
		assert (comm !is null);
		_comm = comm;

		_playerData.alloc();

		_eventReader = new EventReader;
		_eventReader.playerWishMask = &getPlayerWishMask;
		_eventReader.rollbackTimeToTick = &rollbackTimeToTick;

		_eventWriter = new EventWriter;
		_eventWriter.iterPlayerStreams = &iterPlayerStreams;
		_eventWriter.playerOrderMask = &playerOrderMask;

		_dispatcher = new Dispatcher(
			_comm,
			_playerData.lastTickRecvd.ptr
		);

		_dispatcher.receiveEvent = &_eventReader.readEvent;
		_dispatcher.receiveStateSnapshot = &_receiveStateSnapshot;

		Order.addSubmitHandler(&_eventWriter.consume);
		
		comm.registerConnectionHandler(&this.onPlayerConnected);
		comm.registerDisconnectionHandler(&this.onPlayerDisconnected);
		
		TuneClientTiming.addHandler(&onTuneClientTiming);
	}


	void receiveData() {
		_dispatcher.dispatch(timeHub.currentTick);
	}


	void sendData() {
		for (int pid = 0; pid < maxPlayers; ++pid) {
			if (_playerData.connected[pid]) {
				_playerData.writer[pid].flush((u8[] bytes) {
					//log.trace("Sending {} bytes of data to player {}.", bytes.length, pid);
					_comm.send(bytes, cast(playerId)pid);
				});
			}
		}
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


	BudgetWriter* getWriterForPlayer(playerId pid) {
		assert (_playerData.connected[pid]);
		return &_playerData.writer[pid];
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


		void _receiveStateSnapshot(playerId pid, BitStreamReader* bsr) {
			assert (this.receiveStateSnapshot !is null);
			receiveStateSnapshot(timeHub.currentTick, pid, bsr);
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
			for (int pid = 0; pid < maxPlayers; ++pid) {
				if (_playerData.connected[pid]) {
					playerId meh = cast(playerId)pid;
					if (int r = dg(meh, _playerData.writer[pid].bsw)) {
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
			BudgetWriter[maxPlayers]			writer;
			bool delegate(Order)[maxPlayers]	orderMask;
			bool delegate(Wish)[maxPlayers]		wishMask;
			tick[maxPlayers]					lastTickRecvd;
			bool[maxPlayers]					stateMask;
			bool[maxPlayers]					connected;

			void reset(playerId pid) {
				writer[pid].reset();
			}

			void alloc() {
				void* bswStorage = mainHeap.allocRaw(bswPrealloc * maxPlayers);
				foreach (i, ref w; writer) {
					w.bsw = BitStreamWriter(
						bswStorage[bswPrealloc * i .. bswPrealloc * (i+1)]
					);
					w.reset();
					w.budgetInc = playerWriteBudget;
					w.budgetMax = playerWriteBudgetMax;
				}
			}
		}

		bool delegate(Order)	_defaultOrderMask;
		bool delegate(Wish)		_defaultWishMask;

		PlayerData		_playerData;
	}
}
