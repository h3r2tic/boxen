module xf.net.enet.ENetCommon;

private {
	import xf.Common;
	import xf.utils.BitStream;
	import xf.game.Defs : tick, playerId;
	import xf.mem.FixedQueue;
	import xf.mem.ThreadChunkAllocator;
	import xf.net.Log : log = netLog, error = netError;
	import tango.text.convert.Format;
	import enet;
}


struct NetEvent {
	ENetEvent	enetEvent;
	tick		receivedAtTick;
	uword		receivedMillis;		// TODO
}

alias FixedQueue!(NetEvent) EventQueue;


struct Peer {
	EventQueue		eventQueue;
	ENetPeer*		con;
	BitStreamReader	retainedBsr;
	ENetPacket*		retainedPacket;
	tick			retainedUntilTick;
	uint			retainedCntr;

	void reset() {
		eventQueue.clear();
		con = null;
		retainedBsr = BitStreamReader.init;
		retainedPacket = null;
		retainedUntilTick = 0;
		retainedCntr = 0;
	}
}

enum {
	DataChannel			= 0,
	TimeTuningChannel	= 1
}



void sendImpl(Peer* peer, u8[] bytes, uint flags) {
	auto pkt = enet_packet_create(bytes.ptr, bytes.length, flags);
	//printf("Sending a packet.\n");
	enet_peer_send(peer.con, DataChannel, pkt);
}


bool handlePacket(
		Peer* peer,
		BitStreamReader bsr,
		ENetPacket* pkt,
		tick curTick,
		uint retainedCntr,
		tick delegate(BitStreamReader*, uint*) dg
) {
	final targetTick = dg(&bsr, &retainedCntr);
	
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
		peer.retainedCntr = retainedCntr;
		return false;
	}
}


void recvPacketsForTick(
		tick curTick,
		playerId numPeers,
		Peer* delegate(playerId) getPeer,
		void delegate(tick, void delegate(playerId, NetEvent*)) recvPackets,
		tick delegate(playerId, BitStreamReader*, uint*) sink
) {
	void handleEvent(playerId pid, NetEvent* ev) {
		assert (ENetEventType.ENET_EVENT_TYPE_RECEIVE == ev.enetEvent.type);
		assert (DataChannel == ev.enetEvent.channelID);

		// BitStreamReader expects data allocated to the granularity of
		// machine words. This is guaranteed by initializing ENet with
		// a custom allocator. See enet.d's static this() for how this works

		final packet = ev.enetEvent.packet;
		final peer = getPeer(pid);
		assert (peer !is null);
		
		final bsr = BitStreamReader(cast(uword*)packet.data, packet.dataLength);
		handlePacket(peer, bsr, packet, curTick, 0,
			(BitStreamReader* bsr, uint* retCntr) {
				return sink(pid, bsr, retCntr);
			}
		);
	}
	
	for (playerId pid = 0; pid < numPeers; ++pid) {
		final peer = getPeer(pid);
		if (peer is null) {
			continue;
		}

		if (peer.retainedPacket !is null) {
			if (peer.retainedUntilTick <= curTick) {
				auto recvBsr = peer.retainedBsr;
				auto recvPkt = peer.retainedPacket;
				auto retCntr = peer.retainedCntr;
				peer.retainedBsr = BitStreamReader.init;
				peer.retainedPacket = null;
				peer.retainedCntr = 0;

				handlePacket(peer, recvBsr, recvPkt, curTick, retCntr,
					(BitStreamReader* bsr, uint* retCntr) {
						return sink(pid, bsr, retCntr);
					}
				);
			}
		}

		// TODO: handle the queue
	}

	recvPackets(curTick, (playerId pid, NetEvent* ev) {
		final peer = getPeer(pid);
		assert (peer !is null);
		
		if (peer.retainedPacket is null) {
			handleEvent(pid, ev);
		} else {
			if (peer.eventQueue.isFull) {
				// TODO: make this disconnect gracefully
				error("Packet backlog overflow.");
			} else {
				*peer.eventQueue.pushBack() = *ev;
			}
		}
	});
}
