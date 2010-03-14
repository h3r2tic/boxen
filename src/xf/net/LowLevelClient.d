module xf.net.LowLevelClient;

private {
	import xf.Common;
	import xf.net.LowLevelComm;
	import xf.utils.BitStream;
	import xf.game.Misc : tick;
}



abstract class LowLevelClient : LowLevelComm {
	LowLevelClient	connect(u16 clientPort, cstring address, u16 port);
	LowLevelClient	disconnect();
	bool			connected();

	void send(u8[] bytes);
	
	float timeTuning();

	uword averageRTTMillis();

	void registerConnectionHandler(void delegate());
}
