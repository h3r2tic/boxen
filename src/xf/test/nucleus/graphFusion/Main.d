module Main;

private {
	import tango.core.tools.TraceExceptions;
	
	import xf.Common;
	import xf.mem.ChunkQueue;
	
	import xf.core.Registry;
	import xf.nucleus.kdef.model.IKDefRegistry;

	import xf.nucleus.graph.Graph;
	import xf.nucleus.graph.KernelGraph;
	import xf.nucleus.graph.KernelGraphOps;
	import xf.nucleus.kdef.KDefGraphBuilder;

	import xf.nucleus.Log : error = nucleusError;
	import xf.nucleus.quark.QuarkDef;
	import xf.nucleus.kernel.KernelDef;
	import xf.nucleus.TypeSystem;
	import xf.nucleus.graph.GraphMisc;
	import xf.nucleus.TypeConversion;

	import tango.text.convert.Format;
	import tango.io.Stdout;
	import tango.io.device.File;

	import tango.io.vfs.FileFolder;
}


void findBestKernelImpls(
	int			delegate(int delegate(ref QuarkDef) dg)
			quarks,
			
	KernelDef	delegate(cstring name)
			getKernel
) {
	foreach (q; quarks) {
		static assert (is(typeof(q) == QuarkDef));
		
		foreach (impl; q.implList) {
			if (auto kernel = getKernel(impl.name)) {
				if (impl.score > kernel.bestImplScore) {
					kernel.bestImplScore = impl.score;
					kernel.bestImpl = cast(Object)q;
				}
			}
		}
	}
}


void findBestKernelImpls(IKDefRegistry reg) {
	return findBestKernelImpls(
		&reg.quarks,
		&reg.getKernel
	);
}


import tango.core.Memory;

void main() {
	{
		GC.disable();
		
		ScratchFIFO mem;
		mem.initialize();

		final allocator = (uword bytes) { return mem.pushBack(bytes); };

		final vfs = new FileFolder(".");

		final registry = create!(IKDefRegistry)();
		registry.setVFS(vfs);
		registry.registerFolder(".", allocator);
		registry.doSemantics(allocator);
		registry.dumpInfo();

		findBestKernelImpls(registry);

		GraphDef[char[]] graphs;

		foreach (g; &registry.graphs) {
			graphs[g.label] = g;
		}

		GraphNodeId output, input;

		auto kg = createKernelGraph();
		buildKernelGraph(
			graphs["DefaultStructure"],
			kg
		);
		foreach (nid, n; kg.iterNodes) {
			if (KernelGraph.NodeType.Output == n.type) {
				output = nid;
				break;
			}
		}
		assert (output.valid);

		
		buildKernelGraph(
			graphs["DefaultSurface"],
			kg
		);
		foreach (nid, n; kg.iterNodes) {
			if (KernelGraph.NodeType.Input == n.type && nid.id > output.id) {
				input = nid;
				break;
			}
		}
		assert (output.valid);


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


		// If this line is uncommented, an extra conversion happens, as expected.
		// This shows that graph fusion can reduce the number of conversions.
		//
		// convertGraphDataFlow(kg, &registry.converters, &registry.getKernel);
		//

		verifyDataFlowNames(kg, &registry.getKernel);

		fuseGraph(
			kg,
			output,
			input,
			&registry.converters,
			&registry.getKernel
		);

		verifyDataFlowNames(kg, &registry.getKernel);

		File.set("graph.dot", toGraphviz(kg));

		disposeKernelGraph(kg);
	}

	Stdout.formatln("Test passed!");
}
