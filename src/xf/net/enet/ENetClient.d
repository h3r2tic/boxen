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
	import xf.net.enet.ENetCommon;
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


	override bool connected() {
		return _connected;
	}


	override void recvPacketsForTick(
			tick curTick,
			tick delegate(playerId, tick, BitStreamReader*, uint* retained) dg
	) {
		.recvPacketsForTick(
			curTick,
			1,
			(playerId pid) {
				assert (0 == pid);
				return _connected ? &server : null;
			},
			&receiveMore,
			dg
		);
	}
	
	
	override void send(u8[] bytes) {
		sendImpl(&server, bytes, ENetPacketFlag.ENET_PACKET_FLAG_RELIABLE);
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
		void receiveMore(tick curTick, void delegate(playerId, NetEvent*) eventSink) {
		//void receiveMore(tick curTick, Peer* peer) {
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
							NetEvent nev;
							nev.enetEvent = ev;
							nev.receivedAtTick = curTick;
							eventSink(0, &nev);
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
