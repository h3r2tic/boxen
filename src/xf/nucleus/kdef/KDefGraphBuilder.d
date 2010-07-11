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



uword numGraphFlattenedNodes(IGraphDef def_) {
	GraphDef def = GraphDef(def_);
	uword num = def.nodes.length;
	
	foreach (nodeName, nodeDef; def.nodes) {
		alias KernelGraph.NodeType NT;

		if ("kernel" == nodeDef.type) {
			switch (nodeDef.kernelImpl.type) {
				case KernelImpl.Type.Kernel: break;

				case KernelImpl.Type.Graph: {
					num += numGraphFlattenedNodes(nodeDef.kernelImpl.graph);
					--num;
				} break;

				default: assert (false);
			}
		}
	}

	return num;
}


private void buildKernelSubGraph(
		IGraphDef def_,
		KernelGraph kg,
		uword* nodeI,
		GraphNodeId delegate(
			uword			i,
			cstring			nodeName,
			GraphDefNode	nodeDef,
			GraphNodeId delegate() defaultBuilder
		) nodeBuilder,
		bool genBridge,
		GraphNodeId* inputBridgeId,
		GraphNodeId* outputBridgeId,
		GraphNodeId[] nodeIds,
		GraphNodeId[] nodeInputIds,
		GraphNodeId[] nodeOutputIds,
		GraphDefNode[] nodeDefs,
) {
	GraphDef def = GraphDef(def_);
	
	foreach (nodeName, nodeDef; def.nodes) {
		alias KernelGraph.NodeType NT;

		if (nodeDef.type != "kernel" || KernelImpl.Type.Kernel == nodeDef.kernelImpl.type) {
			void createKernelData(NT type, GraphNodeId n) {
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

			void createBridgeData(NT type, GraphNodeId n) {
				final nodeData = kg.getNode(n).bridge();
				nodeData.params = nodeDef.params.dup(nodeData.params._allocator);
				foreach (ref p; nodeData.params) {
					p.dir = ParamDirection.InOut;
				}
			}

			auto createData = &createParamData;

			GraphNodeId* rememberId = null;
			
			NT type; {
				switch (nodeDef.type) {
					case "data": type = NT.Data; break;

					case "input": {
						if (genBridge) {
							rememberId = inputBridgeId;
							createData = &createBridgeData;
							type = NT.Bridge;
						} else {
							type = NT.Input;
						}
					} break;
					
					case "output": {
						if (genBridge) {
							rememberId = outputBridgeId;
							createData = &createBridgeData;
							type = NT.Bridge;
						} else {
							type = NT.Output;
						}
					} break;
					
					case "kernel": {
						createData = &createKernelData;

						if (nodeDef.kernelImpl.kernel.isConcrete) {
							type = NT.Func;
						} else {
							type = NT.Kernel;
						}
					} break;
					default: assert (false, nodeDef.type);
				}
			}

			nodeDefs[*nodeI] = nodeDef;

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
				nodeIds[*nodeI] = nodeBuilder(
					*nodeI,
					nodeName,
					nodeDef,
					&defaultNodeBuilder
				);
			} else {
				nodeIds[*nodeI] = defaultNodeBuilder();
			}

			if (rememberId) {
				*rememberId = nodeIds[*nodeI];
			}

			// The nodes for input and output flow for non-subgraphs are the nodes themselves
			nodeOutputIds[*nodeI] = nodeInputIds[*nodeI] = nodeIds[*nodeI];

			++*nodeI;
		} else {
			assert (
					nodeDef.type == "kernel"
				&&	KernelImpl.Type.Graph == nodeDef.kernelImpl.type
			);

			GraphNodeId bridgeIn, bridgeOut;

			// nodeI will be modified by the recursive call, hence remember it
			// so that the input and output bridge nodes may be associated with
			// the subgraph for data and auto flow at the end of this func.
			uword subgraphDefIdx = *nodeI;

			buildKernelSubGraph(
				nodeDef.kernelImpl.graph,
				kg,
				nodeI,
				nodeBuilder,
				true,
				&bridgeIn,
				&bridgeOut,
				nodeIds,
				nodeInputIds,
				nodeOutputIds,
				nodeDefs
			);

			assert (bridgeIn.valid);
			assert (bridgeOut.valid);

			// Got the input and output bridge nodes for the subgraph now, store
			// these as the idx associated with the GraphNodeDef of the subgraph.
			nodeInputIds[subgraphDefIdx] = bridgeIn;
			nodeOutputIds[subgraphDefIdx] = bridgeOut;
			
			nodeDefs[subgraphDefIdx] = nodeDef;
		}
	}

	GraphNodeId findInputId(GraphDefNode g) {
		foreach (i, d; nodeDefs) {
			if (d is g) return nodeInputIds[i];
		}
		assert (false);
	}

	GraphNodeId findOutputId(GraphDefNode g) {
		foreach (i, d; nodeDefs) {
			if (d is g) return nodeOutputIds[i];
		}
		assert (false);
	}

	final flow = kg.flow();

	foreach (con; def.nodeConnections) {
		flow.addAutoFlow(findOutputId(con.from), findInputId(con.to));
	}

	foreach (con; def.nodeFieldConnections) {
		flow.addDataFlow(findOutputId(con.fromNode), con.from, findInputId(con.toNode), con.to);
	}

	foreach (nf; def.noAutoFlow) {
		auto nodeId = findOutputId(nf.toNode);
		auto node = kg.getNode(nodeId);
		auto param = node.getInputParam(nf.to);
		if (param is null) {
			error(
				"Input param {} for noauto not found in node {}.",
				nf.to, nodeId.id
			);
		} else {
			param.wantAutoFlow = false;
		}
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
	uword nodeI = 0;
	GraphDef def = GraphDef(def_);

	scope stack = new StackBuffer;

	final uword totalNodes = numGraphFlattenedNodes(def);

	final nodeIds = stack.allocArray!(GraphNodeId)(totalNodes);
	final nodeDefs = stack.allocArray!(GraphDefNode)(totalNodes);

	final nodeInputIds = stack.allocArray!(GraphNodeId)(totalNodes);
	final nodeOutputIds = stack.allocArray!(GraphNodeId)(totalNodes);
	
	buildKernelSubGraph(
		def_,
		kg,
		&nodeI,
		nodeBuilder,
		false,
		null,
		null,
		nodeIds,
		nodeInputIds,
		nodeOutputIds,
		nodeDefs
	);

	assert (totalNodes == nodeI);
}
