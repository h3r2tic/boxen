module xf.net.LowLevelClient;

private {
	import xf.Common;
	import xf.utils.BitStream;
	import xf.game.Misc : tick;
}



abstract class LowLevelClient {
	LowLevelClient	connect(u16 clientPort, cstring address, u16 port);
	LowLevelClient	disconnect();
	bool			connected();

	bool recvPacketForTick(tick, tick delegate(BitStreamReader*));
	void send(void delegate(BitStreamWriter*));
	void unreliableSend(void delegate(BitStreamWriter*));
	
	float timeTuning();

	uword averageRTTMillis();

	void registerConnectionHandler(void delegate());
}
