module xf.nucleus.quark.QuarkDef;

/+private {
	import xf.Common;
	import xf.nucleus.Defs;
	import xf.nucleus.Param;
	import xf.nucleus.Function;
	import xf.nucleus.Code;

	import xf.nucleus.kernel.KernelDef;
}



class QuarkDef : KernelDef {
	cstring				name;
	KernelImplDef[]		implList;
	Code[]				code;
	Function[]			functions;


	Function getFunction(cstring name) {
		foreach (f; functions) {
			if (f.name == name) {
				return f;
			}
		}
		return null;
	}
}
+/
