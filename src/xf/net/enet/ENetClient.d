module xf.net.enet.ENetClient;

private {
	import xf.Common;
	import xf.core.Registry;
	import xf.net.LowLevelClient;
	import xf.net.Misc;
	import xf.net.Log : log = netLog, error = netError;
	import xf.utils.BitStream;
	import xf.mem.MainHeap;
	
	import enet;
	import xf.net.enet.EnetCommon;
}



class ENetClient : LowLevelClient {
	mixin(Implements("LowLevelClient"));


	private {
		Peer				server;
		void delegate()[]	connHandlers;
		ENetHost*			client;

		float				_timeTuning = 1.f;
		bool				_connected = false;
	}
	
	
	this() {
		// alloc event backlog queues
		{
			const eventBacklog = 1024;
			const numPeers = 1;
			final eventQueueMemSize = eventBacklog * numPeers * ENetEvent.sizeof;
			final eventQueueMem = mainHeap.allocRaw(eventQueueMemSize);
			server.eventQueue = EventQueue(eventQueueMem[0..eventQueueMemSize]);
		}
		
		client = enet_host_create(
			null,	// Client
			1,		// Single outgoing connection
			0,		// Unlimited incoming bw
			0		// Unlimited outgoing bw
		);

		if (client is null) {
			error("Failed to initialize ENet client.");
		}
	}


	void dispose() {
		enet_host_destroy(client);
	}


	override ENetClient connect(u16 clientPort, cstring address, u16 port) {
		assert (!_connected);
		
		log.info("Connecting to {}:{}", address, port);

		ENetAddress addr;
		enet_address_set_host(&addr, toStringz(address));
		addr.port = port;

		// two channels: 0-data 1-time tuning
		server.con = enet_host_connect(client, &addr, 2);

		if (server.con is null) {
			throw new Exception("Failed to initiate connection to " ~ address);
		}

		_connected = true;
		return this;
	}

	
	override ENetClient disconnect() {
		if (!_connected) {
			log.warn("Attempted to disconnect while already disconnected.");
		} else {
			_connected = false;
			enet_peer_disconnect_later(server.con, 0);
		}

		return this;
	}
	

	override bool recvPacketForTick(tick curTick, tick delegate(BitStreamReader*) dg) {
		receiveMore(&server);

		if (server.retainedPacket !is null) {
			if (server.retainedUntilTick <= curTick) {
				auto recvBsr = server.retainedBsr;
				auto recvPkt = server.retainedPacket;
				server.retainedBsr = BitStreamReader.init;
				server.retainedPacket = null;
				
				if (!handlePacket(&server, recvBsr, recvPkt, curTick, dg)) {
					return false;
				}
			}
		}
		
		if (!server.eventQueue.isEmpty) {
			final ev = *server.eventQueue.popFront();
			assert (ENetEventType.ENET_EVENT_TYPE_RECEIVE == ev.type);
			assert (DataChannel == ev.channelID);

			// BitStreamReader expects data allocated to the granularity of
			// machine words. This is guaranteed by initializing ENet with
			// a custom allocator. See enet.d's static this() for how this works
			
			auto bsr = BitStreamReader(cast(uword*)ev.packet.data, ev.packet.dataLength);
			return handlePacket(&server, bsr, ev.packet, curTick, dg);
		}
		
		return false;
	}
	
	
	override void send(void delegate(BitStreamWriter*) writer) {
		sendImpl(&server, writer, ENetPacketFlag.ENET_PACKET_FLAG_RELIABLE);
	}
	
	override void unreliableSend(void delegate(BitStreamWriter*) writer) {
		sendImpl(&server, writer, ENetPacketFlag.ENET_PACKET_FLAG_UNSEQUENCED);
	}
	
	override float timeTuning(){
		return _timeTuning;
	}

	override uword averageRTTMillis() {
		// TODO
		return 0;
	}

	override void registerConnectionHandler(void delegate() dg) {
		connHandlers ~= dg;
	}


	private {
		void receiveMore(Peer* peer) {
			ENetEvent ev;
			
			while (enet_host_service(client, &ev, 0) > 0) {
				// We got an event!
				switch(ev.type) {
					case ENetEventType.ENET_EVENT_TYPE_CONNECT: {
						log.info("Connected.");
						foreach(handler; connHandlers) {
							handler();
						}
					} break;

					case ENetEventType.ENET_EVENT_TYPE_DISCONNECT: {
						log.info("Disconnected.");
					} break;

					case ENetEventType.ENET_EVENT_TYPE_RECEIVE: {
						//printf("Recieved a packet.\n");
						if (TimeTuningChannel == ev.channelID) {
							assert (float.sizeof == ev.packet.dataLength);
							_timeTuning = *cast(float*)ev.packet.data;
							enet_packet_destroy(ev.packet);
						} else {
							if (peer.eventQueue.isFull) {
								// TODO: make this disconnect gracefully
								error("Packet backlog overflow.");
							} else {
								*peer.eventQueue.pushBack() = ev;
							}
						}
					} break;

					default: {
						log.error("Received unsupported event.");
					} break;
				}
			}
		}
	}
}
