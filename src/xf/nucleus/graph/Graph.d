module xf.nucleus.graph.Graph;

private {
	import xf.Common;
	import xf.mem.FreeList;
	import xf.mem.ChunkQueue;
	import xf.mem.StackBuffer;
	import xf.mem.SmallTempArray;
	import xf.omg.core.Misc : min, max;
	import xf.nucleus.Log : error = nucleusError, log = nucleusLog;
}

public {
	import xf.nucleus.graph.GraphDefs;
}



struct GraphNodeInfo {
	size_t	userData;
	void*	nodeData;
}


// version = DebugGraphConnections;



interface IGraphFlow {
	size_t			numNodes();
	size_t			capacity();
	GraphNodeFruct	iterNodes();
	DataFlow*		addDataFlow(
			GraphNodeId from, cstring fromPort,
			GraphNodeId to, cstring toPort,
			bool* newFlow = null
	);
	void			removeDataFlow(
			GraphNodeId from, cstring fromPort,
			GraphNodeId to, cstring toPort
	);
	void			removeDataFlow(
			GraphNodeId from, GraphNodeId to,
			bool delegate(cstring, cstring) pred = null
	);
	FlowFruct		iterDataFlow(GraphNodeId from, GraphNodeId to);
	OutgoingConnectionFruct	iterOutgoingConnections(GraphNodeId id);
	IncomingConnectionFruct	iterIncomingConnections(GraphNodeId id);
	void			addAutoFlow(GraphNodeId from, GraphNodeId to);
	void			removeAutoFlow(GraphNodeId from, GraphNodeId to);
	bool			hasAutoFlow(GraphNodeId from, GraphNodeId to);
	void			removeAllAutoFlow();
	void			removeAllFlow(GraphNodeId from, GraphNodeId to);
}


// A class, but not to be used with GC memory
final class Graph : IGraphFlow {
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
			// do not clear the old stuff. something could be still iterating over it
		}

	gotNodeId:		// <----
		++_numNodes;
		_writeFlag(_presentFlags, res.id, true);
		_nodeInfos[res.id] = GraphNodeInfo.init;
		_nodeLabels[res.id] = null;
		// _dataFlow[res.id] is already good and its items can be reused

		version (DebugGraphConnections) {
			foreach (con; iterIncomingConnections(res)) { assert (false); }
			foreach (con; iterOutgoingConnections(res)) { assert (false); }
		}
		
		return res;
	}

	GraphNodeId		_getNodeId(uword idx) {
		assert (idx < _capacity);
		assert (true == _readFlag(_presentFlags, idx));
		return GraphNodeId(cast(ushort)idx, _idReuseCounts[idx]);
	}


	bool isValidNodeIndex(uword idx) {
		return idx < _capacity && _readFlag(_presentFlags, idx);
	}
	

	/**
	 * Marks the node as unused. Does not shift node IDs around.
	 */
	void			removeNode(GraphNodeId id) {
		_verifyNodeId(id);

		version (DebugGraphConnections) {
			foreach (con; iterIncomingConnections(id)) {}
			foreach (con; iterOutgoingConnections(id)) {}
		}

		_removeExternalConnectionsToAndFrom(id);
		
		// so their items can be reused
		_disposeConnectionList(&_incomingConnections[id.id]);
		_disposeConnectionList(&_outgoingConnections[id.id]);

		for (uword i = 0; i < _capacity; ++i) {
			_writeFlag(_autoFlowFlags, id.id, i, false);
			_writeFlag(_autoFlowFlags, i, id.id, false);
		}

		++_idReuseCounts[id.id];
		_writeFlag(_presentFlags, id.id, false);

		assert (_numNodes > 0);
		--_numNodes;
	}
	
	void			removeNodes(bool delegate(GraphNodeId) pred) {
		for (uword i = 0; i < _capacity; ++i) {
			if (_readFlag(_presentFlags, i)) {
				final id = GraphNodeId(cast(ushort)i, _idReuseCounts[i]);
				
				if (pred(id)) {
					_removeExternalConnectionsToAndFrom(id);

					// so their items can be reused
					_disposeConnectionList(&_incomingConnections[i]);
					_disposeConnectionList(&_outgoingConnections[i]);

					for (uword j = 0; j < _capacity; ++j) {
						_writeFlag(_autoFlowFlags, id.id, j, false);
						_writeFlag(_autoFlowFlags, j, id.id, false);
					}

					++_idReuseCounts[i];
					_writeFlag(_presentFlags, i, false);

					assert (_numNodes > 0);
					--_numNodes;
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

	size_t			capacity() {
		return _capacity;
	}
	
	GraphNodeFruct	iterNodes() {
		return GraphNodeFruct(this);
	}

	// ----

	DataFlow*		addDataFlow(
			GraphNodeId from, cstring fromPort,
			GraphNodeId to, cstring toPort,
			bool* newFlow = null
	) {
		_verifyNodeId(from);
		_verifyNodeId(to);
		
		assert (from.id != to.id);
		
		ConnectionList* outList = &_outgoingConnections[from.id];
		ConnectionList* incList = &_incomingConnections[to.id];
		Connection* con;
		
		foreach (item; outList.items) {
			if (item.from.id is from.id) {
				assert (item.from.reuseCnt is from.reuseCnt);
				if (item.to.id is to.id) {
					assert (item.to.reuseCnt is to.reuseCnt);
					con = item;
				}
			}
		}

		if (con !is null) {
			version (DebugGraphConnections) {
				assert (con.alive);
			}

			if (auto fl = con.containsFlow(fromPort, toPort)) {
				if (newFlow) *newFlow = false;
				return fl;
			}
		} else {
			con = _allocConnection();
			con.from = from;
			con.to = to;

			outList.pushBack(
				con,
				&_mem.pushBack
			);

			incList.pushBack(
				con,
				&_mem.pushBack
			);
		}

		con.pushBack(
			DataFlow(
				_allocString(fromPort),
				_allocString(toPort)
			),
			&_mem.pushBack
		);

		if (newFlow) *newFlow = true;

		return &con.items[con.length-1];
	}
	
	void			removeDataFlow(
			GraphNodeId from, cstring fromPort,
			GraphNodeId to, cstring toPort
	) {
		_verifyNodeId(from);
		_verifyNodeId(to);
		ConnectionList* outList = &_outgoingConnections[from.id];
		ConnectionList* incList = &_incomingConnections[to.id];
		Connection* con;
		
		foreach (item; outList.items) {
			if (item.from.id is from.id) {
				assert (item.from.reuseCnt is from.reuseCnt);
				if (item.to.id is to.id) {
					assert (item.to.reuseCnt is to.reuseCnt);
					con = item;
				}
			}
		}

		if (con !is null) {
			if (auto fl = con.containsFlow(fromPort, toPort)) {
				con.remove(fl);

				if (0 == con.length) {
					_disconnectUnsafe(con);
				}
			} else {
				error(
					"Data flow from {}:{} to {}:{} doesn't exist:"
					" valid node connection, no such data flow.",
					from.id, fromPort, to.id, toPort
				);
			}
		} else {
			error(
				"Data flow from {}:{} to {}:{} doesn't exist:"
				" no such connection.",
				from.id, fromPort, to.id, toPort
			);
		}
	}
	
	void			removeDataFlow(
			GraphNodeId from, GraphNodeId to,
			bool delegate(cstring, cstring) pred = null
	) {
		_verifyNodeId(from);
		_verifyNodeId(to);
		ConnectionList* outList = &_outgoingConnections[from.id];
		ConnectionList* incList = &_incomingConnections[to.id];
		Connection* con;
		
		foreach (item; outList.items) {
			if (item.from.id is from.id) {
				assert (item.from.reuseCnt is from.reuseCnt);
				if (item.to.id is to.id) {
					assert (item.to.reuseCnt is to.reuseCnt);
					con = item;
				}
			}
		}

		if (con !is null) {
			con.removeMatching((DataFlow fl) {
				return pred ? pred(fl.from, fl.to) : true;
			});

			if (0 == con.length) {
				_disconnectUnsafe(con);
			}
		} else {
			error(
				"Data flow from {} to {} doesn't exist:"
				" no such connection.",
				from.id, to.id
			);
		}
	}
	
	FlowFruct		iterDataFlow(GraphNodeId from, GraphNodeId to) {
		return FlowFruct(this, from, to);
	}

	// ----

	OutgoingConnectionFruct	iterOutgoingConnections(GraphNodeId id) {
		return OutgoingConnectionFruct(this, id);
	}
	
	IncomingConnectionFruct	iterIncomingConnections(GraphNodeId id) {
		return IncomingConnectionFruct(this, id);
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

	void			removeAllAutoFlow() {
		alias _capacity num;
		memset(_autoFlowFlags, 0, uword.sizeof * ((num*num+wordBits-1) / wordBits));
	}

	// ----

	void			removeAllFlow(GraphNodeId from, GraphNodeId to) {
		_verifyNodeId(from);
		_verifyNodeId(to);

		// remove auto flow
		
		_writeFlag(_autoFlowFlags, from.id, to.id, false);

		// remove data flow

		ConnectionList* outList = &_outgoingConnections[from.id];
		ConnectionList* incList = &_incomingConnections[to.id];
		Connection* con;
		
		foreach (item; outList.items) {
			if (item.from.id is from.id) {
				assert (item.from.reuseCnt is from.reuseCnt);
				if (item.to.id is to.id) {
					assert (item.to.reuseCnt is to.reuseCnt);
					con = item;
				}
			}
		}

		if (con !is null) {
			_disconnectUnsafe(con);
		} else {
			error(
				"Data flow from {} to {} doesn't exist:"
				" no such connection.",
				from.id, to.id
			);
		}
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

		assert (maxUsed+1 >= numNodes);

		if (uword.max == maxUsed) {
			//log.trace("Graph.minimizeMemoryUsage(): Disposing all storage.");
			_dispose();
			assert (0 == countUsedBytes);
		} else {
			ScratchFIFO oldStorage = _mem;
			_mem = ScratchFIFO.init;
			_mem.initialize();
			//log.trace("Graph.minimizeMemoryUsage(): Allocating {} nodes.", maxUsed+1);
			_reallocateNodes(maxUsed+1);
			oldStorage.clear();
			_connectionFreeList = null;		// In old mem now, do not want.
		}
	}


	uword			countUsedBytes() {
		return _mem.countUsedBytes();
	}
	

	/**
	 * Deletes all nodes and connections.
	 */
	void			reset() {
		_dispose();
		_mem.initialize();
	}


	version (DebugGraphConnections) {
		void sanityCheck() {
			foreach (n; iterNodes) {
				foreach (con; iterOutgoingConnections(n)) {
					foreach (fl; iterDataFlow(n, con)) {}
				}
				foreach (con; iterIncomingConnections(n)) {
					foreach (fl; iterDataFlow(con, n)) {}
				}
			}
		}
	}



	private {
		ScratchFIFO	_mem;

		void _dispose() {
			_mem.clear();
			
			_presentFlags = null;
			_idReuseCounts = null;
			_nodeInfos = null;
			_nodeLabels = null;
			_autoFlowFlags = null;

			_incomingConnections = null;
			_outgoingConnections = null;
			
			_connectionFreeList = null;
			
			_numNodes = 0;
			_capacity = 0;
		}

		this() {
			_mem.initialize();
		}

		~this() {
			_dispose();
		}

		int _iterDataFlow(
				GraphNodeId from, GraphNodeId to, int delegate(ref DataFlow) sink
		) {
			_verifyNodeId(from);
			_verifyNodeId(to);
			
			ConnectionList* outList = &_outgoingConnections[from.id];
			Connection* con;

			version (DebugGraphConnections) {
				ConnectionList* incList = &_incomingConnections[to.id];
				Connection* con2;
			}
			
			foreach (item; outList.items) {
				version (DebugGraphConnections) {
					assert (item.alive);
				}

				if (item.from.id is from.id) {
					assert (item.from.reuseCnt is from.reuseCnt);
					if (item.to.id is to.id) {
						assert (item.to.reuseCnt is to.reuseCnt);
						con = item;
					}
				}
			}

			version (DebugGraphConnections) {
				foreach (item; incList.items) {
					version (DebugGraphConnections) {
						assert (item.alive);
					}

					if (item.from.id is from.id) {
						assert (item.from.reuseCnt is from.reuseCnt);
						if (item.to.id is to.id) {
							assert (item.to.reuseCnt is to.reuseCnt);
							con2 = item;
						}
					}
				}

				if (con !is con2) {
					error("con == {:x}, con2 == {:x}", con, con2);
				}
			}


			if (con !is null) {
				auto items = con.items();
				foreach (ref fl; items) {
					cstring fb = fl.from;
					cstring tb = fl.to;
					int r = sink(fl);
					assert (fb is fl.from, "Do not touch the strings :F");
					assert (tb is fl.to, "Do not touch the strings :F");
					if (r) return r;
				}
			} else if (!hasAutoFlow(from, to)) {
				error(
					"Data flow from {} to {} doesn't exist:"
					" no such connection.",
					from.id, to.id
				);
			}

			return 0;
		}

		int _iterNodes(int delegate(ref GraphNodeId) sink) {
			for (uword i = 0; i < _capacity; ++i) {
				if (_readFlag(_presentFlags, i)) {
					auto id = GraphNodeId(cast(ushort)i, _idReuseCounts[i]);
					if (int r = sink(id)) {
						return r;
					}
				}
			}

			return 0;
		}

		int	_iterOutgoingConnections(GraphNodeId from, int delegate(ref GraphNodeId) sink) {
			_verifyNodeId(from);

			ConnectionList* outList = &_outgoingConnections[from.id];

			// auto flow

			for (uword to = 0; to < _capacity; ++to) {
				if (	from.id != to
					&&	_readFlag(_presentFlags, to)
					&&	_readFlag(_autoFlowFlags, from.id, to)
				) {
					if (int r = sink(GraphNodeId(cast(ushort)to, _idReuseCounts[to]))) {
						return r;
					}
				}
			}

			// data flow
			
			foreach (item; outList.items) {
				auto con = item.to;

				version (DebugGraphConnections) {
					assert (item.alive);
				}

				if (!_readFlag(_autoFlowFlags, from.id, item.to.id)) {
					if (int r = sink(con)) {
						return r;
					}
				}
			}

			return 0;
		}

		int	_iterIncomingConnections(GraphNodeId to, int delegate(ref GraphNodeId) sink) {
			_verifyNodeId(to);

			ConnectionList* incList = &_incomingConnections[to.id];

			// auto flow

			for (uword from = 0; from < _capacity; ++from) {
				if (	from != to.id
					&&	_readFlag(_presentFlags, from)
					&&	_readFlag(_autoFlowFlags, from, to.id)
				) {
					if (int r = sink(GraphNodeId(cast(ushort)from, _idReuseCounts[from]))) {
						return r;
					}
				}
			}

			// data flow

			foreach (item; incList.items) {
				auto con = item.from;

				version (DebugGraphConnections) {
					assert (item.alive);
				}

				if (!_readFlag(_autoFlowFlags, item.from.id, to.id)) {
					if (int r = sink(con)) {
						return r;
					}
				}
			}

			return 0;
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

				mixin MSmallTempArray!(DataFlow);

				version (DebugGraphConnections) {
					bool alive = false;
				}

				// used to track the new/real connection when reallocating the graph
				Connection* _reallocReal;
			}

			DataFlow* containsFlow(cstring from, cstring to) {
				foreach (ref it; items) {
					if (it.from == from && it.to == to) {
						return &it;
					}
				}

				return null;
			}

			// occupies the same space as the 'from' GraphNodeId, thus safe to reuse
			Connection*	_freeListNext;
		}
		

		uword*				_presentFlags;
		ushort*				_idReuseCounts;
		GraphNodeInfo*		_nodeInfos;
		cstring*			_nodeLabels;
		uword*				_autoFlowFlags;		// _capacity * _capacity binary matrix
		
		ConnectionList*		_incomingConnections;
		ConnectionList*		_outgoingConnections;
		
		Connection*			_connectionFreeList;
		
		uword			_numNodes;
		uword			_capacity;

		enum { wordBits = word.sizeof * 8 }


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
			return (flags[idx / wordBits] & (1 << (idx % wordBits))) != 0;
		}

		static void _writeFlag(uword* flags, uword idx, bool val) {
			final i = idx / wordBits;
			final i2 = idx % wordBits;
			flags[i] &= ~(cast(uword)1 << i2);
			flags[i] |= (cast(uword)val << i2);
		}

		bool _readFlag(uword* flags, uword idx1, uword idx2) {
			return _readFlag(flags, idx1 * _capacity + idx2);
		}

		void _writeFlag(uword* flags, uword idx1, uword idx2, bool val) {
			return _writeFlag(flags, idx1 * _capacity + idx2, val);
		}

		void _writeFlag(uword* flags, uword idx1, uword idx2, bool val, uword capacity) {
			return _writeFlag(flags, idx1 * capacity + idx2, val);
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
			log.trace("Graph._reallocateNodes()");

			version (DebugGraphConnections) sanityCheck();
			
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

			// zeroed because the items are reusable
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
						_writeFlag(autoFlowFlags, i, j, true, num);
					}
				}

				// copy data connections

				void copyConnections(ref ConnectionList dst, ref ConnectionList src) {
					dst.alloc(src.length, &_mem.pushBack);
					foreach (conI, ref dstCon; dst.items) {
						assert (dstCon is null);
						dstCon = _allocConnection();
						
						final srcCon = src._items[conI];
						assert (srcCon !is null);
						
						dstCon.from = srcCon.from;
						dstCon.to = srcCon.to;
						dstCon.alloc(srcCon.length, &_mem.pushBack);
						foreach (flowI, ref dstFlow; dstCon.items) {
							final srcFlow = srcCon._items[flowI];
							dstFlow.from = _allocString(srcFlow.from);
							dstFlow.to = _allocString(srcFlow.to);
						}

						src._items[conI]._reallocReal = dstCon;
					}
				}

				copyConnections(incomingConnections[i], _incomingConnections[i]);
			}

			for (int i = 0; i < _capacity; ++i) {
				// the node didn't even exist
				if (!_readFlag(_presentFlags, i)) {
					continue;
				}

				void shallowCopyConnections(ref ConnectionList dst, ref ConnectionList src) {
					dst.alloc(src.length, &_mem.pushBack);
					foreach (conI, ref dstCon; dst.items) {
						assert (dstCon is null);
						dstCon = src._items[conI]._reallocReal;
						assert (dstCon !is null);
					}
				}

				shallowCopyConnections(outgoingConnections[i], _outgoingConnections[i]);
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

			version (DebugGraphConnections) sanityCheck();
		}

		uword _getNewCapacity() {
			return _capacity + 64;
		}

		void _verifyNodeId(GraphNodeId id) {
			assert (id.id < _capacity, "Node ID out of range.");
			assert (true == _readFlag(_presentFlags, id.id), "The node ID had been removed.");
			assert (id.reuseCnt == _idReuseCounts[id.id], "Stale node handle.");
		}

		void _disposeConnectionList(ConnectionList* list) {
			foreach (ref item; list.items) {
				_disposeConnection(item);
			}
			list._length = 0;
		}

		Connection* _allocConnection() {
			if (_connectionFreeList !is null) {
				auto con = _connectionFreeList;

				version (DebugGraphConnections) {
					assert (!con.alive);
					con.alive = true;
				}

				_connectionFreeList = con._freeListNext;
				con._freeListNext = null;
				assert (0 == con._length);		// must be properly disposed
				return con;
			} else {
				auto con = cast(Connection*)_mem.pushBack(Connection.sizeof);
				*con = Connection.init;
				version (DebugGraphConnections) {
					con.alive = true;
				}
				return con;
			}
		}

		// Warning: Doesn't remove the connection from the incoming and outgoing lists
		void _disposeConnection(Connection* con) {
			version (DebugGraphConnections) {
				assert (con.alive);
				con.alive = false;
			}

			con._length = 0;
			con._freeListNext = _connectionFreeList;
			_connectionFreeList = con;
		}

		void _removeExternalConnectionsToAndFrom(GraphNodeId id) {
			_verifyNodeId(id);
			
			final inc = &_incomingConnections[id.id];
			final oug = &_outgoingConnections[id.id];

			scope stack = new StackBuffer;
			final _conNodes = stack.allocArray!(ushort)(max(inc.length, oug.length));
			uword numCon;

			// remove all outgoing connections for nodes that are incoming to this node
			{
				numCon = 0;

				foreach (con; inc.items) {
					_conNodes[numCon++] = con.from.id;
				}

				foreach (n; _conNodes[0..numCon]) {
					_outgoingConnections[n].removeMatching((Connection* c) {
						return c.to.id == id.id;
					});
				}
			}

			// remove all incoming connections for nodes that are outgoing from this node
			{
				numCon = 0;

				foreach (con; oug.items) {
					_conNodes[numCon++] = con.to.id;
				}

				foreach (n; _conNodes[0..numCon]) {
					_incomingConnections[n].removeMatching((Connection* c) {
						return c.from.id == id.id;
					});
				}
			}
		}

		// Unsafe because it may bork collections that are being iterated upon
		void _disconnectUnsafe(Connection* con) {
			ConnectionList* outList = &_outgoingConnections[con.from.id];
			ConnectionList* incList = &_incomingConnections[con.to.id];

			outList.removeMatching((Connection* c2) {
				return con is c2;
			});
			incList.removeMatching((Connection* c2) {
				return con is c2;
			});

			_disposeConnection(con);
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
		int opApply(int delegate(ref DataFlow) sink) {
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
