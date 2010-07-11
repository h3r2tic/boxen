module xf.nucleus.codegen.Codegen;

private {
	import xf.Common;
	import xf.nucleus.codegen.Defs;
	import xf.nucleus.codegen.Rename;
	import xf.nucleus.Param;
	import xf.nucleus.graph.KernelGraph;
	import xf.nucleus.graph.Graph;
	import xf.nucleus.graph.GraphMisc;
	import xf.nucleus.graph.GraphOps;
	import xf.nucleus.graph.KernelGraphOps;
	import xf.nucleus.graph.Simplify;
	import xf.gfx.Defs : GPUDomain;
	import xf.utils.BitSet;
	import xf.mem.StackBuffer;
	import xf.nucleus.Log : error = nucleusError;

	import Integer = tango.text.convert.Integer;
	import tango.io.stream.Format;
	import tango.text.convert.Format;
	import tango.io.device.File;
}



struct CodegenSetup {
	GraphNodeId	inputNode;
	GraphNodeId	outputNode;
}


private struct SubgraphData {
	cstring[] node2funcName;
	cstring[] node2compName;
}


void codegen(
	KernelGraph graph,
	CodegenSetup setup,
	CodeSink sink
) {
	alias KernelGraph.NodeType NT;

	scope stack = new StackBuffer;
	final graphBack = graph.backend_readOnly;

	GraphNodeId rasterNode;
	GraphNodeId	vinputNodeId = setup.inputNode;
	GraphNodeId	foutputNodeId = setup.outputNode;

	foreach (nid, node; graph.iterNodes) {
		if (
			NT.Kernel == node.type
		&&	"Rasterize" == node.kernel.kernel.func.name
		) {
			rasterNode = nid;
		}

		/+if (NT.Input == node.type) {
			assert (!vinputNodeId.valid, "There can be only one.");
			vinputNodeId = nid;
			assert (vinputNodeId.valid);
		}

		if (NT.Output == node.type) {
			assert (!foutputNodeId.valid, "There can be only one.");
			foutputNodeId = nid;
			assert (foutputNodeId.valid);
		}+/
	}

	assert (vinputNodeId.valid, "No Input node found. That should be resolved earlier");
	assert (foutputNodeId.valid, "No Output node found. That should be resolved earlier");
	

	if (!rasterNode.valid) {
		error("'Rasterize' node not found, can't codegen :(");
	}

	// Remove the unreachable nodes. The backend is readonly, but as we won't
	// be adding nodes to the graph any further, it's safe to remove the backend nodes
	removeUnreachableBackwards(
		graph.backend_readOnly,
		foutputNodeId, rasterNode
	);

	// ---- Simplify the graph by removing redundant Func nodes

	auto topological = stack.allocArray!(GraphNodeId)(graph.numNodes);
	findTopologicalOrder(graphBack, topological);

	simplifyKernelGraph(graph, topological);

	// ---- Find the GPU domains for nodes

	final nodeDomains = stack.allocArray!(GPUDomain)(graph.capacity);
	nodeDomains[] = GPUDomain.Fragment;

	uword numVertexNodes = 0;

	visitPrecedingNodes(graphBack, (GraphNodeId node) {
		nodeDomains[node.id] = GPUDomain.Vertex;
		++numVertexNodes;
	}, rasterNode);
	nodeDomains[rasterNode.id] = GPUDomain.Vertex;

	assert (GPUDomain.Vertex == nodeDomains[vinputNodeId.id]);
	assert (GPUDomain.Fragment == nodeDomains[foutputNodeId.id]);

	// move nodes into the vertex stage, if possible
	
	moveToVertexIter: foreach (nid; topological) {
		if (!nid.valid || GPUDomain.Vertex == nodeDomains[nid.id]) {
			continue;
		}

		assert (GPUDomain.Fragment == nodeDomains[nid.id]);

		final node = graph.getNode(nid);
		if (NT.Func == node.type || NT.Bridge == node.type) {
			foreach (pred; graphBack.iterIncomingConnections(nid)) {
				if (GPUDomain.Vertex != nodeDomains[pred.id]) {
					continue moveToVertexIter;
				}
			}

			if (NT.Bridge == node.type || node.func.func.hasTag("linear")) {
				nodeDomains[nid.id] = GPUDomain.Vertex;
			}
			// TODO: anything /else/ ?
		}
	}

	File.set("graph.dot", toGraphviz(graph, (GraphNodeId nid) {
		switch (nodeDomains[nid.id]) {
			case GPUDomain.Vertex: return " : vert"[];
			case GPUDomain.Fragment: return " : frag"[];
			default: assert (false);
		}
	}));

	// ----

	auto vinputNodeParams = graph.getNode(vinputNodeId).getParamList();
	auto foutputNodeParams = graph.getNode(foutputNodeId).getParamList();

	final vinputNT = graph.getNode(vinputNodeId).type;
	final foutputNT = graph.getNode(foutputNodeId).type;

	// note that there will be just one Input and one Output node,
	// all the other should have been used for connecting kernels

	// final uword numFragmentNodes = graph.numNodes - numVertexNodes;

	/*
	 * Must find all inputs and outputs of a domain
	 * - they will be the params to vertex/fragment/geometry shader funcs
	 *
	 * The bridge params must have special names
	 * - e.g. an input of the vertex stage may need to be bridged into the
	 *   fragment stage, yet we don't want to rename the vertex input, as
	 *   asset data must bind to it.
	 *
	 *
	 * ... not doing any tesselation in geometry shaders yet
	 * can just enforce direct flow between levels
	 *
	 * have a struct for cg params
	 * - owner node
	 * - param name
	 * - binding semantic
	 *
	 * when generating param flow, if the param comes from a previous
	 * domain level or it doesn't belong to an Input or Data node,
	 * use the n{nodeId}__ prefix for its name, otherwise prefix with
	 * the kernel prefix (structure__, pigment__, illumination__ or light{id}__)
	 *
	 * The func that generates code for each stage will take two lists of
	 * these cg param structs - one for inputs, one for outputs.
	 *
	 * At the end of a generated function, assign all the output params
	 * of the bridge. The output params must have special names that don't
	 * conflict with the regular data flow temporaries. Could be just
	 * bridge__{index of the output param}.
	 *
	 * In case of input param generation, just use the n{nodeId}__ names.
	 * This way, the body of the codegen function doesn't need to care
	 * about level differences.
	 *
	 * The array of outputs of one domain level can be shared with
	 * the inputs to the next domain level, hence making it trivial to match
	 * binding semantics and also reducing memory use.
	 *
	 * Note: don't bother trying to bridge Data nodes. They're effect-scope
	 * uniforms anyway.
	 *
	 * With this setup, uniform inputs into the shader will have kernel type
	 * prefixes, whereas the varying structure kernel inputs will additionally
	 * have the 'VertexProgram' scope.
	*/

	void _iterVOutputParams(void delegate(GraphNodeId, Param*) sink) {
		foreach (nid, node; graph.iterNodes) {
			if (nodeDomains[nid.id] != GPUDomain.Vertex) {
				continue;
			}

			foreach (con; graph.flow.iterOutgoingConnections(nid)) {
				if (nodeDomains[con.id] != GPUDomain.Fragment) {
					continue;
				}

				foreach (fl; graph.flow.iterDataFlow(nid, con)) {
					auto param = node.getOutputParam(fl.from);
					sink(nid, param);
				}
			}
		}
	}


	/*
	 * The inputs to consider are either the /output/ params of an Input node
	 * or the /input/ params if anothes node type is passed as the vertex input.
	 */

	uword numVinputs = 0;
	foreach (ref p; *vinputNodeParams) {
		if (NT.Input == vinputNT || p.isInput) {
			++numVinputs;
		}
	}


	CgParam[] vinputs = stack.allocArray!(CgParam)(numVinputs);
	numVinputs = 0;
	foreach (ref p; *vinputNodeParams) {
		if (NT.Input == vinputNT || p.isInput) {
			vinputs[numVinputs++] = CgParam(
				vinputNodeId,
				&p
			);
		}
	}

	
	CgParam[] voutputs; {
		// one extra for the POSITION
		uword numVOutputParams = 1;

		// Count them all, with possible repetitions
		_iterVOutputParams((GraphNodeId, Param*) {
			++numVOutputParams;
		});

		voutputs = stack.allocArray!(CgParam)(numVOutputParams);

		// Now count and gather just the unique ones

		numVOutputParams = 0;

		findPosParam: foreach (from; graph.flow.iterIncomingConnections(rasterNode)) {
			foreach (fl; graph.flow.iterDataFlow(from, rasterNode)) {
				assert (0 == numVOutputParams);
				
				voutputs[0] = CgParam(
					from,
					graph.getNode(from).getOutputParam(fl.from),
					BindingSemantic("POSITION")
				);
				
				numVOutputParams = 1;
				break findPosParam;
			}
		}

		assert (1 == numVOutputParams);
		
		_iterVOutputParams((GraphNodeId nid, Param* param) {
			foreach (ref cgp; voutputs[0..numVOutputParams]) {
				if (cgp.param is param) {
					return;
				}
			}

			voutputs[numVOutputParams++] = CgParam(
				nid,
				param
			);
		});

		// Shrink the array to contain just the unique params
		voutputs = voutputs[0..numVOutputParams];
	}

	graph.removeNode(rasterNode);

	// Need to recalc it after the simplification and removal of the Rasterize node
	topological = topological[0..graph.numNodes];
	findTopologicalOrder(graphBack, topological);

	alias voutputs finputs;


	/*
	 * The outputs to consider are either the /input/ params of an Output node
	 * or the /output/ params if anothes node type is passed as the fragment output.
	 */

	uword numFoutputs = 0;
	foreach (i, ref p; *foutputNodeParams) {
		if (NT.Output == foutputNT || p.isOutput) {
			++numFoutputs;
		}
	}
	
	CgParam[] foutputs = stack.allocArray!(CgParam)(numFoutputs);
	numFoutputs = 0;
	foreach (ref p; *foutputNodeParams) {
		if (NT.Output == foutputNT || p.isOutput) {
			GraphNodeId	srcNid;
			Param*		srcParam;

			if (!getOutputParamIndirect(
				graph,
				foutputNodeId,
				p.name,
				&srcNid,
				&srcParam
			)) {
				error(
					"No flow to {}.{}. Should have been caught earlier.",
					foutputNodeId.id,
					p.name
				);
			}

			foutputs[numFoutputs++] = CgParam(
				srcNid,
				srcParam
			);
		}
	}

	// ---- figure out the binding semantics ----

	// HACK: Will need to handle DEPTH semantics too.
	foreach (i, ref p; foutputs) {
		p.bindingSemantic.name = "COLOR";
		p.bindingSemantic.index = i;
	}

	void assignTexcoords(CgParam[] pars) {
		uword next = 0;
		foreach (ref p; pars) {
			if (p.bindingSemantic.name is null) {
				p.bindingSemantic.name = "TEXCOORD";
				p.bindingSemantic.index = next++;
			}
		}
	}

	assignTexcoords(vinputs);
	assignTexcoords(voutputs);

	// ---- dump all uniforms ----

	foreach (nid, node; graph.iterNodes) {
		if (NT.Data == node.type) {
			foreach (param; node.data.params) {
				assert (param.hasTypeConstraint);

				sink("uniform ");
				sink(param.type);
				sink(" ");
				
				emitSourceParamName(
					CodegenContext(
						sink,
						GPUDomain.Unresolved,
						graph,
						nodeDomains
					),
					nid,
					param.name
				);

				sink(";").newline;
			}
		}
	}

	word numGraphs = 1;
	void findNumGraphs(KernelGraph graph) {
		foreach (nid, node; graph.iterNodes) {
			if (NT.Composite == node.type) {
				auto compNode = node.composite();
				assert (compNode.graph !is null);
				compNode._graphIdx = numGraphs++;
				findNumGraphs(compNode.graph);
			}
		}
	}
	findNumGraphs(graph);

	final graphs = stack.allocArray!(SubgraphData)(numGraphs);
	emitGraphCompositesAndFuncs(
		graph,
		0,
		graphs,
		sink,
		stack
	);
	
	// ---- codegen the vertex shader ----

	domainCodegen(
		CodegenContext(
			sink,
			GPUDomain.Vertex,
			graph,
			nodeDomains
		),
		"VertexProgram",
		vinputs,
		voutputs,
		(void delegate(GraphNodeId) sink) {
			foreach (nid; topological) {
				if (GPUDomain.Vertex == nodeDomains[nid.id]) {
					sink(nid);
				}
			}
		},
		graphs[0].node2funcName,
		graphs[0].node2compName
	);

	// ---- codegen the fragment shader ----

	domainCodegen(
		CodegenContext(
			sink,
			GPUDomain.Fragment,
			graph,
			nodeDomains
		),
		"FragmentProgram",
		finputs[1..$],	// without the POSITION param
		foutputs,
		(void delegate(GraphNodeId) sink) {
			foreach (nid; topological) {
				if (GPUDomain.Fragment == nodeDomains[nid.id]) {
					sink(nid);
				}
			}
		},
		graphs[0].node2funcName,
		graphs[0].node2compName
	);
}



void emitGraphCompositesAndFuncs(
	KernelGraph graph,
	uint graphIdx,
	SubgraphData[] graphs,
	CodeSink sink,
	StackBufferUnsafe stack
) {
	alias KernelGraph.NodeType NT;

	// ---- dump all composites ----

	cstring[] node2compName; {
		auto _emittedComps = stack.allocArray!(GraphNodeId)(
			graph.numNodes
		);
		uword numEmittedComps = 0;
		
		GraphNodeId[] emittedComps() {
			return _emittedComps[0..numEmittedComps];
		}
		
		node2compName = stack.allocArray!(cstring)(graph.capacity);

		foreach (nid, node; graph.iterNodes) {
			if (NT.Composite != node.type) {
				continue;
			}

			auto compNode = node.composite();

			bool ifaceEmitted = false;

			foreach (emid; emittedComps) {
				auto c = graph.getNode(emid).composite();
								
				if (c.targetFunc.name == compNode.targetFunc.name) {
					ifaceEmitted = true;
					break;
				}
			}

			final func = compNode.targetFunc;

			if (!ifaceEmitted) {
				_emittedComps[numEmittedComps++] = nid;
				sink("interface ")(func.name)(" {").newline;
				sink('\t');
				bool returnEmitted = false;
				foreach (p; func.params) {
					if (p.isOutput) {
						assert (!returnEmitted);	// uh oh, only one ret allowed for now (TODO?)
						returnEmitted = true;
						sink(compNode.returnType);
						sink(' ');
						sink(p.name);
					}
				}
				sink('(').newline;
				{
					word i = 0;
					foreach (p; func.params) {
						if (p.isInput) {
							if (i > 0) {
								sink(',').newline();
							}

							sink("\t\t")(p.type)(' ')(p.name);
							++i;
						}
					}
				}
				sink.newline()("\t);").newline;
				sink("};").newline;
			}

			cstring compName; {
				char[128] buf;
				compName = Format.sprint(
					buf,
					"{}__impl{}_g{}",
					func.name,
					nid.id,
					graphIdx
				);
				
				compName =
					stack.allocArrayNoInit!(char)(compName.length)[] = compName;
			}

			node2compName[nid.id] = compName;

			// ---- dump the composite ----

			{
				emitGraphCompositesAndFuncs(
					compNode.graph,
					compNode._graphIdx,
					graphs,
					sink,
					stack
				);

				sink("struct ")(compName)(" : ")(func.name)(" {").newline;

				foreach (p; compNode.graph.getNode(compNode.dataNode).data().params) {
					sink("\t\t")(p.type)(' ')(p.name)(';').newline;
				}

				sink('\t');
				bool returnEmitted = false;
				foreach (p; func.params) {
					if (p.isOutput) {
						assert (!returnEmitted);	// uh oh, only one ret allowed for now (TODO?)
						returnEmitted = true;
						sink(compNode.returnType);
						sink(' ');
						sink(p.name);
					}
				}
				sink('(').newline;
				{
					word i = 0;
					foreach (p; func.params) {
						if (p.isInput) {
							if (i > 0) {
								sink(',').newline();
							}

							sink("\t\t")(p.type)(' ')(p.name);
							++i;
						}
					}
				}
				sink.newline()("\t) {").newline;

				// codegen the body

				File.set("graph.dot", toGraphviz(compNode.graph));

				auto topological = stack.allocArray!(GraphNodeId)(compNode.graph.numNodes);
				findTopologicalOrder(compNode.graph.backend_readOnly, topological);

				final ctx = CodegenContext(
					sink,
					GPUDomain.Unresolved,
					compNode.graph,
					null
				);

				domainCodegenBody(
					ctx,
					(void delegate(GraphNodeId) sink) {
						foreach (nid; topological) {
							sink(nid);
						}
					},
					graphs[compNode._graphIdx].node2funcName,
					graphs[compNode._graphIdx].node2compName
				);
				
				{
					cstring retName;
					foreach (p; func.params) {
						if (p.isOutput) {
							assert (retName is null);	// uh oh, only one ret allowed for now (TODO?)
							retName = p.name;
						}
					}

					sink.newline()("\t\treturn ");

					GraphNodeId	srcNid;
					Param*		srcParam;

					if (!findSrcParam(
						compNode.graph,
						compNode.outNode,
						retName,
						&srcNid,
						&srcParam
					)) {
						error(
							"No flow to {}.{}. Should have been caught earlier.",
							compNode.outNode,
							retName
						);
					}

					emitSourceParamName(ctx, srcNid, srcParam.name);

					sink(';').newline();
				}

				sink("\t}").newline();
				sink("};").newline;
			}
		}
	}


	// ---- dump all funcs ----

	cstring[] node2funcName; {
		auto _emittedFuncs = stack.allocArray!(GraphNodeId)(
			graph.numNodes
		);
		uword numEmittedFuncs = 0;
		
		GraphNodeId[] emittedFuncs() {
			return _emittedFuncs[0..numEmittedFuncs];
		}
		
		node2funcName = stack.allocArray!(cstring)(graph.capacity);

		funcDumpIter: foreach (nid, node; graph.iterNodes) {
			if (NT.Func != node.type) {
				continue;
			}

			auto	funcNode = node.func();
			uword	overloadIndex = 0;

			overloadSearch: foreach (emid; emittedFuncs) {
				auto f = graph.getNode(emid).func();
				
				if (f.func.name == funcNode.func.name) {
					if (f.params.length != funcNode.func.params.length) {
						++overloadIndex;
						continue overloadSearch;
					}
					
					foreach (i, p1; f.params) {
						assert (p1.hasTypeConstraint);
						auto p2 = funcNode.params[i];
						assert (p2.hasTypeConstraint);

						if (p1.type() != p2.type()) {
							++overloadIndex;
							continue overloadSearch;
						}
					}

					// no param types differ, use this overload
					node2funcName[nid.id] = node2funcName[emid.id];
					continue funcDumpIter;
				}
			}

			_emittedFuncs[numEmittedFuncs++] = nid;

			cstring funcName; {
				if (0 == overloadIndex && 0 == graphIdx) {
					funcName = funcNode.func.name;
				} else {
					char[128] buf;
					funcName = Format.sprint(
						buf,
						"{}__overload{}_g{}",
						funcNode.func.name,
						overloadIndex,
						graphIdx
					);
					
					funcName =
						stack.allocArrayNoInit!(char)(funcName.length)[] = funcName;
				}
			}

			node2funcName[nid.id] = funcName;

			// ---- dump the func ----

			sink.formatln("void {} (", funcName);
			
			foreach (i, par; funcNode.params) {
				sink("\t");
				sink(.toString(par.dir));
				sink(" ");
				sink(par.type);
				sink(" ");
				sink(par.name);
				
				if (i+1 != funcNode.params.length) {
					sink(",");
				}
				
				sink.newline();
			}
			
			sink(") {").newline();
			funcNode.func.code.writeOut((char[] text) {
				sink(text);
			});
			sink.newline();
			sink("}").newline();
		}
	}

	graphs[graphIdx].node2funcName = node2funcName;
	graphs[graphIdx].node2compName = node2compName;
}



void domainCodegen(
	CodegenContext ctx,
	cstring domainFuncName,
	CgParam[] inputs,
	CgParam[] outputs,
	void delegate(void delegate(GraphNodeId)) nodesTopo,
	cstring[] node2funcName,
	cstring[] node2compName
) {
	auto sink = ctx.sink;
	
	/*
	 * void domainFuncName(
	 *   each input param passed through sourceParamName()
	 *   each output param with a bridge__{i} name
	 * ) {
	 *     type n{i}__outParam1;
	 *     type n{i}__outParam2;
	 *     n{i}Func(inpar1, inpar2, inpar3, n{i}__outParam1, n{i}__outParam2);
	 *
	 *     ...
	 * 
	 *     bridge__{i} = sourceParamName(outputs[i]);
	 * }
	 */

	sink.formatln("void {} (", domainFuncName);
	
	foreach (i, par; inputs) {
		assert (par.param.hasTypeConstraint);

		sink("\tin ");
		sink(par.param.type);
		sink(" ");
		emitSourceParamName(ctx, par.node, par.param.name);
		sink(" : ");
		par.bindingSemantic.writeOut(sink);
		
		if (i+1 != inputs.length+outputs.length) {
			sink(",");
		}
		
		sink.newline();
	}
	
	foreach (i, par; outputs) {
		assert (par.param.hasTypeConstraint);

		sink("\tout ");
		sink(par.param.type);
		sink(" ");
		sink.format("bridge__{}", i);
		sink(" : ");
		par.bindingSemantic.writeOut(sink);
		
		if (i+1 != outputs.length) {
			sink(",");
		}
		
		sink.newline();
	}

	sink(") {").newline();

	domainCodegenBody(ctx, nodesTopo, node2funcName, node2compName);

	foreach (i, par; outputs) {
		sink.format("\tbridge__{} = ", i);

/+
		GraphNodeId	srcNid;
		Param*		srcParam;

		if (!findSrcParam(
			ctx.graph,
			par.node,
			par.param.name,
			&srcNid,
			&srcParam
		)) {
			error(
				"No flow to {}.{}. Should have been caught earlier.",
				par.node.id,
				par.param.name
			);
		}

		emitSourceParamName(ctx, srcNid, srcParam.name);
+/

		emitSourceParamName(ctx, par.node, par.param.name);
		sink(';').newline();
	}

	sink("}").newline();
}



void domainCodegenBody(
	CodegenContext ctx,
	void delegate(void delegate(GraphNodeId)) nodesTopo,
	cstring[] node2funcName,
	cstring[] node2compName
) {
	alias KernelGraph.NodeType NT;


	auto sink = ctx.sink;

	nodesTopo((GraphNodeId nid) {
		auto node = ctx.graph.getNode(nid);

		// TODO: remove Bridge nodes and redirect their flow after auto conversion
		// have been carried out, so that this step doen't have to be done
		if (NT.Bridge == node.type) {
			auto params = &node.bridge().params;
			
			foreach (par; *params) {
				assert (par.hasTypeConstraint);
				sink('\t');
				sink(par.type)(' ');
				emitSourceParamName(ctx, nid, par.name);
				sink(" = ");

				GraphNodeId	srcNid;
				Param*		srcParam;

				if (!findSrcParam(
					ctx.graph,
					nid,
					par.name,
					&srcNid,
					&srcParam
				)) {
					error(
						"No flow to {}.{}. Should have been caught earlier.",
						nid.id,
						par.name
					);
				}

				emitSourceParamName(ctx, srcNid, srcParam.name);

				sink(';').newline();
			}
		} else if (NT.Composite == node.type) {
			auto compName = node2compName[nid.id];
			assert (compName !is null);

			sink('\t')(compName)(' ');
			const compOutputName = "kernel";	// TODO: move the name to a common place
			emitSourceParamName(ctx, nid, compOutputName);
			sink(';').newline();

			auto params = &node.composite().params;
			
			foreach (i, par; *params) {
				if (par.isInput) {
					sink('\t');

					emitSourceParamName(ctx, nid, compOutputName);
					sink('.');
					sink(par.name)(" = ");

					GraphNodeId	srcNid;
					Param*		srcParam;

					if (!findSrcParam(
						ctx.graph,
						nid,
						par.name,
						&srcNid,
						&srcParam
					)) {
						error(
							"No flow to {}.{}. Should have been caught earlier.",
							nid.id,
							par.name
						);
					}

					emitSourceParamName(ctx, srcNid, srcParam.name);

					sink(';').newline();
				}
			}
		} else if (NT.Func == node.type) {
			auto params = &node.func().params;
			
			foreach (par; *params) {
				assert (par.hasTypeConstraint);
				
				if (par.isOutput) {
					sink('\t');
					sink(par.type)(' ');
					emitSourceParamName(ctx, nid, par.name);
					sink(';').newline();
				}
			}

			auto funcName = node2funcName[nid.id];
			assert (funcName !is null);
			
			sink('\t')(funcName)('(').newline;
			foreach (i, par; *params) {
				sink('\t');
				sink('\t');

				if (par.isInput) {
					GraphNodeId	srcNid;
					Param*		srcParam;

					if (!findSrcParam(
						ctx.graph,
						nid,
						par.name,
						&srcNid,
						&srcParam
					)) {
						error(
							"No flow to {}.{}. Should have been caught earlier.",
							nid.id,
							par.name
						);
					}

					emitSourceParamName(ctx, srcNid, srcParam.name);
				} else {
					emitSourceParamName(ctx, nid, par.name);
				}
				
				if (i+1 != params.length) {
					sink(',');
				}
				sink.newline();
			}
			sink("\t);").newline;
		}
	});
}


struct BindingSemantic {
	cstring	name;
	uint	index;

	void writeOut(CodeSink sink) {
		sink(name)(index);
	}
}

struct CgParam {
	GraphNodeId		node;
	Param*			param;
	BindingSemantic	bindingSemantic;
}
