module xf.gfx.Resource;


struct ResourceHandle {
	size_t	id			= 0;		// important!
	size_t	reuseCnt	= 0;
}



template MResource() {
	alias bool function(Handle, int) ResCountFunc;
	
	Handle			_resHandle;
	void*			_resMngr;
	void*			_refMngr;
	ResCountFunc	_resCountAdjust;

	// TODO: is it possible for a resource to have the same type and _resHandle
	// as another resource and another _resMngr? if so, a struct containing the two
	// and being a GUID could be useful. if not, the current form is OK
	alias	_resHandle GUID;
	
	// ----
	
	bool acquire() {
		assert (_resHandle != Handle.init);
		assert (_refMngr !is null);
		bool delegate(Handle, int) dg = void;
		dg.ptr = _refMngr;
		dg.funcptr = _resCountAdjust;
		return dg(_resHandle, 1);
	}

	void dispose() {
		assert (_refMngr !is null);
		bool delegate(Handle, int) dg = void;
		dg.ptr = _refMngr;
		dg.funcptr = _resCountAdjust;
		dg(_resHandle, -1);
		_resHandle = Handle.init;
	}
	
	Resource* asResource() {
		return cast(Resource*)this;
	}

	bool valid() {
		return _resHandle !is Handle.init;
	}
}


struct Resource {
	alias ResourceHandle Handle;
	mixin MResource;
}
