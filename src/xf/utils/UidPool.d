module xf.utils.UidPool;

private {
	import
		xf.mem.Array,
		xf.mem.ArrayAllocator;
}



struct UidPool(T) {
	struct UID {
		T		id;
		size_t	reuseCnt = 0;
	}
	
	
	UID alloc() {
		if (_recycledIds.length > 0) {
			return _recycledIds.popBack;
		} else {
			return UID(_nextId++, 0);
		}
	}
	
	
	void free(UID id) {
		_recycledIds.pushBack(UID(id.id, id.reuseCnt+1));
	}
	
	
	private {
		Array!(
			UID,
			ArrayExpandPolicy.FixedAmount!(1024)

		)		_recycledIds;
		T		_nextId = 0;
	}
}
