module xf.utils.FreeList;

private {
	import xf.mem.OSHeap;
}


// TODO: more allocation strategies could be useful
struct UntypedFreeList {
	void* alloc() {
		assert (_itemSize != 0, "Intialize the freelist by calling itemSize first.");
		
		if (_freeList !is null) {
			final res = _freeList;
			_freeList = *cast(void**)res;
			return res;
		} else {
			return osHeap.allocRaw(_itemSize);
		}
	}
	
	
	void free(void* ptr) {
		assert (ptr !is null);
		*cast(void**)ptr = _freeList;
		_freeList = ptr;
	}
	
	
	void itemSize(size_t s) {
		assert (0 == _itemSize, "Can only initialize the freelist once.");
		assert (s != 0);
		
		if (s < size_t.sizeof) {
			s = size_t.sizeof;
		}
		
		_itemSize = s;
	}
	
	
	private {
		size_t	_itemSize = 0;
		void*	_freeList = null;
	}
}
