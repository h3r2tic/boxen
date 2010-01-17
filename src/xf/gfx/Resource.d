module xf.gfx.Resource;


typedef size_t ResourceHandle;


template MResource() {
	// TODO: is it possible for a resource to have the same type and _resHandle
	// as another resource and another _resMngr? if so, a struct containing the two
	// and being a GUID could be useful. if not, the current form is OK
	union {
		Handle	_resHandle;
		size_t	GUID;
		
		static assert (size_t.sizeof == Handle.sizeof);
	}
	void*	_resMngr;
	
	bool function(Handle)	_acquire;
	void function(Handle)	_dispose;
	
	// ----
	
	bool acquire() {
		assert (_resHandle != Handle.init);
		bool delegate(Handle) dg = void;
		dg.ptr = _resMngr;
		dg.funcptr = _acquire;
		return dg(_resHandle);
	}

	void dispose() {
		void delegate(Handle) dg = void;
		dg.ptr = _resMngr;
		dg.funcptr = _dispose;
		dg(_resHandle);
		_resHandle = Handle.init;
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
