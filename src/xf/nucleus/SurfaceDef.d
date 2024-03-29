module xf.nucleus.SurfaceDef;

private {
	import xf.Common;
	import xf.nucleus.Defs;
	import xf.nucleus.Param;
	import xf.nucleus.KernelImpl;
	import xf.nucleus.DepTracker;
}



final class SurfaceDef {
	private alias void* delegate(uword) Allocator;
	union {
		ParamList	params;
		Allocator	_allocator;
	}

	private DepTracker	_dependentOnThis;
	DepTracker* dependentOnThis() {
		return &_dependentOnThis;
	}


	bool opEquals(SurfaceDef other) {
		return
			name == other.name
		&&	reflKernelName == other.reflKernelName
		&&	params == other.params;
	}


	void invalidate() {
		_dependentOnThis.valid = false;
	}

	bool isValid() {
		return _dependentOnThis.valid;
	}


	this(cstring refl, Allocator alloc) {
		_allocator = alloc;
		this.reflKernelName = refl;
		_dependentOnThis = DepTracker(alloc);
	}

	// TODO: make these props
	cstring		name;
	cstring		reflKernelName;

	KernelImpl	reflKernel;

	SurfaceId	id;
}
