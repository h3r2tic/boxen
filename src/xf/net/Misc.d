module xf.net.Misc;



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
