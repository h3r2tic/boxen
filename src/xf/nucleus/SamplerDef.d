module xf.nucleus.SamplerDef;

private {
	import xf.Common;
	import xf.nucleus.Defs;
	import xf.nucleus.Param;
}



final class SamplerDef {
	private alias void* delegate(uword) Allocator;
	union {
		ParamList	params;
		Allocator	_allocator;
	}


	bool opEquals(SamplerDef other) {
		return params == other.params;
	}


	this(Allocator alloc) {
		_allocator = alloc;
	}
}
