module xf.nucleus.kdef.KDefRegistry;

private {
	import xf.core.Registry;
	
	import xf.nucleus.kdef.model.IKDefRegistry;
	import xf.nucleus.kdef.Common;
	import xf.nucleus.kdef.KDefProcessor;
	import xf.nucleus.kernel.KernelDef;
	import xf.nucleus.quark.QuarkDef;
	import xf.nucleus.util.AbstractRegistry;
	import xf.nucleus.kdef.model.IKDefFileParser;
	
	import tango.text.convert.Format;
	import tango.io.Stdout;
	
	alias char[] string;
}




class KDefRegistry : IKDefRegistry {
	mixin(Implements("IKDefRegistry"));
	
	private KDefProcessor kdefProcessor;


	this() {
		kdefProcessor = new KDefProcessor(_fileParser = create!(IKDefFileParser)());
		super("*.kdef");
	}
	
	
	void dumpInfo() {
		kdefProcessor.dumpInfo;
	}
	
	
	KernelDef getKernel(string name) {
		return kdefProcessor.getKernel(name);
	}
	

	QuarkDef getQuark(string name) {
		return kdefProcessor.getQuark(name);
	}
	
	
	IKDefFileParser kdefFileParser() {
		return _fileParser;
	}
	
	
	KDefModule getModuleForPath(string path) {
		return kdefProcessor.getModuleForPath(path);
	}
	

	override void processFile(string path) {
		_fileParser.setVFS(_vfs);
		kdefProcessor.processFile(path);
	}
	
	
	int kernels(int delegate(ref KernelDef) dg) {
		return kdefProcessor.kernels(dg);
	}
	

	int quarks(int delegate(ref QuarkDef) dg) {
		return kdefProcessor.quarks(dg);
	}


	int graphs(int delegate(ref GraphDef) dg) {
		return kdefProcessor.graphs(dg);
	}
	
	
	int converters(int delegate(ref SemanticConverter) dg) {
		return kdefProcessor.converters(dg);
	}

	
	void doSemantics() {
		kdefProcessor.doSemantics;
	}
	

	void clear() {
		kdefProcessor.clear();
	}
	
	
	private {
		IKDefFileParser	_fileParser;
	}
}
