module xf.nucleus.GraphOps;

private {
	import xf.Common;
	import xf.nucleus.Graph;
	import GraphUtils = xf.utils.Graph;
	import xf.mem.StackBuffer;
	import xf.utils.BitSet : DynamicBitSet;
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


void removeUnreachableBackwards(Graph graph, GraphNodeId[] initialNodes_ ...) {
	scope stack = new StackBuffer;

	// Enough storage for all graph nodes
	auto initialNodes = stack.allocArray!(GraphNodeId)
		(graph.capacity)[0..initialNodes_.length];
		
	initialNodes[] = initialNodes_;
	
	void addInitial(GraphNodeId id) {
		assert (initialNodes.length < graph.capacity);
		initialNodes = initialNodes.ptr[0..initialNodes.length+1];
		initialNodes[$-1] = id;
	}

	// Not disposed anywhere since its storage is on the StackBuffer
	DynamicBitSet visitedNodes;
	
	visitedNodes.alloc(graph.capacity, (uword bytes) {
		void* mem = stack.allocRaw(bytes);
		memset(mem, 0, bytes);
		return mem;
	});

	// perform a backwards search and find useful nodes

	foreach (n; initialNodes) {
		visitedNodes.set(n.id);
	}
	
	while (initialNodes.length > 0) {
		GraphNodeId n = initialNodes[$-1];		
		initialNodes = initialNodes[0..$-1];

		foreach (incFrom; graph.iterIncomingConnections(n)) {
			if (!visitedNodes.isSet(incFrom.id)) {
				addInitial(incFrom);
				visitedNodes.set(incFrom.id);
			}
		}
	}

	graph.removeNodes((GraphNodeId id) {
		return !visitedNodes.isSet(id.id);
	});

	// Note: the previous version of this code also had port removal from nodes.
	// This is gone now, since graph nodes are no longer 'smart'. If such an operation
	// is desired, it must be done manually in a separate step
}
