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
	import xf.game.Defs;
	import xf.game.Event;
	import xf.game.TimeHub;
	import xf.utils.BitStream;
	import xf.mem.MainHeap;
	import xf.net.Log : log = netLog, error = netError;
}



extern (C) {
	playerId	g_localPlayerId;
	tick		g_lastTickRecvd;
}



class GameClient : IGameComm {
	// 1MB for the bitstream
	const bswPrealloc		= 1024 * 1024;

	// In bits per iteration   // TODO: make this per second
	const playerWriteBudget	= 128 * 1024 / 60;

	// Can't overflow this amount
	const playerWriteBudgetMax	= playerWriteBudget * 5;


	float delegate(tick, playerId, BitStreamReader*) receiveStateSnapshot;

	
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
			&g_lastTickRecvd
		);

		_dispatcher.receiveEvent = &_eventReader.readEvent;

		Wish.addSubmitHandler(&_eventWriter.consume);
		AdjustTick.addHandler(&this.adjustTick);
		//DestroyObject.addHandler(&this.onDestroyObjectOrder);
		registerConnectionHandler(&this.onConnectedToServer);
	}


	private void _receiveStateSnapshot(playerId pid, BitStreamReader* bsr) {
		assert (this.receiveStateSnapshot !is null);
		float err = receiveStateSnapshot(timeHub.currentTick, pid, bsr);
		// TODO: sum the error and do stuff when it's > allowed :P
	}


	void receiveData() {
		assert (receiveStateSnapshot !is null);
		_dispatcher.receiveStateSnapshot = &this._receiveStateSnapshot;
		_dispatcher.dispatch(timeHub.currentTick);

		//if (timeHub.currentTick > g_lastTickRecvd) {
			timeHub.trimHistory(timeHub.currentTick - g_lastTickRecvd);
		//}
	}


	void sendData() {
		if (_connected) {
			_writer.flush((u8[] bytes) {
				//log.trace("Sending {} bytes of data to server.", bytes.length);
				_comm.send(bytes);
			});
		}
	}


	void registerConnectionHandler(void delegate() h) {
		return _comm.registerConnectionHandler(h);
	}
	
	
	tick lastTickReceived() {
		return g_lastTickRecvd;
	}
	
	
	float serverTickOffset() {
		/+if (g_lastTickRecvd != g_lastTickRecvd.init) {
			//return cast(long)lastTickReceived - cast(long)timeHub.inputTick;
			return this.tickOffsetTuning;
		}
		else return 0;+/
		return _comm.timeTuning;
	}


	// TODO: make this automatic
	void setLocalPlayerId(playerId id) {
		g_localPlayerId = id;
	}


	BudgetWriter* getWriter() {
		return &_writer;
	}


	bool connectedAndReady() {
		// Some stuff is not ready when the tick has not been adjusted
		// E.g. storing data with associated timeHub.currentTick is erroneous
		// Thus the client must wait for connectedAndReady before e.g. attempting
		// to store NetObj states
		return _connected && _tickAdjusted;
	}


	protected {
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
		bool			_tickAdjusted;
		bool			_connected;
	}
}


private {
	import xf.omg.core.Misc;
	import tango.stdc.stdio;
	import xf.utils.HardwareTimer;
}


/**
	Precise tick synchronization. Makes the client run as closely as possible to the perfect ahead-of-server time
	
	client.serverTickOffset specifies server-defined tick tuning feedback.
	It specifies how many ticks earlier the last event should've arrived.
	If it's a small negative number, then it's ok. If it's positive, the server has received an event out of time.
*/
void synchronizeNetworkTicks(GameClient client) {
	static int totalSampleCount = 0;
	++totalSampleCount;
	
	static float[200] offsetTable = 0.f;
	static int offsetPtr = 0;
	
	static float[200]	offsetTbl2 = void;
	static int			offsetPtr2 = 0;
	
	float serverOffset = client.serverTickOffset;
	offsetTable[offsetPtr++ % offsetTable.length] = serverOffset;
	//float offset = offsetTable.fold(0.f, (float a, float b){ return a + b; }) / offsetTable.length;
	
	static float deviation = -1.f;
	static float amortizedDeviation = 0.f;
	
	offsetTbl2[offsetPtr2++] = serverOffset;
	if (offsetTbl2.length == offsetPtr2) {
		offsetPtr2 = 0;
	}// {
		float mean = 0.f;
		foreach (x; offsetTbl2) mean += x;
		mean /= offsetTbl2.length;
		
		deviation = 0.f;
		foreach (x; offsetTbl2) deviation += (mean - x) * (mean - x);
		deviation /= offsetTbl2.length;
		deviation = sqrt(deviation);
	//}

	amortizedDeviation = (deviation + amortizedDeviation) / 2.f;

	// not enough samples to determine reliably
	if (totalSampleCount < 50) {
		amortizedDeviation = 2.f;
	}
	
		static float[offsetTable.length] sortedOffsets;
		sortedOffsets[] = offsetTable;
		sortedOffsets.sort;
		
		float errorThresh = .4f;
		float offset = sortedOffsets[rndint((1.f - errorThresh) * (offsetTable.length - 1))];
		
	offset += amortizedDeviation * 2f;
	
	// vary the game speed to match with the server
	float timeMult = 1.f;
	if (offset > 0.0f) {
		timeMult = 1.f + 0.005f * offset;
	} else if (offset < -1.0f) {
		timeMult = 1.f + 0.005f * offset;
	}
	
	if (timeMult > 1.6f) {
		timeMult = 1.6f;
	}
	if (timeMult < 0.8f) {
		timeMult = 0.8f;
	}
	HardwareTimer.multiplier = timeMult;

	printf(\r`offset [srv: %1.1f, calc: %1.1f; dev: %1.2f] ; time mult: %3.3f`, serverOffset, offset, amortizedDeviation, cast(float)HardwareTimer.multiplier);
	fflush(stdout);
}
