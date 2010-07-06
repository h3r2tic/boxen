module xf.nucleus.SurfaceDef;

private {
	import xf.Common;
	import xf.nucleus.Defs;
	import xf.nucleus.Param;
	import xf.nucleus.KernelImpl;
	import xf.nucleus.DepTracker;
}



class SurfaceDef {
	private alias void* delegate(uword) Allocator;
	union {
		ParamList	params;
		Allocator	_allocator;
	}

	private DepTracker	_dependentOnThis;
	DepTracker* dependentOnThis() {
		return &_dependentOnThis;
	}


	void invalidateIfDifferent(SurfaceDef other) {
		if (	params != other.params
			||	name != other.name
			||	illumKernelName != other.illumKernelName
		) {
			dependentOnThis.valid = false;
		}
	}


	this(cstring illum, Allocator alloc) {
		_allocator = alloc;
		this.illumKernelName = illum.dup;		// TODO
		_dependentOnThis = DepTracker(alloc);
	}

	// TODO: make these props
	cstring		name;
	cstring		illumKernelName;

	KernelImpl	illumKernel;

	SurfaceId	id;
}
