module xf.nucleus.SurfaceDef;

private {
	import xf.Common;
	import xf.nucleus.Defs;
	import xf.nucleus.Param;
	import xf.nucleus.KernelImpl;
}



class SurfaceDef {
	private alias void* delegate(uword) Allocator;
	union {
		ParamList	params;
		Allocator	_allocator;
	}


	this(cstring illum, Allocator alloc) {
		_allocator = alloc;
		this.illumKernelName = illum.dup;		// TODO
	}

	// TODO: make these props
	cstring		name;
	cstring		illumKernelName;

	KernelImpl	illumKernel;

	SurfaceId	id;
}
