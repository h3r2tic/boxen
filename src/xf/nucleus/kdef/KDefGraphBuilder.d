module xf.nucleus.kdef.KDefGraphBuilder;

private {
	import xf.Common;
	import xf.nucleus.Param;
	import xf.nucleus.Value;
	import xf.nucleus.Function;
	import xf.nucleus.KernelImpl;
	import xf.nucleus.graph.Graph;
	import xf.nucleus.graph.KernelGraph;
	import xf.nucleus.graph.GraphDef;
	import xf.nucleus.kdef.Common;
	import xf.nucleus.Log : log = nucleusLog;
	import xf.mem.StackBuffer;
}



void buildKernelGraph(
		IGraphDef def_,
		KernelGraph kg,
		GraphNodeId delegate(
			uword			i,
			cstring			nodeName,
			GraphDefNode	nodeDef,
			GraphNodeId delegate() defaultBuilder
		) nodeBuilder = null
) {
	GraphDef def = GraphDef(def_);
	
	scope stack = new StackBuffer;
	final nodeIds = stack.allocArray!(GraphNodeId)(def.nodes.length);
	final nodeDefs = stack.allocArray!(GraphDefNode)(def.nodes.length);
	// TODO: handle sub-graphs

	uword i = 0;
	foreach (nodeName, nodeDef; def.nodes) {
		alias KernelGraph.NodeType NT;

		void createKernelData(NT type, GraphNodeId n) {
			// TODO ^ subgraphs
			assert (KernelImpl.Type.Kernel == nodeDef.kernelImpl.type);
			if (NT.Kernel == type) {
				final nodeData = kg.getNode(n).kernel();
				final kernel = nodeDef.kernelImpl.kernel;
				nodeData.kernel = kernel;
			} else if (NT.Func == type) {
				final nodeData = kg.getNode(n).func();
				final kernel = nodeDef.kernelImpl.kernel;
				nodeData.func = cast(Function)kernel.func;
				nodeData.params = kernel.func.params.dup(&kg._mem.pushBack);
			}
		}

		void createParamData(NT type, GraphNodeId n) {
			final nodeData = kg.getNode(n)._param();
			nodeData.params = nodeDef.params.dup(nodeData.params._allocator);
		}

		auto createData = &createParamData;
		
		NT type; {
			switch (nodeDef.type) {
				case "input":	type = NT.Input; break;
				case "output":	type = NT.Output; break;
				case "data":	type = NT.Data; break;
				case "kernel": {
					createData = &createKernelData;

					// TODO ^ subgraphs
					assert (KernelImpl.Type.Kernel == nodeDef.kernelImpl.type);
					if (nodeDef.kernelImpl.kernel.isConcrete) {
						type = NT.Func;
					} else {
						type = NT.Kernel;
					}
				} break;
				default: assert (false, nodeDef.type);
			}
		}

		nodeDefs[i] = nodeDef;

		GraphNodeId defaultNodeBuilder() {
			final n = kg.addNode(type);

			log.trace(
				"Created a graph node '{}'. Id = {}.",
				nodeName, n.id
			);

			createData(type, n);

			return n;
		}

		if (nodeBuilder !is null) {
			nodeIds[i] = nodeBuilder(
				i,
				nodeName,
				nodeDef,
				&defaultNodeBuilder
			);
		} else {
			nodeIds[i] = defaultNodeBuilder();
		}

		++i;
	}

	GraphNodeId findId(GraphDefNode g) {
		foreach (i, d; nodeDefs) {
			if (d is g) return nodeIds[i];
		}
		assert (false);
	}

	final flow = kg.flow();

	foreach (con; def.nodeConnections) {
		flow.addAutoFlow(findId(con.from), findId(con.to));
	}

	foreach (con; def.nodeFieldConnections) {
		flow.addDataFlow(findId(con.fromNode), con.from, findId(con.toNode), con.to);
	}


	version (DebugGraphConnections) {
		void assertAddedNode(GraphNodeId x) {
			foreach (n; nodeIds) {
				if (n == x) return;
			}
			assert (false);
		}

		foreach (n; nodeIds) {
			foreach (con; flow.iterOutgoingConnections(n)) {
				assertAddedNode(con);
			}
			foreach (con; flow.iterIncomingConnections(n)) {
				assertAddedNode(con);
			}
		}
	}
}
