module xf.nucleus.codegen.Misc;

private {
	import xf.Common;

	import
		xf.nucleus.codegen.Defs,
		xf.nucleus.codegen.Rename,
		xf.nucleus.graph.KernelGraph;
}



void dumpUniforms(CodegenContext* ctx, KernelGraph graph, CodeSink sink) {
	alias KernelGraph.NodeType NT;

	foreach (nid, node; graph.iterNodes) {
		if (NT.Data == node.type) {
			foreach (param; node.data.params) {
				assert (param.hasTypeConstraint);

				//sink("uniform ");
				sink(param.type);
				sink(" ");
				
				emitSourceParamName(
					ctx,
					graph,
					null,
					nid,
					param.name
				);

				sink(";").newline;
			}
		}
	}
}
