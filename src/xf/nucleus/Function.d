module xf.nucleus.Function;

private {
	import xf.Common;
	import xf.nucleus.Code;
	import xf.nucleus.Param;
}



class AbstractFunction {
	cstring name;
	mixin MParamSupport;
	
	this (cstring name, Param[] params) {
		this.name = name.dup;
		this.overrideParams(params);
	}
}


class Function : AbstractFunction {
	Code code;
	
	this (cstring name, Param[] params, Code code) {
		super (name, params);
		this.code = code;
	}
}
