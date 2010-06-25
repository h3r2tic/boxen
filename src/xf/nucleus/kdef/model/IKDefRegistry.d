module xf.nucleus.kdef.model.IKDefRegistry;

private {
	import xf.core.Registry;
	
	import xf.nucleus.kdef.model.IKDefFileParser;
	import xf.nucleus.kernel.KernelDef;
	import xf.nucleus.kdef.Common : GraphDef, KDefModule;
	import xf.nucleus.util.AbstractRegistry;
	import xf.nucleus.TypeConversion;
	import xf.nucleus.KernelImpl;

	alias char[] string;
}




abstract class IKDefRegistry : AbstractRegistry {
	this (string fnmatch) {
		super(fnmatch);
	}
	
	abstract void dumpInfo();
	abstract KernelImpl getKernel(string name);
	abstract IKDefFileParser kdefFileParser();
	abstract KDefModule getModuleForPath(string path);
	abstract int converters(int delegate(ref SemanticConverter) dg);
	abstract void doSemantics(Allocator);
	abstract void clear();
}
