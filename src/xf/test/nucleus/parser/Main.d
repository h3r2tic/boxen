module Main;

private {
	import tango.core.tools.TraceExceptions;
	
	import xf.Common;

	import xf.nucleus.kdef.Common;
	import xf.nucleus.kdef.KDefFileParser;
	import xf.nucleus.kdef.KDefProcessor;
	import xf.nucleus.KernelImpl;

	import xf.nucleus.graph.KernelGraph;
	import xf.nucleus.kdef.KDefGraphBuilder;

	import tango.text.convert.Format;
	import tango.io.Stdout;
	import tango.io.device.File;

	import tango.io.vfs.FileFolder;
}



void main() {
	{
		final vfs = new FileFolder(".");

		final fparser = new KDefFileParser;
		fparser.setVFS(vfs);

		final processor = new KDefProcessor(fparser);

		processor.processFile("sample.kdef");
		processor.doSemantics();
		processor.dumpInfo();

		foreach (impl; processor.kernels) {
			if (impl.impl.type != KernelImpl.Type.Graph) {
				continue;
			}

			auto g = impl.impl.graph;
			auto kg = createKernelGraph();
			
			buildKernelGraph(
				g,
				kg
			);

			disposeKernelGraph(kg);
		}
	}

	Stdout.formatln("Test passed!");
}
