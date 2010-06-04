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
		KernelGraph kg
) {
	scope stack = new StackBuffer;
	final nodeIds = stack.allocArray!(GraphNodeId)(def.nodes.length);
	final nodeDefs = stack.allocArray!(GraphDefNode)(def.nodes.length);
	// TODO: handle sub-graphs

	uword i = 0;
	foreach (nodeName, nodeDef; def.nodes) {
		alias KernelGraph.NodeType NT;

		void createKernelData(NT type, GraphNodeId n) {
			cstring kname = (cast(StringValue)nodeDef.vars["kernelName"]).value;
			cstring fname = (cast(StringValue)nodeDef.vars["funcName"]).value;

			final nodeData = kg.getNode(n).kernel();
			
			nodeData.kernelName = kg.allocString(kname);
			nodeData.funcName = kg.allocString(fname);
		}

		void createParamData(NT type, GraphNodeId n) {
			final nodeData = kg.getNode(n)._param();
			
			if (auto params_ = "params" in nodeDef.vars) {
				if (auto params = cast(ParamListValue)*params_) {
					foreach (d; params.value) {
						auto p = nodeData.params.add(
							(	NT.Output == type
							?	ParamDirection.In	// output nodes contain flow _inputs_
							:	ParamDirection.Out
							),
							d.name
						);

						p.hasPlainSemantic = true;
						final psem = p.semantic();

						if (d.type.length > 0) {
							p.type = d.type;
						}

						void buildSemantic(ParamSemanticExp sem) {
							if (sem is null) {
								return;
							}
							
							if (sem) {
								if (ParamSemanticExp.Type.Sum == sem.type) {
									buildSemantic(sem.exp1);
									buildSemantic(sem.exp2);
								} else if (ParamSemanticExp.Type.Trait == sem.type) {
									psem.addTrait(sem.name, sem.value);
									// TODO: check the type?
								} else {
									// TODO: err
									assert (false, "Subtractive trait used in a graph param.");
								}
							}
						}
						
						buildSemantic(d.paramSemantic);
					}
				} else {
					throw new Exception("The 'params' variable in a node must be a ParamListValue, not a " ~ (*params_).classinfo.name);
				}
			} else {
				throw new Exception("OH SHI-, didn't find any params in the '"~nodeName~"' node");
			}
		}

		auto createData = &createParamData;
		
		NT type; {
			auto typeVar = nodeDef.vars["type"];
			assert (cast(StringValue)typeVar);
			switch ((cast(StringValue)typeVar).value) {
				case "input":	type = NT.Input; break;
				case "output":	type = NT.Output; break;
				case "data":	type = NT.Data; break;
				case "kernel":	type = NT.Kernel; createData = &createKernelData; break;
				default: assert (false, (cast(StringValue)typeVar).value);
			}
		}

		final n = nodeIds[i] = kg.addNode(type);
		nodeDefs[i] = nodeDef;
		++i;

		log.trace(
			"Created a graph node '{}'. Id = {}.",
			nodeName, n.id
		);

		createData(type, n);
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
}
