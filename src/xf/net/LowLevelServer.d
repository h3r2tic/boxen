module xf.net.LowLevelServer;

private {
	import xf.Common;
	import xf.net.LowLevelComm;
	import xf.net.Misc;
	import xf.core.Registry;
	import xf.utils.BitStream;
	import xf.game.Misc;
}



abstract class LowLevelServer : LowLevelComm {
	mixin(CtorParams = "int");		// max player count
	
	LowLevelServer start(cstring addr, u16 port);
	LowLevelServer stop();
	
	size_t maxPlayers();

	void send(u8[], playerId target);
	void broadcast(u8[], bool delegate(playerId) filter);
	
	void setPlayerTimeTuning(playerId pid, float val);

	void kickPlayer(playerId pid);
	
	void registerConnectionHandler(void delegate(playerId));
	void registerDisconnectionHandler(void delegate(playerId));
}
