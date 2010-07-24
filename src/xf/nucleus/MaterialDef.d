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
		&&	materialKernelName == other.materialKernelName
		&&	params == other.params;
	}


	void invalidate() {
		_dependentOnThis.valid = false;
	}

	bool isValid() {
		return _dependentOnThis.valid;
	}


	this(cstring kernel, Allocator alloc) {
		_allocator = alloc;
		this.materialKernelName = kernel;
		_dependentOnThis = DepTracker(alloc);
	}

	// TODO: make these props
	cstring		name;
	cstring		materialKernelName;

	KernelImpl	materialKernel;

	MaterialId	id;
}
