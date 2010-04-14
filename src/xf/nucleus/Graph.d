module xf.nucleus.Graph;

private {
	import xf.Common;
	import xf.mem.FreeList;
	import xf.mem.ChunkQueue;
}



struct GraphNodeId {
	ushort	id;
	ushort	reuseCnt;
}


enum GraphNodeType {
	Calc,
	Data,
	Input,
	Output
}


enum GraphNodeDomain {
	Auto,
	Vertex,
	Geometry,
	Fragment
}


struct GraphNodeInfo {
	size_t			userData;
	void*			nodeData;
	GraphNodeType	type;
	GraphNodeDomain	domain;
}


final class Graph {
	GraphNodeId		addNode();
	void			removeNode(GraphNodeId);
	void			removeNodes(bool delegate(GraphNodeId));
	
	void			setNodeLabel(GraphNodeId, cstring);
	cstring			getNodeLabel(GraphNodeId);
	
	GraphNodeInfo	getNodeInfo();
	void			setNodeInfo(GraphNodeInfo);

	size_t			numNodes();
	GraphNodeFruct	iterNodes();

	void			addDataFlow(GraphNodeId, cstring, GraphNodeId, cstring);
	void			removeDataFlow(GraphNodeId, cstring, GraphNodeId, cstring);
	void			removeDataFlow(GraphNodeId, GraphNodeId, bool delegate(cstring, cstring));
	FlowFruct		iterDataFlow(GraphNodeId, GraphNodeId);
	
	void			addAutoFlow(GraphNodeId, GraphNodeId);
	void			removeAutoFlow(GraphNodeId, GraphNodeId);
	bool			hasAutoFlow(GraphNodeId, GraphNodeId);

	void			removeAllFlow(GraphNodeId, GraphNodeId);

	void			minimizeMemoryUsage();


	private {
		ScratchFIFO	_mem;

		this() {
			_mem.initialize();
		}

		~this() {
			_mem.clear();
		}

		int _iterDataFlow(
			GraphNodeId, GraphNodeId, int delegate(ref cstring, ref cstring)
		);

		int _iterNodes(int delegate(ref GraphNodeId));
	}
}


Graph createGraph() {
	void* mem = _graphFreeList.alloc();
	final initVal = Graph.classinfo.init;
	mem[0..initVal.length] = initVal;
	final res = cast(Graph)mem;
	res._ctor();
	return res;
}


void disposeGraph(ref Graph g) {
	assert (g !is null);
	g._dtor();
	memset(cast(void*)g, 0xcb, Graph.classinfo.init.length);
	_graphFreeList.free(cast(void*)g);
	g = null;
}


private {
	struct FlowFruct {
		Graph		graph;
		GraphNodeId	fromNode, toNode;
		
		// The strings should be copied to stack-based buffers and only valid within
		// the call that opApply will do to the sink delegate
		int opApply(int delegate(ref cstring, ref cstring) sink) {
			return graph._iterDataFlow(fromNode, toNode, sink);
		}
	}

	struct GraphNodeFruct {
		Graph graph;

		int opApply(int delegate(ref GraphNodeId) sink) {
			return graph._iterNodes(sink);
		}
	}

	// ----

	UntypedFreeList	_graphFreeList;

	// ----

	static this() {
		_graphFreeList.itemSize = Graph.classinfo.init.length;
	}
}
