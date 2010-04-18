module xf.utils.ResourcePool;

private {
	import xf.Common;

	import
		xf.utils.UidPool,
		xf.utils.Error;
	
	import
		xf.mem.Array,
		xf.mem.ArrayAllocator,
		xf.mem.FreeList;
}



struct ThreadUnsafeResourcePool(T, Handle) {
	static assert (is(typeof(Handle.id)			: size_t));
	static assert (is(typeof(Handle.reuseCnt)	== size_t));
	
	
	struct ResourceReturn {
		T*		resource;
		Handle	handle;
	}
	
	
	// darn, i want struct ctors :F
	void initialize() {
		_resources.initialize();
		_initializingThread = Thread.getThis();
	}
	
	
	ResourceReturn alloc(void delegate(T*) resGen) out (res) {
		assert (res.handle.id != 0);
	} body {
		assert (Thread.getThis() is _initializingThread);
		
		final uid = _uidPool.alloc();
		if (uid.id < _uidMap.length) {
			final res = &_uidMap.ptr[uid.id];
			res.reuseCnt = uid.reuseCnt;
			
			return ResourceReturn(
				res.res,
				Handle(uid.id+1, uid.reuseCnt)
			);
		} else {
			assert (uid.id == _uidMap.length);
			assert (0 == uid.reuseCnt);
			final res = _resources.alloc();
			resGen(res);
			_uidMap.pushBack(ResData(res, 0));
			return ResourceReturn(res, Handle(uid.id+1, 0));
		}
	}
	
	
	void free(ResData *res) {
		assert (res !is null);
		++res.reuseCnt;
	}
	
	
	ResData* find(Handle h, bool errorOnNotFound = true) {
		if (0 == h.id) {
			return null;
		} else {
			final curThread = Thread.getThis();
			if (curThread !is _initializingThread) {
				utilsError(
					"ThreadUnsafeResourcePool called from a different thread"
					" (ptr={:x}) than which it was initialized in (ptr={:x}).",
					cast(void*)curThread,
					cast(void*)_initializingThread
				);
			}
			
			final idx = cast(size_t)h.id-1;
			assert (idx < _uidMap.length);

			final res = &_uidMap.ptr[idx];
			if (res.reuseCnt != h.reuseCnt) {
				if (errorOnNotFound) {
					utilsError(
						"Resource reference counting error: trying to use a"
						" resource that has already been released. Expected"
						" reuseCnt: {}. Handle's reuseCnt: {}. UID(+1): {}.",
						res.reuseCnt,
						h.reuseCnt,
						h.id
					);
					assert (false);
				} else {
					return null;
				}
			} else {
				return res;
			}
		}
	}


	private {
		struct ResData {
			T*		res;
			size_t	reuseCnt;
		}
		
		Array!(
			ResData,
			ArrayExpandPolicy.FixedAmount!(1024)
		)					_uidMap;
		UidPool!(size_t)	_uidPool;
		FreeList!(T)		_resources;
		
		Thread				_initializingThread;
	}
}
