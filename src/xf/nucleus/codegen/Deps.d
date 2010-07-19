/**
 * Dumping of dependencies
 */
module xf.nucleus.codegen.Deps;

private {
	import
		xf.Common,
		xf.utils.FormatTmp;

	import
		xf.nucleus.Param,
		xf.nucleus.Function,
		xf.nucleus.codegen.Defs,
		xf.nucleus.codegen.Rename,
		xf.nucleus.codegen.Body,
		xf.nucleus.graph.KernelGraph,
		xf.nucleus.graph.KernelGraphOps,
		xf.nucleus.graph.GraphOps;

	import
		xf.mem.StackBuffer,
		xf.mem.SmallTempArray;
}



private struct SubgraphData {
	cstring[]	node2funcName;
	cstring[]	node2compName;
	bool		emitted = false;
}


void emitInterfaces(KernelGraph graph, CodeSink sink, CodegenSetup setup) {
	scope stack = new StackBuffer;
	mixin MSmallTempArray!(cstring) emittedComps;

	/+// HACK
	emittedComps.pushBack("Image", &stack.allocRaw);+/


	void emit(AbstractFunction func, cstring retType) {
		bool ifaceEmitted = false;

		foreach (em; emittedComps.items) {
			if (em == func.name) {
				ifaceEmitted = true;
				break;
			}
		}

		if (!ifaceEmitted) {
			emittedComps.pushBack(func.name, &stack.allocRaw);

			sink("interface ")(func.name)(" {").newline;
			sink('\t');
			bool returnEmitted = false;
			foreach (p; func.params) {
				if (p.isOutput) {
					assert (!returnEmitted);	// uh oh, only one ret allowed for now (TODO?)
					returnEmitted = true;
					sink(retType);
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
	}
	
	void worker(KernelGraph graph) {
		foreach (nid, node; graph.iterNodes) {
			if (setup.getInterface !is null) {
				foreach (par; *node.getParamList()) {
					if (par.hasPlainSemantic && par.hasTypeConstraint) {
						AbstractFunction ifaceFunc;
						if (setup.getInterface(par.type, &ifaceFunc)) {
							emit(ifaceFunc, getIfaceFuncReturnType(ifaceFunc));
						}
					}
				}
			}
			
			if (KernelGraph.NodeType.Composite == node.type) {
				auto compNode = node.composite();
				worker(compNode.graph);
				emit(compNode.targetFunc, compNode.returnType);
			}
		}
	}

	worker(graph);
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
		node2compName = stack.allocArray!(cstring)(graph.capacity);

		foreach (nid, node; graph.iterNodes) {
			if (NT.Composite != node.type) {
				continue;
			}

			auto compNode = node.composite();
			final func = compNode.targetFunc;

			cstring compName;
			formatTmp((Fmt fmt) {
					fmt.format(
						"{}__impl{}_g{}",
						func.name,
						nid.id,
						graphIdx
					);
				},
				(cstring str) {
					compName = stack.dupString(str);
				}
			);

			node2compName[nid.id] = compName;

			// ---- dump the composite ----

			if (!graphs[compNode._graphIdx].emitted) {
				graphs[compNode._graphIdx].emitted = true;
				
				removeUnreachableBackwards(
					compNode.graph.backend_readOnly,
					compNode.outNode
				);
				
				// reserved for the main graph
				assert (compNode._graphIdx != 0);
				
				emitGraphCompositesAndFuncs(
					compNode.graph,
					compNode._graphIdx,
					graphs,
					sink,
					stack
				);

				sink("struct ")(compName)(" : ")(func.name)(" {").newline;

				foreach (p; compNode.graph.getNode(compNode.dataNode).data().params) {
					sink("\t")(p.type)(' ')(p.name)(';').newline;
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

				//File.set("graph.dot", toGraphviz(compNode.graph));

				auto topological = stack.allocArray!(GraphNodeId)(compNode.graph.numNodes);
				findTopologicalOrder(compNode.graph.backend_readOnly, topological);

				final ctx = CodegenContext(
					sink,
					GPUDomain.Unresolved,
					compNode.graph,
					null,
					2
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
					formatTmp((Fmt fmt) {
						fmt.format(
							"{}__overload{}_g{}",
							funcNode.func.name,
							overloadIndex,
							graphIdx
						);
					}, (cstring str) {
						funcName = stack.dupString(str);
					});
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


private cstring getIfaceFuncReturnType(AbstractFunction func) {
	cstring res = null;
	foreach (p; func.params) {
		if (ParamDirection.Out == p.dir) {
			assert (res is null);	// we only support one return param for ifaces
			assert (p.hasPlainSemantic);	// TODO
			assert (p.hasTypeConstraint);
			res = p.type;
		}
	}
	assert (res !is null);
	return res;
}
