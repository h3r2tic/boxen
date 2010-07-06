module Main;

private {
	import tango.core.tools.TraceExceptions;
	
	import xf.Common;
	import xf.mem.ChunkQueue;
	
	import xf.core.Registry;
	import xf.nucleus.kdef.model.IKDefRegistry;

	import xf.nucleus.graph.KernelGraph;
	import xf.nucleus.graph.KernelGraphOps;
	import xf.nucleus.kdef.KDefGraphBuilder;

	import xf.nucleus.Log : error = nucleusError;
	import xf.nucleus.kernel.KernelDef;
	import xf.nucleus.TypeSystem;
	import xf.nucleus.graph.GraphMisc;
	import xf.nucleus.TypeConversion;

	import tango.text.convert.Format;
	import tango.io.Stdout;
	import tango.io.device.File;

	import tango.io.vfs.FileFolder;
}


import tango.core.Memory;

void main() {
	{
		GC.disable();
		
		final vfs = new FileFolder(".");

		final registry = create!(IKDefRegistry)();
		registry.setVFS(vfs);
		registry.registerFolder(".");
		registry.doSemantics();
		registry.dumpInfo();

		// TODO
		foreach (g; &registry.graphs) {
			auto kg = createKernelGraph();
			
			buildKernelGraph(
				g,
				kg
			);

			convertKernelNodesToFuncNodes(
				kg,
				(cstring kname, cstring fname) {
					final kernel = registry.getKernel(kname);
					
					if (kernel is null) {
						error(
							"convertKernelNodesToFuncNodes requested a nonexistent"
							" kernel '{}'", kname
						);
					}

					if (kernel.bestImpl is null) {
						error(
							"The '{}' kernel requested by convertKernelNodesToFuncNodes"
							" has no implemenation.", kname
						);
					}

					final quark = cast(QuarkDef)kernel.bestImpl;
					
					return quark.getFunction(fname);
				}
			);

			verifyDataFlowNames(kg, &registry.getKernel);
			convertGraphDataFlow(kg, &registry.converters, &registry.getKernel);
			verifyDataFlowNames(kg, &registry.getKernel);

			File.set("graph.dot", toGraphviz(kg));

			disposeKernelGraph(kg);
		}
		
	}

	Stdout.formatln("Test passed!");
}
