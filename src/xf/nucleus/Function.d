module xf.nucleus.Function;

private {
	import xf.Common;
	import xf.nucleus.Code;
	import xf.nucleus.Param;
	import xf.nucleus.TypeSystem;
}



class AbstractFunction {
	cstring name;
	
	union {
		private void* delegate(uword) _allocator;
		ParamList		params;
	}
	
	this (cstring name, void* delegate(uword) allocator) {
		_allocator = allocator;
		if (name) {
			this.name = ((cast(char*)allocator(name.length))[0..name.length] = name);
		}
	}
}


class Function : AbstractFunction {
	Code code;
	
	this (cstring name, Code code, void* delegate(uword) allocator) {
		super (name, allocator);
		this.code = code;
	}
}
