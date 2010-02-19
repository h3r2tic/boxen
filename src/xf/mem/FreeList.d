module xf.mem.FreeList;

private {
	import xf.mem.OSHeap;
}


// NOTE: the returned objects are to be assumed junk and need to be initialized

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
	
	
	bool isEmpty() {
		return _freeList is null;
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


struct FreeList(T) {
	void initialize() {
		_impl.itemSize = T.sizeof;
	}


	bool isEmpty() {
		return _impl.isEmpty();
	}
	
	
	T* alloc() {
		return cast(T*)_impl.alloc();
	}
	
	
	void free(T* ptr) {
		return _impl.free(ptr);
	}
	
	
	UntypedFreeList	_impl;
}


struct NondestructiveFreeList(T) {
	void initialize() {
		_impl.itemSize = (void*).sizeof + T.sizeof;
	}


	bool isEmpty() {
		return _impl.isEmpty();
	}
	
	
	T* alloc() {
		return cast(T*)(_impl.alloc() + (void*).sizeof);
	}
	
	
	void free(T* ptr) {
		assert (ptr !is null);
		return _impl.free(cast(void*)ptr - (void*).sizeof);
	}
	
	
	UntypedFreeList	_impl;
}
