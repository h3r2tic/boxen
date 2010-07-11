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

		default: assert (false);
	}

	codeSink(pname);
}


void emitSourceParamName(
	CodegenContext ctx,
	GraphNodeId nid,
	cstring pname
) {
	alias KernelGraph.NodeType NT;


	final node = ctx.graph.getNode(nid);
	
	if (NT.Input == node.type) {
		if (ctx.nodeDomains is null) {
			ctx.sink(pname);
		} else if (ctx.nodeDomains[nid.id] == ctx.domain) {
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
