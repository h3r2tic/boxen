module xf.nucleus.codegen.Codegen;

private {
	import xf.Common;
	import xf.nucleus.Param;
	import xf.nucleus.graph.KernelGraph;
	import xf.nucleus.graph.Graph;
	import xf.nucleus.graph.GraphOps;
	import xf.gfx.Defs : GPUDomain;
	import xf.utils.BitSet;
	import xf.mem.StackBuffer;
	import xf.nucleus.Log : error = nucleusError;

	import Integer = tango.text.convert.Integer;
	import tango.io.stream.Format;
	import tango.text.convert.Format;
}



alias FormatOutput!(char) CodeSink;


void codegen(
	KernelGraph graph,
	CodeSink sink
) {
	scope stack = new StackBuffer;
	final graphBack = graph.backend_readOnly;

	GraphNodeId rasterNode;
	GraphNodeId	vinputNodeId;
	GraphNodeId	foutputNodeId;

	foreach (nid, node; graph.iterNodes) {
		if (
			KernelGraph.NodeType.Kernel == node.type
		&&	"Rasterize" == cast(cstring)node.kernel.kernelName
		) {
			rasterNode = nid;
		}

		if (KernelGraph.NodeType.Input == node.type) {
			assert (!vinputNodeId.valid, "There can be only one.");
			vinputNodeId = nid;
			assert (vinputNodeId.valid);
		}

		if (KernelGraph.NodeType.Output == node.type) {
			assert (!foutputNodeId.valid, "There can be only one.");
			foutputNodeId = nid;
			assert (foutputNodeId.valid);
		}
	}

	assert (vinputNodeId.valid, "No Input node found. That should be resolved earlier");
	assert (foutputNodeId.valid, "No Output node found. That should be resolved earlier");
	

	if (!rasterNode.valid) {
		error("'Rasterize' node not found, can't codegen :(");
	}

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

	auto vinputNode = graph.getNode(vinputNodeId).input();
	auto foutputNode = graph.getNode(foutputNodeId).output();

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
	 * the kernel prefix (structure__, surface__, or light{id}__)
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


	CgParam[] vinputs = stack.allocArray!(CgParam)(vinputNode.params.length);
	foreach (i, ref p; vinputNode.params) {
		vinputs[i] = CgParam(
			vinputNodeId,
			&p
		);
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

	// TODO: anything special about the POSITION semantic here?
	alias voutputs finputs;
	
	CgParam[] foutputs = stack.allocArray!(CgParam)(foutputNode.params.length);
	foreach (i, ref p; foutputNode.params) {
		foutputs[i] = CgParam(
			foutputNodeId,
			&p
		);
	}

	// HACK: Will need to handle DEPTH semantics too.
	foreach (i, ref p; foutputs) {
		p.bindingSemantic.name = "COLOR";
		p.bindingSemantic.index = i;
	}

	// ---- dump all quark funcs ----

	auto _emittedFuncs = stack.allocArray!(GraphNodeId)(
		graph.numNodes
	);
	uword numEmittedFuncs = 0;
	
	GraphNodeId[] emittedFuncs() {
		return _emittedFuncs[0..numEmittedFuncs];
	}
	
	auto node2funcName = stack.allocArray!(cstring)(graph.capacity);

	funcDumpIter: foreach (nid, node; graph.iterNodes) {
		if (KernelGraph.NodeType.Func != node.type) {
			continue;
		}

		auto	funcNode = node.func();
		uword	overloadIndex = 0;

		overloadSearch: foreach (emid; emittedFuncs) {
			auto f = graph.getNode(emid).func();
			
			if (f.func is funcNode.func) {
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

		cstring funcName; {
			if (0 == overloadIndex) {
				funcName = funcNode.func.name;
			} else {
				char[128] buf;
				funcName = Format.sprint(
					buf,
					"{}__overload{}",
					funcNode.func.name,
					overloadIndex
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
		sink("}").newline();
	}
	
	// ---- dump all uniforms ----

	foreach (nid, node; graph.iterNodes) {
		if (KernelGraph.NodeType.Data == node.type) {
			foreach (param; node.data.params) {
				assert (param.hasTypeConstraint);

				sink("uniform ");
				sink(param.type);
				
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
	
	// ----

	final topological = stack.allocArray!(GraphNodeId)(graph.numNodes);
	findTopologicalOrder(graphBack, topological);

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
		node2funcName
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
		finputs,
		foutputs,
		(void delegate(GraphNodeId) sink) {
			foreach (nid; topological) {
				if (GPUDomain.Fragment == nodeDomains[nid.id]) {
					sink(nid);
				}
			}
		},
		node2funcName
	);
}



struct CodegenContext {
	CodeSink	sink;
	GPUDomain	domain;
	KernelGraph	graph;
	GPUDomain[]	nodeDomains;
}



void emitSourceParamName(
	CodegenContext ctx,
	GraphNodeId nid,
	cstring pname
) {
	final node = ctx.graph.getNode(nid);
	
	if (
		KernelGraph.NodeType.Data == node.type
		|| (
			KernelGraph.NodeType.Input == node.type
		&&	ctx.nodeDomains[nid.id] == ctx.domain
		)
	) {
		final pnode = node._param();
		switch (pnode.sourceKernelType) {
			case SourceKernelType.Undefined: {
				error("Param (Input/Data) node without a source kernel type :(");
			} break;

			case SourceKernelType.Structure: {
				ctx.sink("structure__");
			} break;

			case SourceKernelType.Surface: {
				ctx.sink("surface__");
			} break;

			case SourceKernelType.Light: {
				ctx.sink("light")(pnode.sourceLightIndex)("__");
			} break;

			default: assert (false);
		}
	} else {
		ctx.sink('n')(nid.id)("__");
	}

	ctx.sink(pname);
}


void domainCodegen(
	CodegenContext ctx,
	cstring domainFuncName,
	CgParam[] inputs,
	CgParam[] outputs,
	void delegate(void delegate(GraphNodeId)) nodesTopo,
	cstring[] node2funcName
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
		sink.formatln("bridge__{}", i);
		sink(" : ");
		par.bindingSemantic.writeOut(sink);
		
		if (i+1 != outputs.length) {
			sink(",");
		}
		
		sink.newline();
	}

	sink(") {").newline();

	domainCodegenBody(ctx, nodesTopo, node2funcName);

	foreach (i, par; outputs) {
		sink.format("bridge__{} = ", i);
		emitSourceParamName(ctx, par.node, par.param.name);
		sink(';').newline();
	}

	sink("}").newline();
}


void domainCodegenBody(
	CodegenContext ctx,
	void delegate(void delegate(GraphNodeId)) nodesTopo,
	cstring[] node2funcName
) {
	auto sink = ctx.sink;

	nodesTopo((GraphNodeId nid) {
		auto node = ctx.graph.getNode(nid);
		if (KernelGraph.NodeType.Func != node.type) {
			return;
		}

		auto funcNode = node.func();
		
		foreach (par; funcNode.params) {
			assert (par.hasTypeConstraint);
			
			if (!par.isInput) {
				sink(par.type)(' ');
				emitSourceParamName(ctx, nid, par.name);
				sink(';').newline();
			}
		}

		auto funcName = node2funcName[nid.id];
		assert (funcName !is null);
		
		sink(funcName)('(').newline;
		foreach (i, par; funcNode.params) {
			emitSourceParamName(ctx, nid, par.name);
			if (i+1 != funcNode.params.length) {
				sink(',').newline();
			}
		}
		sink(");").newline;
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
