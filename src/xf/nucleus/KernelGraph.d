module xf.nucleus.KernelGraph;

private {
	import xf.Common;
	import xf.nucleus.Function;
	import xf.nucleus.Graph;
	import xf.nucleus.Param;
}




struct KernelGraph {
	enum NodeType {
		Input,
		Output,
		Data,
		Calc
	}


	struct ParamNode {
		// TODO: mem management - MParamSupport uses the GC - the mem will be lost
		pragma (msg, "BUG: " ~ __FILE__ ~ " @ " ~ __LINE__.stringof);

		ParamList params;
	}


	struct CalcNode {
		Function func;		// already resolved from kernels
	}


	struct Node {
		private {
			NodeType	_type;

			union {
				ParamNode	_input;
				CalcNode	_calc;
			}
		}


		NodeType type() {
			return _type;
		}

		ParamNode* input() {
			assert (NodeType.Input == type);
			return &_input;
		}

		ParamNode* output() {
			assert (NodeType.Output == type);
			return &_input;
		}

		ParamNode* data() {
			assert (NodeType.Data == type);
			return &_input;
		}

		CalcNode* calc() {
			assert (NodeType.Calc == type);
			return &_calc;
		}
	}

	
	static KernelGraph opCall() {
		KernelGraph res;
		res._graph = .createGraph();
		return res;
	}


	void dispose() {
		if (_graph) {
			.disposeGraph(_graph);
			assert (_graph is null);
		}
	}


	GraphNodeId addNode(NodeType t) {
		assert (_graph !is null);
		final id = _graph.addNode();
		
		_allocNodes(_graph.capacity);	// HACK
		_nodes[id.id]._type = t;
		
		GraphNodeInfo info;
		
		// required for the getNode function
		info.nodeData = &_nodes[id.id];	// BUG: should not use a plain array here
		_graph.setNodeInfo(id, info);
		
		return id;
	}


	NodeTypeFruct iterNodes(GraphNodeType type) {
		return NodeTypeFruct(this, type);
	}


	NodeFruct iterNodes() {
		return NodeFruct(this);
	}


	private struct NodeTypeFruct {
		KernelGraph*	_this;
		GraphNodeType	_type;


		int opApply(int delegate(ref GraphNodeId) sink) {
			foreach (ref id; _this._graph.iterNodes()) {
				if (_this.getNode(id).type == _type) {
					if (int r = sink(id)) {
						return r;
					}
				}
			}

			return 0;
		}


		int opApply(int delegate(ref GraphNodeId, ref Node) sink) {
			foreach (ref id; _this._graph.iterNodes()) {
				auto node = _this.getNode(id);
				
				if (node.type == _type) {
					if (int r = sink(id, *node)) {
						return r;
					}
				}
			}

			return 0;
		}
	}
	

	private struct NodeFruct {
		KernelGraph*	_this;


		int opApply(int delegate(ref GraphNodeId) sink) {
			foreach (ref id; _this._graph.iterNodes()) {
				if (int r = sink(id)) {
					return r;
				}
			}

			return 0;
		}


		int opApply(int delegate(ref GraphNodeId, ref Node) sink) {
			foreach (ref id; _this._graph.iterNodes()) {
				auto node = _this.getNode(id);
				if (int r = sink(id, *node)) {
					return r;
				}
			}

			return 0;
		}
	}


	bool isValidNodeIndex(uword idx) {
		assert (_graph !is null);
		return _graph.isValidNodeIndex(idx);
	}


	Node* getNode(GraphNodeId idx) {
		assert (_graph !is null);
		final info = _graph.getNodeInfo(idx);
		return cast(Node*)info.nodeData;
	}


	private {
		// TODO: allocate them in chunks, keep a freelist, don't let them
		// change addresses
		void _allocNodes(uword num) {
			assert (false, "TODO");
		}

		
		Graph	_graph;
		Node[]	_nodes;
	}
}
