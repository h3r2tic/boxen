module xf.nucleus.kdef.model.IKDefRegistry;

private {
	import xf.core.Registry;

	import xf.nucleus.Defs;
	import xf.nucleus.kdef.model.IKDefFileParser;
	import xf.nucleus.kdef.model.KDefInvalidation;
	import xf.nucleus.kernel.KernelDef;
	import xf.nucleus.kdef.Common : GraphDef, KDefModule;
	import xf.nucleus.util.AbstractRegistry;
	import xf.nucleus.TypeConversion;
	import xf.nucleus.KernelImpl;
	import xf.nucleus.SurfaceDef;
	import xf.nucleus.MaterialDef;

	alias char[] string;
}




abstract class IKDefRegistry : AbstractRegistry {
	this (string fnmatch) {
		super(fnmatch);
	}
	
	abstract void dumpInfo();
	abstract KernelImpl getKernel(string name);
	abstract KernelImpl getKernel(KernelImplId id);
	abstract bool getKernel(string name, KernelImpl* res);
	abstract bool isSubKernelOf(KernelImpl impl, string subName);
	abstract IKDefFileParser kdefFileParser();
	abstract KDefModule getModuleForPath(string path);
	abstract int converters(int delegate(ref SemanticConverter) dg);
	abstract int surfaces(int delegate(ref string, ref SurfaceDef) dg);
	abstract int materials(int delegate(ref string, ref MaterialDef) dg);
	abstract int kernelImpls(int delegate(ref KernelImpl) dg);
	//abstract void doSemantics();
	abstract void registerObserver(IKDefInvalidationObserver o);
	abstract bool invalidated();
	abstract void reload();
}
