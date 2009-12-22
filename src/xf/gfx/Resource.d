module xf.gfx.Resource;


typedef size_t ResourceHandle;


template MResource() {
	Handle	_resHandle;
	void*	_resMngr;
	
	bool function(Handle)	_acquire;
	bool function(Handle)	_dispose;
	
	// ----
	
	bool acquire() {
		assert (_resHandle != Handle.init);
		bool delegate(Handle) dg = void;
		dg.ptr = _resMngr;
		dg.funcptr = _acquire;
		return dg(_resHandle);
	}

	bool dispose() {
		bool delegate(Handle) dg = void;
		dg.ptr = _resMngr;
		dg.funcptr = _dispose;
		auto res = dg(_resHandle);
		_resHandle = Handle.init;
		return res;
	}
	
	Resource* asResource() {
		return cast(Resource*)this;
	}
}


struct Resource {
	alias ResourceHandle Handle;
	mixin MResource;
}


static assert (Resource.sizeof == size_t.sizeof * 4);
