module xf.nucleus.graph.KernelGraphOps;

private {
	import xf.Common;
	import xf.nucleus.Function;
	import xf.nucleus.graph.KernelGraph;
	import xf.nucleus.Log : error = nucleusError;
}



void convertKernelNodesToFuncNodes(
	KernelGraph graph,
	Function delegate(cstring kname, cstring fname) getFuncImpl
) {
	foreach (nid, node; graph.iterNodes(KernelGraph.NodeType.Kernel)) {
		final ndata = node.kernel();
		final func = getFuncImpl(ndata.kernelName, ndata.funcName);
		
		if (func is null) {
			error(
				"Could not find a kernel func '{}'::'{}'",
				ndata.kernelName, ndata.funcName
			);
		}

		graph.resetNode(nid, KernelGraph.NodeType.Func);
		node.func.func = func;		// lolz
	}
}


void verifyDataFlowNames(KernelGraph graph) {
	final flow = graph.flow();
	
	foreach (fromId; graph.iterNodes) {
		final fromNode = graph.getNode(fromId);
		
		foreach (toId; flow.iterOutgoingConnections(fromId)) {
			final toNode = graph.getNode(toId);
			
			foreach (fl; flow.iterDataFlow(fromId, toId)) {
				if (fromNode.getOutputParam(fl.from) is null) {
					error(
						"verifyDataFlowNames: The source node for flow {}->{}"
						" doesn't have an output parameter called '{}'",
						fromId.id, toId.id, fl.from
					);
				}

				if (toNode.getInputParam(fl.to) is null) {
					error(
						"verifyDataFlowNames: The target node for flow {}->{}"
						" doesn't have an input parameter called '{}'",
						fromId.id, toId.id, fl.to
					);
				}
			}
		}
	}
}
