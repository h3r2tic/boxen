module xf.nucleus.kdef.KDefRegistry;

private {
	import xf.core.Registry;
	
	import xf.nucleus.kdef.model.IKDefRegistry;
	import xf.nucleus.kdef.Common;
	import xf.nucleus.kdef.KDefProcessor;
	import xf.nucleus.kernel.KernelDef;
	import xf.nucleus.kdef.model.IKDefFileParser;
	import xf.nucleus.TypeConversion;
	import xf.nucleus.KernelImpl;
	
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
	
	
	KernelImpl getKernel(string name) {
		return kdefProcessor.getKernel(name);
	}
	
	IKDefFileParser kdefFileParser() {
		return _fileParser;
	}
	
	
	KDefModule getModuleForPath(string path) {
		return kdefProcessor.getModuleForPath(path);
	}
	

	override void processFile(string path, Allocator allocator) {
		_fileParser.setVFS(_vfs);
		kdefProcessor.processFile(path, allocator);
	}


	int converters(int delegate(ref SemanticConverter) dg) {
		return kdefProcessor.converters(dg);
	}

	
	void doSemantics(Allocator allocator) {
		kdefProcessor.doSemantics(allocator);
	}
	

	void clear() {
		kdefProcessor.clear();
	}
	
	
	private {
		IKDefFileParser	_fileParser;
	}
}
