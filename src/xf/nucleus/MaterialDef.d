module xf.nucleus.MaterialDef;

private {
	import xf.Common;
	import xf.nucleus.Defs;
	import xf.nucleus.Param;
	import xf.nucleus.KernelImpl;
}



class MaterialDef {
	private alias void* delegate(uword) Allocator;
	union {
		ParamList	params;
		Allocator	_allocator;
	}


	this(cstring pigment, Allocator alloc) {
		_allocator = alloc;
		this.pigmentKernelName = pigment.dup;		// TODO
	}

	// TODO: make these props
	cstring		name;
	cstring		pigmentKernelName;

	KernelImpl	pigmentKernel;

	MaterialId	id;
}
