module xf.nucleus.MaterialDef;

private {
	import xf.Common;
	import xf.nucleus.Defs;
	import xf.nucleus.Param;
	import xf.nucleus.KernelImpl;
	import xf.nucleus.DepTracker;
}



final class MaterialDef {
	private alias void* delegate(uword) Allocator;
	union {
		ParamList	params;
		Allocator	_allocator;
	}

	private DepTracker	_dependentOnThis;
	DepTracker* dependentOnThis() {
		return &_dependentOnThis;
	}


	bool opEquals(MaterialDef other) {
		return
			name == other.name
		&&	pigmentKernelName == other.pigmentKernelName
		&&	params == other.params;
	}


	void invalidateIfDifferent(MaterialDef other) {
		if (!opEquals(other)) {
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
