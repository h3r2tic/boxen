module xf.net.GameClient;

private {
	import xf.Common;
	import xf.net.ControlEvents;
	import xf.net.LowLevelClient;
	import xf.net.EventWriter;
	import xf.net.EventReader;
	import xf.net.Dispatcher;
	import xf.net.BudgetWriter;
	import xf.net.GameComm;
	import xf.game.Misc;
	import xf.game.Event;
	import xf.game.TimeHub;
	import xf.utils.BitStream;
	import xf.mem.MainHeap;
	import xf.net.Log : log = netLog, error = netError;
}



class GameClient : IGameComm {
	// 1MB for the bitstream
	const bswPrealloc		= 1024 * 1024;

	// In bits per iteration   // TODO: make this per second
	const playerWriteBudget	= 1024 * 32;

	// Can't overflow this amount
	const playerWriteBudgetMax	= playerWriteBudget * 5;


	
	this (LowLevelClient comm) {
		assert (comm !is null);
		_comm = comm;

		initBudgetWriter();

		//_playerData.alloc(maxPlayers);
		//_maxPlayers = maxPlayers;
		
		_eventReader = new EventReader;
		_eventReader.playerWishMask = &getPlayerWishMask;
		_eventReader.rollbackTimeToTick = &rollbackTimeToTick;

		_eventWriter = new EventWriter;
		_eventWriter.iterPlayerStreams = &iterPlayerStreams;
		_eventWriter.playerOrderMask = &playerOrderMask;

		_dispatcher = new Dispatcher(
			_comm,
			&_lastTickRecvd
		);

		_dispatcher.receiveEvent = &_eventReader.readEvent;
		_dispatcher.receiveStateSnapshot = &receiveStateSnapshot;

		Wish.addSubmitHandler(&_eventWriter.consume);
		AdjustTick.addHandler(&this.adjustTick);
		//DestroyObject.addHandler(&this.onDestroyObjectOrder);
		registerConnectionHandler(&this.onConnectedToServer);
	}


	void receiveData() {
		_dispatcher.dispatch(timeHub.currentTick);
	}


	void sendData() {
		if (_connected) {
			_writer.flush((u8[] bytes) {
				log.trace("Sending {} bytes of data to server.", bytes.length);
				_comm.send(bytes);
			});
		}
	}


	void registerConnectionHandler(void delegate() h) {
		return _comm.registerConnectionHandler(h);
	}
	
	
	tick lastTickReceived() {
		return _lastTickRecvd;
	}
	
	
	float serverTickOffset() {
		/+if (lastTickRecvd != lastTickRecvd.init) {
			//return cast(long)lastTickReceived - cast(long)timeHub.inputTick;
			return this.tickOffsetTuning;
		}
		else return 0;+/
		return _comm.timeTuning;
	}


	// TODO: make this automatic
	void setLocalPlayerId(playerId id) {
		_localPlayerId = id;
	}


	BudgetWriter* getWriter() {
		return &_writer;
	}


	bool connected() {
		return _connected;
	}


	protected {
		void receiveStateSnapshot(playerId, BitStreamReader*) {
			assert (false, "TODO");
		}


		void adjustTick(AdjustTick e) {
			log.info("Adjusting tick to {}", e.serverTick);
			
			assert (!_tickAdjusted);
			_tickAdjusted = true;
			
			timeHub.overrideCurrentTick(e.serverTick);
		}

		
		void onConnectedToServer() {
			_connected = true;
		}
	}


	private {
		bool getPlayerWishMask(playerId pid, Wish wish) {
			return true;
		}

		void rollbackTimeToTick(tick tck) {
			timeHub.rollback(timeHub.currentTick - tck);

			// TODO
			/+foreach (id, netObj; netObjects) {
				netObj.dropNewerStates(0, tck);
				
				int states = netObj.numStateTypes;
				for (int i = 0; i < states; ++i) {
					netObj.setToStoredState(0, i, tck);
				}
			}+/
		}

		int iterPlayerStreams(int delegate(ref playerId, ref BitStreamWriter) dg) {
			playerId meh = 0;
			return dg(meh, _writer.bsw);
		}
				
		bool playerOrderMask(playerId pid, Order order) {
			return true;
		}


		void initBudgetWriter() {
			void* bswStorage = mainHeap.allocRaw(bswPrealloc);
			auto w = &_writer;
			w.bsw = BitStreamWriter(
				bswStorage[0 .. bswPrealloc]
			);
			w.reset();
			w.budgetInc = playerWriteBudget;
			w.budgetMax = playerWriteBudgetMax;
		}


		LowLevelClient	_comm;
		EventWriter		_eventWriter;
		EventReader		_eventReader;
		Dispatcher		_dispatcher;
		BudgetWriter	_writer;
		tick			_lastTickRecvd;
		bool			_tickAdjusted;
		bool			_connected;
		playerId		_localPlayerId;
	}
}
