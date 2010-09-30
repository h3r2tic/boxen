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

		case SourceKernelType.Material: {
			codeSink("material__");
		} break;

		case SourceKernelType.Reflectance: {
			codeSink("reflectance__");
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


	assert (nid.isValid);
	final node = graph.getNode(nid);

	if (	NT.Bridge == node.type &&
			node.bridge.type == node.bridge.Type.Input &&
			nodeDomains !is null &&
			nodeDomains[nid.id] == ctx.domain &&
			({
				// return true if no incoming connections
				foreach (c; graph.flow.iterIncomingConnections(nid)) return false;
				return true;
			})()
	) {
		// Also allow bridge nodes as inputs
		assert (GPUDomain.Vertex == ctx.domain);
		ctx.sink("structure__");
		ctx.sink(pname);
	} else if (NT.Input == node.type) {
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
