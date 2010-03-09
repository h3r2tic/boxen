module xf.net.ENetClient;

private {
	import xf.core.Registry;
	
	import tango.stdc.stringz;

	import xf.net.LowLevelClient;
	import xf.utils.BitStream;
	import xf.net.Misc;
	
	import tango.util.container.CircularList;
	import tango.util.container.Container;

	import enet;

	extern(C) int printf(char* fmt, ...);
}



class ENetClient : LowLevelClient {
	mixin(Implements("LowLevelClient"));
	
	enum {
		DataChannel = 0,
		TimeTuningChannel = 1
	}
	
	
	this() {
		eventQueue = new EventQueue;
		
		client = enet_host_create(null, // Client
								  1,	// Single outgoing connection
								  0,	// Unlimited incoming bw
								  0		// Unlimited outgoing bw
			);

		if(client == null) {
			throw new Exception("Failed to initialize client");
		}
	}

	~this() {
		enet_host_destroy(client);
	}
	

	override ENetClient connect(int clientPort, char[] address, ushort port) {
		if(connected) {
			printf("Attempted to connect while already connected.\n");
		}
		
		ENetAddress addr;

		printf("Connecting to %s:%d\n", toStringz(address), port);

		enet_address_set_host(&addr, toStringz(address));
		addr.port = port;

		server = enet_host_connect(client, &addr, 2);		// two channels: 0-data 1-time tuning

		if(server == null) {
			throw new Exception("Failed to initiate connection to " ~ address);
		}

		connected = true;

		return this;
	}
	
	override ENetClient disconnect() {
		if(!connected) {
			printf("Attempted to disconnect while already disconnected.\n");
		}
		
		enet_peer_disconnect_later(server, 0);
		connected = false;

		return this;
	}
	

	// Handle zero or one packet(s).  Will not necessarily call dg,
	// irrespective of return value.  Returns true if a packet was
	// handled, false if no packets available.
	override bool recvPacket(StreamFate delegate(BitStreamReader*) dg) {
		bool handlePacket(BitStreamReader bsr, ENetPacket* pkt) {
			auto fate = dg(&bsr);
			if(fate == StreamFate.Dispose) {
				enet_packet_destroy(pkt);
				return true;
			} else {
				assert(retainedBsr is retainedBsr.init, "Cannot retain multiple packets.");
				
				retainedBsr = bsr;
				retainedPkt = pkt;
				return false;
			}
		}
		
		receiveMore();

		if (retainedBsr !is retainedBsr.init) {
			auto recvBsr = retainedBsr;
			auto recvPkt = retainedPkt;
			retainedBsr = retainedBsr.init;
			retainedPkt = null;
			if(!handlePacket(recvBsr, recvPkt)) {
				return false;
			}
		}
		
		if (!eventQueue.isEmpty) {
			auto ev = eventQueue.removeHead;
			assert (ENetEventType.ENET_EVENT_TYPE_RECEIVE == ev.type);
			assert (DataChannel == ev.channelID);
			//auto bsr = new GenericBitStreamReader(ev.packet.data[0..ev.packet.dataLength]);

			// BitStreamReader expects data allocated to the granularity of
			// machine words. This is guaranteed by initializing ENet with
			// a custom allocator. See enet.d's static this() for how this works
			
			auto bsr = BitStreamReader(cast(uword*)ev.packet.data, ev.packet.dataLength);
			return handlePacket(bsr, ev.packet);
		}
		
		return false;
	}
	
	
	override void send(void delegate(BitStreamWriter*) writer) {
		sendImpl(writer, ENetPacketFlag.ENET_PACKET_FLAG_RELIABLE);
	}
	
	override void unreliableSend(void delegate(BitStreamWriter*) writer) {
		sendImpl(writer, ENetPacketFlag.ENET_PACKET_FLAG_UNSEQUENCED);
	}
	
	override float timeTuning(){
		return _timeTuning;
	}

	override uint averageRTTMillis() {
		// STUB
		return 0;
	}

	override void registerConnectionHandler(void delegate() dg) {
		connHandlers ~= dg;
	}

protected:
	ENetPeer* server;
	ENetHost* client;
	alias CircularList!(ENetEvent, Container.reap, Container.Chunk) EventQueue;
	EventQueue eventQueue;

	void delegate()[] connHandlers;

	void sendImpl(void delegate(BitStreamWriter*) writer, uint flags) {
		void[] data = new void[1024 * 8];
		auto bsw = BitStreamWriter(data);
		// TODO: mem

		//auto bsw = new GenericBitStreamWriter;
		writer(&bsw);
		auto pkt = enet_packet_create(data.ptr, bsw.asBytes.length, flags);
		//printf("Sending a packet.\n");
		enet_peer_send(server, DataChannel, pkt);
	}
	
	
	void receiveMore() {
		ENetEvent ev;
		while (enet_host_service(client, &ev, 0) > 0) {
			// We got an event!
			switch(ev.type) {
			case ENetEventType.ENET_EVENT_TYPE_CONNECT:
				printf("Connected.\n");
				foreach(handler; connHandlers) {
					handler();
				}
				break;

			case ENetEventType.ENET_EVENT_TYPE_DISCONNECT:
				printf("Disconnected.\n");
				break;

			case ENetEventType.ENET_EVENT_TYPE_RECEIVE:
				//printf("Recieved a packet.\n");
				if (TimeTuningChannel == ev.channelID) {
					assert (float.sizeof == ev.packet.dataLength);
					_timeTuning = *cast(float*)ev.packet.data;
					enet_packet_destroy(ev.packet);
				} else {
					eventQueue.append(ev);
				}
				break;

			default:
				printf("WARNING: Received unsupported event.\n");
				break;
			}
		}
	}
	

private:
	ENetPacket*		retainedPkt;
	BitStreamReader	retainedBsr;
	
	float _timeTuning = 1.f;

	bool connected = false;
}
