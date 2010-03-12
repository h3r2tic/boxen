module xf.net.enet.ENetCommon;

private {
	import xf.Common;
	import xf.utils.BitStream;
	import xf.game.Misc : tick;
	import xf.mem.FixedQueue;
	import xf.mem.ThreadChunkAllocator;
	import enet;
}



alias FixedQueue!(ENetEvent) EventQueue;


struct Peer {
	EventQueue		eventQueue;
	ENetPeer*		con;
	BitStreamReader	retainedBsr;
	ENetPacket*		retainedPacket;
	tick			retainedUntilTick;
}

enum {
	DataChannel			= 0,
	TimeTuningChannel	= 1
}



void sendImpl(Peer* peer, void delegate(BitStreamWriter*) writer, uint flags) {
	// TODO: mem (TLS cache)
	final dataChunk = threadChunkAllocator.alloc(1024 * 8);
	scope (exit) threadChunkAllocator.free(dataChunk);
	
	void[] data = dataChunk.ptr[0..dataChunk.size];
	memset(data.ptr, 0, data.length);
	assert (data.length % size_t.sizeof == 0);
	auto bsw = BitStreamWriter(data);

	writer(&bsw);
	auto pkt = enet_packet_create(data.ptr, bsw.asBytes.length, flags);
	//printf("Sending a packet.\n");
	enet_peer_send(peer.con, DataChannel, pkt);
}


bool handlePacket(
		Peer* peer,
		BitStreamReader bsr,
		ENetPacket* pkt,
		tick curTick,
		tick delegate(BitStreamReader*) dg
) {
	final targetTick = dg(&bsr);
	
	if (targetTick <= curTick) {
		enet_packet_destroy(pkt);
		return true;
	} else {
		assert (
			peer.retainedBsr is BitStreamReader.init,
			"Cannot retain multiple packets."
		);
		
		peer.retainedBsr = bsr;
		peer.retainedPacket = pkt;
		peer.retainedUntilTick = targetTick;
		return false;
	}
}
