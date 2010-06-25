module xf.nucleus.kdef.KDefGraphBuilder;

private {
	import xf.Common;
	import xf.nucleus.Param;
	import xf.nucleus.Value;
	import xf.nucleus.graph.Graph;
	import xf.nucleus.graph.KernelGraph;
	import xf.nucleus.kdef.Common;
	import xf.nucleus.Log : log = nucleusLog;
	import xf.mem.StackBuffer;
}



void buildKernelGraph(
		GraphDef def,
		KernelGraph kg,
		GraphNodeId delegate(
			uword			i,
			cstring			nodeName,
			GraphDefNode	nodeDef,
			GraphNodeId delegate() defaultBuilder
		) nodeBuilder = null
) {
	scope stack = new StackBuffer;
	final nodeIds = stack.allocArray!(GraphNodeId)(def.nodes.length);
	final nodeDefs = stack.allocArray!(GraphDefNode)(def.nodes.length);
	// TODO: handle sub-graphs

	uword i = 0;
	foreach (nodeName, nodeDef; def.nodes) {
		alias KernelGraph.NodeType NT;

		void createKernelData(NT type, GraphNodeId n) {
			cstring kname = (cast(IdentifierValue)nodeDef.vars["kernel"]).value;

			final nodeData = kg.getNode(n).kernel();
			
			nodeData.name = kg.allocString(kname);
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
				case "kernel":	type = NT.Kernel; createData = &createKernelData; break;
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
