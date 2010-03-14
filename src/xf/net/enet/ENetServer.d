module xf.net.enet.ENetServer;

private {
	import xf.Common;
	import xf.core.Registry;
	import xf.game.Misc;
	import xf.net.LowLevelServer;
	import xf.net.Misc;
	import xf.net.Log : log = netLog, error = netError;
	import xf.utils.BitStream;
	import xf.utils.BitSet;

	import xf.mem.MainHeap;
	import xf.mem.ThreadChunkAllocator;

	// tmp
	import cstdlib = tango.stdc.stdlib;
	
	import enet;
	import xf.net.enet.ENetCommon;
}



class ENetServer : LowLevelServer {
	mixin(Implements("LowLevelServer"));
	
	enum {
		DataChannel = 0,
		TimeTuningChannel = 1
	}


	this (size_t maxPlayers) {
		assert (playersConnected.dynamic || maxPlayers <= playersConnected.length);

		this._maxPlayers = maxPlayers;
		this.peers.length = maxPlayers;		// TODO: mem

		// alloc event backlog queues
		{
			const eventBacklog = 1024;
			final singlePlayerMemSize = eventBacklog * ENetEvent.sizeof;
			final eventQueueMemSize = maxPlayers * singlePlayerMemSize;
			final eventQueueMem = mainHeap.allocRaw(eventQueueMemSize);
			
			foreach (pi, ref p; peers) {
				p.eventQueue = EventQueue(
					eventQueueMem[
						singlePlayerMemSize*pi
						..
						singlePlayerMemSize*(pi+1)
					]
				);
			}
		}
	}


	override size_t maxPlayers() {
		return _maxPlayers;
	}


	void dispose() {
		if (_running) {
			stop();
		}
	}

	
	override ENetServer start(cstring addr, ushort port) {
		assert (!_running);

		ENetAddress bindTo;

		enet_address_set_host(&bindTo, toStringz(addr));
		bindTo.port = port;
		
		server = enet_host_create(
			&bindTo,
			_maxPlayers,
			0, // Incoming bandwidth limit
			0  // Outgoing bandwidth limit
		);
		
		if (!server) {
			error("ENet failed to start.");
		} else {
			log.info("Server started.");
			_running = true;
		}
		
		return this;
	}

	
	override ENetServer stop() {
		if (!_running) {
			log.warn("Attempted to stop a server which was not running.\n");
		} else {
			_running = false;
			enet_host_destroy(server);
		}
		return this;
	}
	

	override void recvPacketsForTick(
			tick curTick,
			tick delegate(playerId, BitStreamReader*, uint* retained) dg
	) {
		.recvPacketsForTick(
			curTick,
			cast(playerId)peers.length,
			(playerId pid) {
				return playersConnected[pid] ? &peers[pid] : null;
			},
			&receiveMore,
			dg
		);
	}


	void receiveMore(tick curTick, void delegate(playerId, NetEvent*) eventSink) {
		ENetEvent ev;
		
		while (enet_host_service(server, &ev, 0) > 0) {
			//printf("Got event.\n");
			// We got an event!
			switch(ev.type) {
				case ENetEventType.ENET_EVENT_TYPE_CONNECT: {
					ev.peer.data = cstdlib.malloc(playerId.sizeof);		// TODO: mem
					final pid = getFreeID();
					
					*(cast(playerId*)(ev.peer.data)) = pid;
					playersConnected[pid] = true;

					peers[pid].reset();
					peers[pid].con = ev.peer;

					log.info("{} connected.", pid);
					
					foreach (handler; connHandlers) {
						handler(pid);
					}
				} break;

				case ENetEventType.ENET_EVENT_TYPE_DISCONNECT: {
					final pid = *(cast(playerId*)(ev.peer.data));
					final peer = &peers[pid];

					log.info("{} disconnected.", pid);

					foreach(handler; disconnHandlers) {
						handler(pid);
					}

					if (auto p = peer.retainedPacket) {
						enet_packet_destroy(p);
					}

					if (!peer.eventQueue.isEmpty) {
						// TODO: clean-up the event queue
						assert (false, "TODO");
					}
					
					cstdlib.free(ev.peer.data);		// TODO: mem
					ev.peer.data = null;
					playersConnected[pid] = false;
				} break;

				case ENetEventType.ENET_EVENT_TYPE_RECEIVE: {
					final pid = *(cast(playerId*)(ev.peer.data));
					final peer = &peers[pid];
					NetEvent nev;
					nev.enetEvent = ev;
					nev.receivedAtTick = curTick;
					eventSink(pid, &nev);
				} break;

				default: {
					log.error("Received unsupported event.");
				} break;
			}
		}
	}

	
	override void send(u8[] bytes, playerId target) {
		sendImpl(&peers[target], bytes, ENetPacketFlag.ENET_PACKET_FLAG_RELIABLE);
	}
	override void broadcast(u8[] bytes, bool delegate(playerId) filter) {
		broadcastImpl(bytes, filter, ENetPacketFlag.ENET_PACKET_FLAG_RELIABLE);
	}

	
	override void setPlayerTimeTuning(playerId pid, float val) {
		auto pkt = enet_packet_create(&val, float.sizeof, 0 /* unreliable sequenced */);
		enet_peer_send(peers[pid].con, TimeTuningChannel, pkt);
	}

	
	override void kickPlayer(playerId pid) {
		enet_peer_disconnect(peers[pid].con, 0);
	}

	
	override void registerConnectionHandler(void delegate(playerId) dg) {
		connHandlers ~= dg;
	}
	
	override void registerDisconnectionHandler(void delegate(playerId) dg) {
		disconnHandlers ~= dg;
	}


protected:
	void delegate(playerId)[] connHandlers;
	void delegate(playerId)[] disconnHandlers;

	ENetHost*	server;
	size_t		_maxPlayers;
	bool		_running = false;

	BitSet!(32)	playersConnected;
	Peer[]		peers;


	playerId getFreeID() {
		for (int id = 0; id < _maxPlayers; ++id) {
			if (!playersConnected[id]) {
				return cast(playerId)id;
			}
		}
		assert (false, "Failed to find a free ID.");
	}
	

	/+void broadcastImpl(void delegate(BitStreamWriter*) writer, bool delegate(playerId) filter, uint flags) {
		// TODO: mem (TLS cache)
		final dataChunk = threadChunkAllocator.alloc(1024 * 8);
		scope (exit) threadChunkAllocator.free(dataChunk);
		
		void[] data = dataChunk.ptr[0..dataChunk.size];
		memset(data.ptr, 0, data.length);
		assert (data.length % size_t.sizeof == 0);
		auto bsw = BitStreamWriter(data);

		writer(&bsw);

		broadcastImpl(&bsw, filter, flags);
	}+/

	void broadcastImpl(u8[] bytes, bool delegate(playerId) filter, uint flags) {
		// TODO: Confirm if this flag is what we want
		auto pkt = enet_packet_create(bytes.ptr, bytes.length, flags);
		foreach (id, peer; peers) {
			if (filter(cast(playerId)id)) {
				//printf("Sending a packet.\n");
				enet_peer_send(peer.con, DataChannel, pkt);
			}
		}
	}
}
