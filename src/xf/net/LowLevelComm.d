module xf.net.LowLevelComm;

private {
	import xf.game.Misc : tick, playerId;
	import xf.utils.BitStream;
}


abstract class LowLevelComm {
	abstract void recvPacketsForTick(
		tick,
		tick delegate(playerId, BitStreamReader*, uint* retained)
	);
}
