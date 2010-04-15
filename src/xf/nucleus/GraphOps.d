module xf.nucleus.GraphOps;

private {
	import xf.nucleus.Graph;
	import GraphUtils = xf.utils.Graph;
	import xf.mem.StackBuffer;
}



void findTopologicalOrder(Graph graph, GraphNodeId[] result) {
	scope stack = new StackBuffer;
	int[] order = stack.allocArray!(int)(graph.numNodes);
	
	int numOrdered = GraphUtils.findTopologicalOrder(
		// nodeIter
		(void delegate(int) sink) {
			foreach (n; graph.iterNodes) {
				sink(n.id);
			}
		},
		
		// nodeSuccIter
		(int n, void delegate(int) sink) {
			foreach (n2; graph.iterOutgoingConnections(graph._getNodeId(n))) {
				sink(n2.id);
			}
		},
		
		order
	);

	assert (numOrdered == graph.numNodes);
	foreach (i, n; order) {
		result[i] = graph._getNodeId(n);
	}
}


void removeUnreachable(Graph, GraphNodeId[]) {
}
