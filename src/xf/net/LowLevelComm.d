module xf.net.LowLevelComm;

private {
	import xf.game.Defs : tick, playerId;
	import xf.utils.BitStream;
}


abstract class LowLevelComm {
	abstract void recvPacketsForTick(
		tick,
		tick delegate(playerId, tick, BitStreamReader*, uint* retained)
	);
}
