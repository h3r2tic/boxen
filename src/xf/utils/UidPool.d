module xf.utils.UidPool;

private {
	import xf.mem.Array;
}



struct UidPool(T) {
	T alloc() {
		if (recycledIds.length > 0) {
			return recycledIds.popBack;
		} else {
			return nextId++;
		}
	}
	
	
	void free(T id) {
		if (nextId == id + 1) {
			--nextId;
		} else {
			recycledIds.pushBack(id);
		}
	}
	
	
	private {
		Array!(
			T,
			ArrayExpandPolicy.FixedAmount!(1024)

		)	recycledIds;
		T	nextId = 0;
	}
}
