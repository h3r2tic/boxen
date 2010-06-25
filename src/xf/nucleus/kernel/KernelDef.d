module xf.nucleus.kernel.KernelDef;

private {
	import xf.Common;
	//import xf.nucleus.Defs;
	//import xf.nucleus.Param;
	import xf.nucleus.Function;
}



class KernelDef {
	AbstractFunction	func;
	cstring				superKernel;

	bool isConcrete() {
		return cast(Function)func !is null;
	}
}
