module Main;

private {
	import tango.core.tools.TraceExceptions;
	
	import xf.Common;
	import xf.mem.ChunkQueue;
	
	import xf.nucleus.kdef.KDefFileParser;
	import xf.nucleus.kdef.KDefProcessor;

	import tango.text.convert.Format;
	import tango.io.Stdout;
	import tango.io.device.File;

	import tango.io.vfs.FileFolder;
}



void main() {
	{
		ScratchFIFO mem;
		mem.initialize();

		final allocator = (uword bytes) { return mem.pushBack(bytes); };

		final vfs = new FileFolder(".");

		final fparser = new KDefFileParser;
		fparser.setVFS(vfs);

		final processor = new KDefProcessor(fparser, allocator);

		processor.processFile("sample.kdef");
		processor.doSemantics();
		processor.dumpInfo();
	}

	Stdout.formatln("Test passed!");
}
