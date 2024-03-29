module xf.nucleus.graph.KernelGraph;

private {
	import xf.Common;
	import xf.nucleus.graph.Graph;
	import xf.nucleus.Param;
	import xf.nucleus.Kernel;
	import xf.nucleus.kernel.KernelDef;
	import xf.nucleus.Function;
	import xf.mem.ChunkQueue;
	import xf.mem.FreeList;
	import xf.mem.ScratchAllocator;

	static import tango.text.convert.Format;
}

public {
	import xf.nucleus.graph.GraphDefs;
}



// TODO: move this somewhere
enum SourceKernelType {
	Undefined,
	Structure,
	Reflectance,
	Material,
	Light,
	Composite
}

alias xf.nucleus.graph.Graph.GraphNodeId GraphNodeId;



class KernelGraph {
	private typedef cstring _cstring;

	
	_cstring allocString(cstring s) {
		return
			s.length > 0
		?	cast(_cstring)((cast(char*)_mem.pushBack(s.length))[0..s.length] = s)
		:	null;
	}

	
	enum NodeType {
		_Param	= 1,
		Input	= (1 << 1) | _Param,
		Output	= (2 << 1) | _Param,
		Data	= (3 << 1) | _Param,
		Kernel	= (4 << 1),
		Func	= (5 << 1),
		Bridge	= (6 << 1),
		Composite = (7 << 1),
	}


	struct ParamNode {
		alias void* delegate(size_t) Allocator;

		union {
			ParamList	params;
			Allocator	_allocator;
		}

		SourceKernelType	sourceKernelType;
		uint				sourceLightIndex;
	}


	struct BridgeNode {
		alias void* delegate(size_t) Allocator;

		union {
			ParamList	params;
			Allocator	_allocator;
		}

		enum Type {
			Input,
			Output
		}

		Type	type;
	}


	struct KernelNode {
		KernelDef	kernel;
	}


	struct FuncNode {
		Function	func;
		ParamList	params;
	}


	struct CompositeNode {
		KernelGraph			graph;
		GraphNodeId			dataNode;
		GraphNodeId			inNode;
		GraphNodeId			outNode;
		cstring				returnType;
		uint				_graphIdx = uint.max;	// no need to dup, used in codegen
		
		AbstractFunction	targetFunc;

		alias void* delegate(size_t) Allocator;

		union {
			ParamList	params;
			Allocator	_allocator;
		}
	}


	struct Node {
		ParamList	attribs;

		private {
			NodeType	_type;

			union {
				ParamNode		_inputOutputData;
				KernelNode		_kernel;
				FuncNode		_func;
				BridgeNode		_bridge;
				CompositeNode	_composite;
				Node*			_freeListNext;
			}
		}

		// Doesn't perform a deep copy for composite nodes, just refcounts the graph
		void copyTo(Node* other) {
			assert (type == other.type);
			
			other.attribs.copyFrom(attribs);

			if (type & NodeType._Param) {
				auto src = _param();
				auto dst = other._param();
				dst.sourceKernelType = src.sourceKernelType;
				dst.sourceLightIndex = src.sourceLightIndex;
				dst.params.copyFrom(src.params);
			} else {
				switch (type) {
					case NodeType.Kernel: {
						other.kernel.kernel = this.kernel.kernel;
					} break;
					case NodeType.Func: {
						auto src = func();
						auto dst = other.func();
						dst.func = src.func;
						dst.params.copyFrom(src.params);
					} break;
					case NodeType.Bridge: {
						auto src = bridge();
						auto dst = other.bridge();
						dst.params.copyFrom(src.params);
					} break;
					case NodeType.Composite: {
						auto src = composite();
						auto dst = other.composite();
						dst.graph = src.graph;
						++dst.graph._refCnt;
						dst.dataNode = src.dataNode;
						dst.inNode = src.inNode;
						dst.outNode = src.outNode;
						dst.targetFunc = src.targetFunc;
						assert (dst.params._allocator !is null);

						dst.returnType = DgScratchAllocator(
							dst.params._allocator
						).dupString(src.returnType);

						dst.params.copyFrom(src.params);
					} break;
					
					default: assert (false);
				}
			}
		}


		NodeType type() {
			return _type;
		}

		cstring typeString() {
			switch (_type) {
				case NodeType.Input: return "Input";
				case NodeType.Output: return "Output";
				case NodeType.Data: return "Data";
				case NodeType.Kernel: return "Kernel";
				case NodeType.Func: return "Func";
				case NodeType.Bridge: return "Bridge";
				case NodeType.Composite: return "Composite";
				default: assert (false);
			}
		}

		ParamNode* input() {
			assert (NodeType.Input == type);
			return &_inputOutputData;
		}

		ParamNode* output() {
			assert (NodeType.Output == type);
			return &_inputOutputData;
		}

		ParamNode* data() {
			assert (NodeType.Data == type);
			return &_inputOutputData;
		}

		KernelNode* kernel() {
			assert (NodeType.Kernel == type);
			return &_kernel;
		}

		FuncNode* func() {
			assert (NodeType.Func == type);
			return &_func;
		}

		BridgeNode* bridge() {
			assert (NodeType.Bridge == type);
			return &_bridge;
		}

		CompositeNode* composite() {
			assert (NodeType.Composite == type);
			return &_composite;
		}

		ParamNode* _param() {
			assert(NodeType._Param & type);
			return &_inputOutputData;
		}


		Param* getOutputParam(
				cstring name
		) {
			switch (_type) {
				case NodeType.Output:		return null;
				case NodeType.Input:		// fall through
				case NodeType.Data:			return _inputOutputData.params.get(name);
				case NodeType.Bridge:		return _bridge.params.get(name);
				case NodeType.Composite:	return _composite.params.get(name);
				default: {
					final p = getParamList().get(name);
					if (p.isInput) {
						error(
							"Trying to access a function's input parameter '{}'"
							" as an output.", p.toString
						);
						assert (false);
					} else {
						return p;
					}
				}
			}
		}


		Param* getInputParam(
				cstring name
		) {
			switch (_type) {
				case NodeType.Output:		return _inputOutputData.params.get(name);
				case NodeType.Input:		// fall through
				case NodeType.Data:			return null;
				case NodeType.Bridge:		return _bridge.params.get(name);
				case NodeType.Composite:	return _composite.params.get(name);
				default: {
					final p = getParamList().get(name);
					if (p is null) {
						return p;
					} else if (false == p.isInput) {
						error(
							"Trying to access a function's output parameter '{}'"
							" as an input.", p.toString
						);
						assert (false);
					} else {
						return p;
					}
				}
			}
		}


		ParamList* getParamList() {
			switch (_type) {
				case NodeType.Output:		// fall through
				case NodeType.Input:		// fall through
				case NodeType.Data:			return &_inputOutputData.params;
				case NodeType.Func:			return &_func.params;
				case NodeType.Bridge:		return &_bridge.params;
				case NodeType.Composite:	return &_composite.params;
				
				case NodeType.Kernel: {
					auto k = _kernel.kernel;
					if (k is null) {
						error("Unknown kernel: '{}'", k.func.name);
					}
					if (k.func is null) {
						error(
							"WTF, Kernel '{}' doesn't have a function.",
							k.func.name
						);
					}
					return &k.func.params;
				}
				
				default: assert (false, tango.text.convert.Format.Format("Wut. _type == {}  o_O", _type));
			}
		}
	}

	
	private this() {
		_mem.initialize();
		_graph = .createGraph();
	}


	private ~this() {
		if (_graph) {
			.disposeGraph(_graph);
			assert (_graph is null);
		}

		_mem.clear();
	}


	GraphNodeId addNode(NodeType t) {
		assert (_graph !is null);
		final id = _graph.addNode();

		Node* node = void;
		if (_nodeFreeList) {
			node = _nodeFreeList;
			_nodeFreeList = _nodeFreeList._freeListNext;
		} else {
			node = cast(Node*)_mem.pushBack(Node.sizeof);
		}

		*node = Node.init;
		node._type = t;

		node.attribs._allocator = &_mem.pushBack;
		
		GraphNodeInfo info;
		
		// required for the getNode function
		info.nodeData = node;
		_graph.setNodeInfo(id, info);

		if (t & NodeType._Param) {
			node._param._allocator = &_mem.pushBack;
		}

		if (NodeType.Bridge == t) {
			node.bridge._allocator = &_mem.pushBack;
		}

		if (NodeType.Composite == t) {
			node.composite._allocator = &_mem.pushBack;
		}
		
		if (NodeType.Func == t) {
			node.func.params._allocator = &_mem.pushBack;
		}

		return id;
	}


	GraphNodeId addFuncNode(Function func) {
		final id = addNode(NodeType.Func);
		final node = getNode(id).func();
		node.func = func;
		node.params = func.params.dup(&_mem.pushBack);
		return id;
	}


	void resetNode(GraphNodeId id, NodeType t) {
		final node = getNode(id);
		node._type = t;
		if (t & NodeType._Param) {
			node._param._allocator = &_mem.pushBack;
		} else if (NodeType.Bridge == t) {
			node.bridge._allocator = &_mem.pushBack;
		} else if (NodeType.Composite == t) {
			node.composite._allocator = &_mem.pushBack;
		}
	}


	void removeNode(GraphNodeId id) {
		auto node = getNode(id);
		if (NodeType.Composite == node.type) {
			disposeKernelGraph(node.composite.graph);
		}
		_graph.removeNode(id);
	}


	uword numNodes() {
		return _graph.numNodes;
	}


	uword capacity() {
		return _graph.capacity;
	}


	NodeTypeFruct iterNodes(NodeType type) {
		return NodeTypeFruct(this, type);
	}


	NodeFruct iterNodes() {
		return NodeFruct(this);
	}


	private struct NodeTypeFruct {
		KernelGraph	_this;
		NodeType	_type;


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
		KernelGraph	_this;


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
		_graph._verifyNodeId(idx);
		final info = _graph.getNodeInfo(idx);
		return cast(Node*)info.nodeData;
	}


	IGraphFlow flow() {
		return _graph;
	}


	Graph backend_readOnly() {
		return _graph;
	}


	ScratchFIFO		_mem;

	private {
		Node*		_nodeFreeList;
		Graph		_graph;
		int			_refCnt = 1;
	}
}


KernelGraph createKernelGraph() {
	void* mem = _kernelGraphFreeList.alloc();
	final initVal = KernelGraph.classinfo.init;
	mem[0..initVal.length] = initVal;
	final res = cast(KernelGraph)mem;
	res._ctor();
	return res;
}


/+void assureNotCyclic(KernelGraph g) {
	KernelGraph[] list;
	return assureNotCyclic(g, list);
}

void assureNotCyclic(KernelGraph g, ref KernelGraph[] list) {
	assert (g !is null);

	foreach (x; list) {
		assert (x !is g);
	}
	list ~= g;

	foreach (nid; g.iterNodes) {
		auto node = g.getNode(nid);
		if (KernelGraph.NodeType.Composite == node.type) {
			auto comp = node.composite();
			assert (comp.graph !is g);
			if (comp.graph) {
				assureNotCyclic(comp.graph, list);
			}
		}
	}
}+/


void disposeKernelGraph(ref KernelGraph g) {
	assert (g !is null);
	if (--g._refCnt <= 0) {
		foreach (nid; g.iterNodes) {
			auto node = g.getNode(nid);
			if (KernelGraph.NodeType.Composite == node.type) {
				auto comp = node.composite();
				assert (comp.graph !is g);
				if (comp.graph) {
					disposeKernelGraph(comp.graph);
				}
			}
		}
		
		g._dtor();
		memset(cast(void*)g, 0xcb, KernelGraph.classinfo.init.length);
		_kernelGraphFreeList.free(cast(void*)g);
	}
	g = null;
}


private {
	UntypedFreeList	_kernelGraphFreeList;

	// ----

	static this() {
		_kernelGraphFreeList.itemSize = KernelGraph.classinfo.init.length;
	}
}
