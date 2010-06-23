module xf.nucleus.graph.GraphOps;

private {
	import xf.Common;
	import xf.nucleus.graph.Graph;
	import GraphUtils = xf.utils.Graph;
	import xf.mem.StackBuffer;
	import xf.utils.BitSet : DynamicBitSet;
}



void findTopologicalOrder(Graph graph, GraphNodeId[] result) {
	assert (result.length == graph.numNodes);

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


/// Note: the nodes must be an isolated subgraph within 'graph'.
/// Otherwise, connection iteration will find them and things will go bada boom.
void findTopologicalOrder(Graph graph, GraphNodeId[] nodes, GraphNodeId[] result) {
	assert (result.length == nodes.length);

	scope stack = new StackBuffer;
	int[] order = stack.allocArray!(int)(nodes.length);
	
	int numOrdered = GraphUtils.findTopologicalOrder(
		// nodeIter
		(void delegate(int) sink) {
			foreach (n; nodes) {
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

	assert (numOrdered == nodes.length);
	foreach (i, n; order) {
		result[i] = graph._getNodeId(n);
	}
}


void markPrecedingNodes(Graph graph, DynamicBitSet* bs, void delegate(GraphNodeId) visitor, GraphNodeId[] initialNodes_ ...) {
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

	// perform a backwards search and find useful nodes

	foreach (n; initialNodes) {
		bs.set(n.id);
	}
	
	while (initialNodes.length > 0) {
		GraphNodeId n = initialNodes[$-1];		
		initialNodes = initialNodes[0..$-1];

		foreach (incFrom; graph.iterIncomingConnections(n)) {
			if (!bs.isSet(incFrom.id)) {
				if (visitor !is null) {
					visitor(incFrom);
				}
				addInitial(incFrom);
				bs.set(incFrom.id);
			}
		}
	}
}


void markPrecedingNodes(Graph graph, DynamicBitSet* bs, GraphNodeId[] initialNodes_ ...) {
	return markPrecedingNodes(graph, bs, null, initialNodes_);
}
	

void visitPrecedingNodes(Graph graph, void delegate(GraphNodeId) visitor, GraphNodeId[] initialNodes_ ...) {
	scope stack = new StackBuffer;

	// Not disposed anywhere since its storage is on the StackBuffer
	DynamicBitSet visitedNodes;
	
	visitedNodes.alloc(graph.capacity, &stack.allocRaw);
	visitedNodes.clearAll();

	return markPrecedingNodes(graph, &visitedNodes, visitor, initialNodes_);
}


void removeUnreachableBackwards(Graph graph, GraphNodeId[] initialNodes_ ...) {
	scope stack = new StackBuffer;

	// Not disposed anywhere since its storage is on the StackBuffer
	DynamicBitSet visitedNodes;
	
	visitedNodes.alloc(graph.capacity, &stack.allocRaw);
	visitedNodes.clearAll();

	markPrecedingNodes(graph, &visitedNodes, initialNodes_);

	graph.removeNodes((GraphNodeId id) {
		return !visitedNodes.isSet(id.id);
	});

	// Note: the previous version of this code also had port removal from nodes.
	// This is gone now, since graph nodes are no longer 'smart'. If such an operation
	// is desired, it must be done manually in a separate step
}
