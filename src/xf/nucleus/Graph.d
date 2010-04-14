module xf.nucleus.Graph;

private {
	import xf.Common;
	import xf.mem.FreeList;
	import xf.mem.ChunkQueue;
	import xf.omg.core.Misc : min;
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



template MSmallTempArray(T) {
	enum { GrowBy = 8 }
	
	T[] items() {
		return _items[0.._length];
	}

	ushort length() {
		return _length;
	}

	void pushBack(T item, ScratchFIFO mem) {
		if (_length < _capacity) {
			_items[_length++] = item;
		} else {
			_capacity += GrowBy;
			T* items = cast(T*)mem.pushBack(_capacity * T.sizeof);
			items[0.._length] = _items[0.._length];
			items[_length.._capacity] = T.init;
		}
	}

	void alloc(ushort num, ScratchFIFO mem) {
		if (num > 0) {
			_capacity = cast(ushort)(((num + cast(ushort)(GrowBy-1)) / GrowBy) * GrowBy);
			_items = cast(T*)mem.pushBack(_capacity * T.sizeof);
			_length = num;
			items[0.._capacity] = T.init;
		} else {
			_items = null;
			_length = 0;
			_capacity = 0;
		}
	}
	

	T*		_items;
	ushort	_length;
	ushort	_capacity;
}


final class Graph {
	/**
	 * Prepares storage for a new node and returns a handle to it.
	 */
	GraphNodeId		addNode() {
		GraphNodeId res;
		
		if (_numNodes < _capacity) {
			// yay, can reuse a node
			for (uword i = 0; i < _capacity; ++i) {
				if (!_readFlag(_presentFlags, i)) {
					res = GraphNodeId(cast(ushort)i, _idReuseCounts[i]);
					goto gotNodeId;		// <---
				}
			}

			assert (false, "Thought there was an unused node but all flags were set.");
		} else {
			// aww, must reallocate
			res = GraphNodeId(cast(ushort)_capacity, 0);
			_reallocateNodes(_getNewCapacity());
		}

	gotNodeId:		// <----
		++_numNodes;
		_writeFlag(_presentFlags, res.id, true);
		_nodeInfos[res.id] = GraphNodeInfo.init;
		_nodeLabels[res.id] = null;
		// _dataFlow[res.id] is already good and its items can be reused
		
		return res;
	}

	/**
	 * Marks the node as unused. Does not shift node IDs around.
	 */
	void			removeNode(GraphNodeId id) {
		_verifyNodeId(id);
		_writeFlag(_presentFlags, id.id, false);
		++_idReuseCounts[id.id];
		
		// so their items can be reused
		_incomingConnections[id.id]._length = 0;
		_outgoingConnections[id.id]._length = 0;
	}
	
	void			removeNodes(bool delegate(GraphNodeId) pred) {
		for (uword i = 0; i < _capacity; ++i) {
			if (_readFlag(_presentFlags, i)) {
				if (pred(GraphNodeId(cast(ushort)i, _idReuseCounts[i]))) {
					_writeFlag(_presentFlags, i, false);
					++_idReuseCounts[i];

					// so their items can be reused
					_incomingConnections[i]._length = 0;
					_outgoingConnections[i]._length = 0;
				}
			}
		}
	}

	// ----
	
	void			setNodeLabel(GraphNodeId id, cstring label) {
		_verifyNodeId(id);
		_nodeLabels[id.id] = _allocString(label);
	}

	/// The return type is cstring, thus do not touch it
	cstring			getNodeLabel(GraphNodeId id) {
		_verifyNodeId(id);
		return _nodeLabels[id.id];
	}

	// ----
	
	GraphNodeInfo	getNodeInfo(GraphNodeId id) {
		_verifyNodeId(id);
		return _nodeInfos[id.id];
	}
	
	void			setNodeInfo(GraphNodeId id, GraphNodeInfo info) {
		_verifyNodeId(id);
		_nodeInfos[id.id] = info;
	}

	// ----

	size_t			numNodes() {
		return _numNodes;
	}
	
	GraphNodeFruct	iterNodes() {
		return GraphNodeFruct(this);
	}

	// ----

	void			addDataFlow(GraphNodeId, cstring, GraphNodeId, cstring) {
		assert (false, "TODO");
	}
	
	void			removeDataFlow(GraphNodeId, cstring, GraphNodeId, cstring) {
		assert (false, "TODO");
	}
	
	void			removeDataFlow(GraphNodeId, GraphNodeId, bool delegate(cstring, cstring)) {
		assert (false, "TODO");
	}
	
	FlowFruct		iterDataFlow(GraphNodeId, GraphNodeId) {
		assert (false, "TODO");
	}

	// ----

	OutgoingConnectionFruct	iterOutgoingConnections(GraphNodeId) {
		assert (false, "TODO");
	}
	
	IncomingConnectionFruct	iterIncomingConnections(GraphNodeId) {
		assert (false, "TODO");
	}

	// ----
	
	void			addAutoFlow(GraphNodeId from, GraphNodeId to) {
		_verifyNodeId(from);
		_verifyNodeId(to);
		_writeFlag(_autoFlowFlags, from.id, to.id, true);
	}
	
	void			removeAutoFlow(GraphNodeId from, GraphNodeId to) {
		_verifyNodeId(from);
		_verifyNodeId(to);
		_writeFlag(_autoFlowFlags, from.id, to.id, false);
	}
	
	bool			hasAutoFlow(GraphNodeId from, GraphNodeId to) {
		_verifyNodeId(from);
		_verifyNodeId(to);
		return _readFlag(_autoFlowFlags, from.id, to.id);
	}

	// ----

	void			removeAllFlow(GraphNodeId from, GraphNodeId to) {
		_writeFlag(_autoFlowFlags, from.id, to.id, false);
		assert (false, "TODO");
	}

	// ----

	/**
	 * Tries to minimize the number of allocations by reducing the capacity of
	 * various storage to the smallest possible value (highest index of a used
	 * graph node + 1). Frees the old memory used internally and moves everything
	 * to new storage.
	 */
	void			minimizeMemoryUsage() {
		uword maxUsed = uword.max;
		for (uword i = 0; i < _capacity; ++i) {
			if (_readFlag(_presentFlags, i)) {
				maxUsed = i;
			}
		}

		if (uword.max == maxUsed) {
			dispose();
		} else {
			ScratchFIFO oldStorage = _mem;
			_mem = ScratchFIFO.init;
			_reallocateNodes(maxUsed+1);
			oldStorage.clear();
		}
	}

	/**
	 * Deletes all nodes and connections.
	 */
	void			dispose() {
		_mem.clear();
		_presentFlags = null;
		_idReuseCounts = null;
		_nodeInfos = null;
		_nodeLabels = null;
		_autoFlowFlags = null;

		_incomingConnections = null;
		_outgoingConnections = null;
		
		_connectionFreeList = null;
		_dataFlowFreeList = null;
		
		_numNodes = 0;
		_capacity = 0;
	}


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

		int _iterNodes(int delegate(ref GraphNodeId)) {
			assert (false, "TODO");
		}

		int	_iterOutgoingConnections(GraphNodeId, int delegate(ref GraphNodeId)) {
			assert (false, "TODO");
		}

		int	_iterIncomingConnections(GraphNodeId, int delegate(ref GraphNodeId)) {
			assert (false, "TODO");
		}
	}

	private {
		struct ConnectionList {
			mixin MSmallTempArray!(Connection*);
		}
		
		union Connection {
			struct {
				GraphNodeId	from;
				GraphNodeId	to;

				mixin MSmallTempArray!(DataFlow*);
			}

			Connection*	_freeListNext;
		}
		
		union DataFlow {
			struct {
				struct Item {
					cstring from;
					cstring to;
				}

				mixin MSmallTempArray!(Item);
			}

			DataFlow* _freeListNext;
		}

		uword*				_presentFlags;
		ushort*				_idReuseCounts;
		GraphNodeInfo*		_nodeInfos;
		cstring*			_nodeLabels;
		uword*				_autoFlowFlags;		// _capacity * _capacity binary matrix
		
		ConnectionList*		_incomingConnections;
		ConnectionList*		_outgoingConnections;
		
		Connection*			_connectionFreeList;
		DataFlow*			_dataFlowFreeList;
		
		uword			_numNodes;
		uword			_capacity;

		enum { wordBits = uword.sizeof * 8 }


		void _alloc(T)(ref T* ptr, int num, float zero = false) {
			if (num > 0) {
				ptr = cast(T*)_mem.pushBack(T.sizeof * num);
				if (zero) {
					memset(ptr, 0, T.sizeof * num);
				}
			} else {
				ptr = null;
			}
		}

		static bool _readFlag(uword* flags, uword idx) {
			return (flags[idx / wordBits] & (1 << (wordBits % wordBits))) != 0;
		}

		static void _writeFlag(uword* flags, uword idx, bool val) {
			final i = idx / wordBits;
			flags[i] &= ~(cast(uword)1 << (wordBits % wordBits));
			flags[i] |= (cast(uword)val << (wordBits % wordBits));
		}

		bool _readFlag(uword* flags, uword idx1, uword idx2) {
			return _readFlag(flags, idx1 * _capacity + idx2);
		}

		void _writeFlag(uword* flags, uword idx1, uword idx2, bool val) {
			return _writeFlag(flags, idx1 * _capacity + idx2, val);
		}

		cstring _allocString(cstring s) {
			if (s.length > 0) {
				cstring ns = (cast(char*)_mem.pushBack(s.length))[0..s.length];
				ns[] = s;
				return ns;
			} else {
				return null;
			}
		}


		void _reallocateNodes(int num) {
			uword*			presentFlags;
			ushort*			idReuseCounts;
			GraphNodeInfo*	nodeInfos;
			cstring*		nodeLabels;
			uword*			autoFlowFlags;
			ConnectionList*	incomingConnections;
			ConnectionList*	outgoingConnections;

			// Allocate storage

			_alloc(presentFlags, (num+wordBits-1) / wordBits, true);
			_alloc(idReuseCounts, num, true);
			_alloc(nodeInfos, num);
			_alloc(nodeLabels, num);
			_alloc(autoFlowFlags, (num*num+wordBits-1) / wordBits, true);

			// zeroed because the items are re-usable
			_alloc(incomingConnections, num, true);
			_alloc(outgoingConnections, num, true);

			// Copy the old data

			{
				final minCounts = min(num, _capacity);
				idReuseCounts[0..minCounts] = _idReuseCounts[0..minCounts];
			}

			for (int i = 0; i < _capacity; ++i) {
				// the node didn't even exist
				if (!_readFlag(_presentFlags, i)) {
					continue;
				}

				// copy the simple stuff

				_writeFlag(presentFlags, i, true);
				
				nodeInfos[i] = _nodeInfos[i];
				nodeLabels[i] = _allocString(_nodeLabels[i]);

				// copy auto flow flags
				
				for (int j = 0; j < _capacity; ++j) {
					if (_readFlag(_autoFlowFlags, i, j)) {
						_writeFlag(autoFlowFlags, i, j, true);
					}
				}

				// copy data connections

				void copyConnections(ref ConnectionList dst, ref ConnectionList src) {
					dst.alloc(src.length, _mem);
					foreach (conI, ref dstCon; dst.items) {
						final srcCon = src._items[conI];
						dstCon.from = srcCon.from;
						dstCon.to = srcCon.to;
						dstCon.alloc(srcCon.length, _mem);
						foreach (flowI, ref dstFlow; dstCon.items) {
							final srcFlow = srcCon._items[flowI];
							dstFlow.alloc(srcFlow.length, _mem);
							foreach (dataI, ref dstData; dstFlow.items) {
								final srcData = srcFlow._items[dataI];
								dstData.from = _allocString(srcData.from);
								dstData.to = _allocString(srcData.to);
							}
						}
					}
				}
				
				copyConnections(incomingConnections[i], _incomingConnections[i]);
				copyConnections(outgoingConnections[i], _outgoingConnections[i]);
			}

			// replace the currently set data

			_capacity = num;
			_presentFlags = presentFlags;
			_idReuseCounts = idReuseCounts;
			_nodeInfos = nodeInfos;
			_nodeLabels = nodeLabels;
			_autoFlowFlags = autoFlowFlags;
			_incomingConnections = incomingConnections;
			_outgoingConnections = outgoingConnections;
			_connectionFreeList = null;
			_dataFlowFreeList = null;
		}

		uword _getNewCapacity() {
			return _capacity + 32;
		}

		void _verifyNodeId(GraphNodeId id) {
			assert (id.id < _capacity);
			assert (true == _readFlag(_presentFlags, id.id));
			assert (id.reuseCnt == _idReuseCounts[id.id]);
		}
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

	struct OutgoingConnectionFruct {
		Graph		graph;
		GraphNodeId	source;

		int opApply(int delegate(ref GraphNodeId) sink) {
			return graph._iterOutgoingConnections(source, sink);
		}
	}

	struct IncomingConnectionFruct {
		Graph		graph;
		GraphNodeId	target;

		int opApply(int delegate(ref GraphNodeId) sink) {
			return graph._iterIncomingConnections(target, sink);
		}
	}

	// ----

	UntypedFreeList	_graphFreeList;

	// ----

	static this() {
		_graphFreeList.itemSize = Graph.classinfo.init.length;
	}
}
