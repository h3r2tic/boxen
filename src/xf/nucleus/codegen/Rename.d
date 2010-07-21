module xf.nucleus.codegen.Rename;

private {
	import xf.Common;
	import xf.nucleus.codegen.Defs;
	import xf.nucleus.graph.KernelGraph;
	import xf.nucleus.Log : error = nucleusError;
}



void renameDataNodeParam(
		CodeSink codeSink,
		KernelGraph.ParamNode* pnode,
		cstring pname
) {
	switch (pnode.sourceKernelType) {
		case SourceKernelType.Undefined: {
			error("Data node without a source kernel type :(");
		} break;

		case SourceKernelType.Structure: {
			codeSink("structure__");
		} break;

		case SourceKernelType.Pigment: {
			codeSink("pigment__");
		} break;

		case SourceKernelType.Illumination: {
			codeSink("illumination__");
		} break;

		case SourceKernelType.Light: {
			codeSink("light")(pnode.sourceLightIndex)("__");
		} break;

		case SourceKernelType.Composite: {
			// no prefix
		} break;

		default: assert (false);
	}

	codeSink(pname);
}


void emitSourceParamName(
	CodegenContext* ctx,
	KernelGraph graph,
	GPUDomain[] nodeDomains,
	GraphNodeId nid,
	cstring pname
) {
	alias KernelGraph.NodeType NT;


	final node = graph.getNode(nid);
	
	if (NT.Input == node.type) {
		if (nodeDomains is null) {
			ctx.sink(pname);
		} else if (nodeDomains[nid.id] == ctx.domain) {
			// uh huh o_O ... why is this branch even here, what does it do? xD
			assert (GPUDomain.Vertex == ctx.domain);
			ctx.sink("structure__");
			ctx.sink(pname);
		} else {
			ctx.sink('n')(nid.id)("__");
			ctx.sink(pname);
		}
	} else if (
		NT.Data == node.type
	) {
		final pnode = node._param();
		renameDataNodeParam(ctx.sink, pnode, pname);
	} else {
		ctx.sink('n')(nid.id)("__");
		ctx.sink(pname);
	}
}
