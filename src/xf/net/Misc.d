module xf.net.Misc;

private {
	import xf.utils.BitStream;
	import xf.game.Defs : tick;
}



template MRemovePendingNetObjects() {
	protected void removePendingNetObjects() {
		// BUG: should use some malloc'd container
		static NetObj[] delObjects;
		
		foreach (o; &iterNetObjects) {
			if (o.netObjScheduledForDeletion) {
				delObjects ~= o;
			}
		}
		
		foreach (o; delObjects) {
			removeNetObject(o);
		}
		
		delObjects.length = 0;
	}
}


tick readTick(BitStreamReader* bs) {
	uint tmp;
	bs.read(&tmp);
	return cast(tick)tmp;
}
