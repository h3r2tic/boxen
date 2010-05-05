module xf.nucleus.kdef.model.IKDefRegistry;

private {
	import xf.core.Registry;
	
	import xf.nucleus.kdef.model.IKDefFileParser;
	import xf.nucleus.kernel.KernelDef;
	import xf.nucleus.quark.QuarkDef;
	import xf.nucleus.kdef.Common : GraphDef, KDefModule;
	//import xf.nucleus.util.AbstractRegistry;
	import xf.nucleus.TypeConversion;

	alias char[] string;
}




abstract class IKDefRegistry /+: AbstractRegistry +/{
	this (string fnmatch) {
		// TODO
		//super(fnmatch);
	}
	
	abstract void dumpInfo();
	abstract KernelDef getKernel(string name);
	abstract QuarkDef getQuark(string name);
	abstract IKDefFileParser kdefFileParser();
	abstract KDefModule getModuleForPath(string path);
	abstract int kernels(int delegate(ref KernelDef) dg);
	abstract int quarks(int delegate(ref QuarkDef) dg);
	abstract int graphs(int delegate(ref GraphDef) dg);
	abstract int converters(int delegate(ref SemanticConverter) dg);
	abstract void doSemantics();
	abstract void clear();
}
