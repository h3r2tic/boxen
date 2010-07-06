module xf.nucleus.MaterialDef;

private {
	import xf.Common;
	import xf.nucleus.Defs;
	import xf.nucleus.Param;
	import xf.nucleus.KernelImpl;
	import xf.nucleus.DepTracker;
}



class MaterialDef {
	private alias void* delegate(uword) Allocator;
	union {
		ParamList	params;
		Allocator	_allocator;
	}

	private DepTracker	_dependentOnThis;
	DepTracker* dependentOnThis() {
		return &_dependentOnThis;
	}


	void invalidateIfDifferent(MaterialDef other) {
		if (	params != other.params
			||	name != other.name
			||	pigmentKernelName != other.pigmentKernelName
		) {
			dependentOnThis.valid = false;
		}
	}


	this(cstring pigment, Allocator alloc) {
		_allocator = alloc;
		this.pigmentKernelName = pigment.dup;		// TODO
		_dependentOnThis = DepTracker(alloc);
	}

	// TODO: make these props
	cstring		name;
	cstring		pigmentKernelName;

	KernelImpl	pigmentKernel;

	MaterialId	id;
}
