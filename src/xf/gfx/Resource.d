module xf.gfx.Resource;


struct ResourceHandle {
	size_t	id			= 0;		// important!
	size_t	reuseCnt	= 0;
}


template MResource() {
	Handle	_resHandle;
	void*	_resMngr;

	// TODO: is it possible for a resource to have the same type and _resHandle
	// as another resource and another _resMngr? if so, a struct containing the two
	// and being a GUID could be useful. if not, the current form is OK
	alias	_resHandle GUID;
	
	bool function(Handle, int) _resCountAdjust;
	
	// ----
	
	bool acquire() {
		assert (_resHandle != Handle.init);
		bool delegate(Handle, int) dg = void;
		dg.ptr = _resMngr;
		dg.funcptr = _resCountAdjust;
		return dg(_resHandle, 1);
	}

	void dispose() {
		bool delegate(Handle, int) dg = void;
		dg.ptr = _resMngr;
		dg.funcptr = _resCountAdjust;
		dg(_resHandle, -1);
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
