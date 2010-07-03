module xf.nucleus.SamplerDef;

private {
	import xf.Common;
	import xf.nucleus.Defs;
	import xf.nucleus.Param;
}



class SamplerDef {
	private alias void* delegate(uword) Allocator;
	union {
		ParamList	params;
		Allocator	_allocator;
	}


	this(Allocator alloc) {
		_allocator = alloc;
	}
}
