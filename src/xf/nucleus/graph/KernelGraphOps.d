module xf.nucleus.graph.KernelGraphOps;

private {
	import xf.Common;
	import xf.nucleus.Function;
	import xf.nucleus.KernelImpl;
	import xf.nucleus.kernel.KernelDef;
	import xf.nucleus.graph.KernelGraph;

	// for the conversion
	import xf.nucleus.Param;
	import xf.nucleus.TypeSystem;
	import xf.nucleus.graph.Graph;
	import xf.nucleus.graph.GraphOps;
	import xf.nucleus.TypeConversion;
	import xf.mem.StackBuffer;
	import xf.mem.SmallTempArray;
	import xf.utils.LocalArray;
	import xf.utils.FormatTmp;
	import tango.text.convert.Format;
	// ----

	import xf.nucleus.Log : error = nucleusError, log = nucleusLog;
}



struct ConvCtx {
	SemanticConverterIter
			semanticConverters;
			
	bool delegate(cstring, KernelImpl*)
			getKernel;
}


/**
 * Whether to insert converters between regular graph nodes and an Output.
 * It's useful not to perform the conversion when fusing graphs together, so
 * that a conversion forth and back may be avoided without an opitimization step.
 * In such a case, Skip would be selected.
 *
 * Conversely, the data must be fully converted for nodes that escape the graph,
 * that is, Output (or Rasterize) nodes. In this case, go with Perform
 */
enum OutputNodeConversion {
	Perform,
	Skip
}


/**
 * Finds the output parameter which is connected to a given /input/
 * parameter in the graph. Essentially - the source of data flow
 */
bool findSrcParam(
	KernelGraph kg,
	GraphNodeId dstNid,
	cstring dstParam,
	GraphNodeId* srcNid,
	Param** srcParam
) {
	foreach (src; kg.flow.iterIncomingConnections(dstNid)) {
		foreach (fl; kg.flow.iterDataFlow(src, dstNid)) {
			if (fl.to == dstParam) {
				*srcNid = src;
				*srcParam = kg.getNode(src).getOutputParam(fl.from);
				return true;
			}
		}
	}

	return false;
}


/**
 * Acquires an output parameter from the node if it's a regular one,
 * or tracks it in the graph and returns the connected one if it's an
 * Output node.
 *
 * Use it to obtain an output param of a node to which you may want to
 * connect something. Or basically to get the 'real' output when
 * Output nodes are involved
 */
bool getOutputParamIndirect(
	KernelGraph kg,
	GraphNodeId dstNid,
	cstring dstParam,
	GraphNodeId* srcNid,
	Param** srcParam
) {
	final node = kg.getNode(dstNid);
	
	if (KernelGraph.NodeType.Output == node.type) {
		return findSrcParam(kg, dstNid, dstParam, srcNid, srcParam);
	} else {
		if ((*srcParam = node.getOutputParam(dstParam)) !is null) {
			*srcNid = dstNid;
			return true;
		} else {
			return false;
		}
	}
}


/**
 * Connect two disjoint subgraphs by the means of an explicitly marked input node
 * 
 * Auto flow is performed as if the two graphs were auto-connected in separation,
 * yet some conversions are potentially avoided.
 *
 * This operation removes the input node if it's of the Input type or leaves it be
 * if it's a different node. This makes it possible e.g. to connect a complete graph
 * with designated Input and Output nodes to an existing graph, or just tack a single
 * note into one.
 *
 * The _findSrcParam callback will have to provide the parameters on the input side
 * of the Output node in the existing (connected, converted) graph.
 * 
 * Note: currently the callback is queried via the names of the /Input/ node
 * in the destination graph
 */
void fuseGraph(
	KernelGraph	graph,
	GraphNodeId	input,
	ConvCtx ctx,
	GraphNodeId[] dstGraphTopological,
	bool delegate(
		Param* dstParam,
		GraphNodeId* srcNid,
		Param** srcParam
	) _findSrcParam,
	OutputNodeConversion outNodeConversion
) {
	return fuseGraph(
		graph,
		input,
		ctx,
		(int delegate(ref GraphNodeId) sink) {
			foreach (nid; dstGraphTopological) {
				if (int r = sink(nid)) {
					return r;
				}
			}
			return 0;
		},
		_findSrcParam,
		outNodeConversion
	);
}


/// ditto
void fuseGraph(
	KernelGraph	graph,
	GraphNodeId	input,
	ConvCtx ctx,
	int delegate(int delegate(ref GraphNodeId)) dstGraphTopological,
	bool delegate(
		Param* dstParam,
		GraphNodeId* srcNid,
		Param** srcParam
	) _findSrcParam,
	OutputNodeConversion outNodeConversion
) {
	scope stack = new StackBuffer;

	alias KernelGraph.NodeType NT;

	foreach (dummy; graph.flow.iterIncomingConnections(input)) {
		error(
			"The 'input' node may not have any incoming connections"
			" prior to calling fuseGraph"
		);
	}

	bool inputNodeIsFunc = KernelGraph.NodeType.Input != graph.getNode(input).type;

	// A list of all output ports on the Input node, to be used in custom
	// auto flow port generation
	final outputPorts = LocalDynArray!(NodeParam)(stack);
	foreach (ref fromParam; *graph.getNode(input).getParamList()) {
		if (fromParam.isOutput) {
			outputPorts.pushBack(NodeParam(input, &fromParam));
		}
	}						

	bool isOutputNode(GraphNodeId id) {
		return NT.Output == graph.getNode(id).type;
	}

	// Do auto flow for the second graph, extending the incoming flow of the
	// input node to the inputs of the output node from the first graph
	foreach (id; dstGraphTopological) {
		if (inputNodeIsFunc && input == id) {
			/*
			 * This is a special case for when the destination graph's /input/
			 * node it not of the Input type but e.g. a Func node. If this wasn't
			 * the case, we'd be connecting the Input node's /successors/ to the
			 * source graph in a more involved operation. This case is simpler
			 * and only involves connecting the input node directly to what's
			 * in the source graph.
			 */
			doAutoFlow(
				graph,
				id,
				ctx,
				OutputNodeConversion.Skip == outNodeConversion && isOutputNode(id)
					? FlowGenMode.DirectConnection
					: FlowGenMode.InsertConversionNodes,
				(Param* dstParam, void delegate(NodeParam) incomingSink) {
					GraphNodeId	fromNode;
					Param*		fromParam;
					
					if (!_findSrcParam(
						dstParam,
						&fromNode,
						&fromParam
					)) {
						assert (false,
							"Could not find a source parameter"
							" for the Output node twin to the"
							" Func node used in graph fusion."
							" This should have been triggered"
							" earlier, when resolving the Output."
							" The param was '" ~ dstParam.name ~ "'."
						);
					}

					assert (fromParam.isOutput);

					/*
					 * Add the param returned by the user to the list of nodes
					 * for which we're considering auto conversion. This will
					 * usually be just one node that the user supplies, however
					 * it could happen that there's e.g. a Data node connected
					 * to the input on the destination side, so we cover that
					 * case by using AutoFlow instead of a direct connection
					 */
					incomingSink(NodeParam(fromNode, fromParam));
				}
			);

			// Convert SemanticExp to Semantic, nuff said
			simplifyParamSemantics(graph, id);

		} else if (input == id) {
			scope stack2 = new StackBuffer;
			final toRemove = LocalDynArray!(ConFlow)(stack2);
			
			foreach (outCon; graph.flow.iterOutgoingConnections(input)) {
				if (OutputNodeConversion.Perform == outNodeConversion || !isOutputNode(outCon)) {
					foreach (outFl; graph.flow.iterDataFlow(input, outCon)) {
						GraphNodeId	fromNode;
						Param*		fromParam;

						if (Param* fromTmp = graph.getNode(input).getOutputParam(outFl.from)) {
							if (!_findSrcParam(
								fromTmp,
								&fromNode,
								&fromParam
							)) {
								assert (false);
							}

							if (doManualFlow(
								graph,
								fromNode, outCon,
								DataFlow(fromParam.name, outFl.to),
								ctx
							)) {
								toRemove.pushBack(ConFlow(
									input, outFl.from,
									outCon, outFl.to
								));
							}
						} else {
							error(
								"Src param '{}' not found in node {}.",
								outFl.from,
								input.id
							);
						}
					}
				}
			}

			foreach (rem; toRemove) {
				graph.flow.removeDataFlow(rem.fromNode, rem.fromParam, rem.toNode, rem.toParam);
			}
		} else {
			doAutoFlow(
				graph,
				id,
				ctx,
				OutputNodeConversion.Skip == outNodeConversion && isOutputNode(id)
					? FlowGenMode.DirectConnection
					: FlowGenMode.InsertConversionNodes,

				/* Using custom enumeration of incoming nodes/ports
				 * because we'll need to treat the Input node specially.
				 *
				 * Basically, we want the semantics of connecting the Output
				 * and Input nodes together and resolving auto flow regularly.
				 * This is not done in such a straightforward way, since
				 * 1) Can't connect an Output node to an Input node, because
				 *    Output nodes only have _input_ ports and Input nodes
				 *    only have _output_ ports.
				 * 2) There might be some additional conversions done in the
				 *    straightforward approach. They would subsequently require
				 *    an optimization pass.
				 */
				(Param* toParam, void delegate(NodeParam) incomingSink) {
					foreach (fromId; graph.flow.iterIncomingConnections(id)) {
						/* Ordinary stuff so far */
						if (graph.flow.hasAutoFlow(fromId, id)) {

							/* Now, if this node has automatic flow from the
							 * Input node, we will want to override it. Only in case
							 * that the input node is of the Input type. The other
							 * case is done for in the first clause of the top-most
							 * conditional in this function.
							 */
							if (!inputNodeIsFunc && input == fromId) {
								/* First, we figure out to which port auto
								 * flow would connect this param to, but we
								 * don't connect to it and instead dig deeper
								 */

								findAutoFlow(
									graph,
									outputPorts.data,
									id,
									toParam,
									ctx,

									/* This dg will receive the port to which
									 * auto flow would resolve to on the
									 * side of the Input node
									 */
									(	ConvSinkItem[] convChain,
										GraphNodeId intermediateId,
										Param* intermediateParam
									) {
										if (input == intermediateId) {
											/* Now, the Input node is the graph2-side
											 * connector, which is a twin to an
											 * Output node in graph1 and which has
											 * incoming params connected to. We now
											 * find which param connects to the port
											 * equivalent to what we just identified
											 * for the Input node.
											 */

											GraphNodeId	fromNode;
											Param*		fromParam;
											
											if (!_findSrcParam(
												toParam,
												&fromNode,
												&fromParam
											)) {
												assert (false,
													"Could not find a source parameter"
													" for the Output node twin to the"
													" Input node used in graph fusion."
													" This should have been triggered"
													" earlier, when resolving the Output."
												);
											}

											assert (fromParam.isOutput);

											/* Finally, the original port from graph1
											 * is added to the list of all connections
											 * to consider for the auto flow resolving
											 * process for the particular param we're
											 * evaluating a few scopes higher :P
											 */

											incomingSink(NodeParam(fromNode, fromParam));
										} else {
											incomingSink(NodeParam(
												intermediateId,
												intermediateParam
											));
										}
									},

									/*
									 * This call to findAutoFlow doesn't need to find
									 * sources for flow into all of the inputs, as
									 * the outer doAutoFlow may decide to use other
									 * nodes as well, say when using Data nodes
									 * in addition to external input
									 */
									ErrorHandlingMode.Ignore
								);
							} else {
								/* Data flow from a node different than the
								 * Input node. Regular stuff
								 */
								
								final fromNode = graph.getNode(fromId);
								ParamList* fromParams = fromNode.getParamList();

								foreach (ref fromParam; *fromParams) {
									if (fromParam.isOutput) {
										incomingSink(NodeParam(fromId, &fromParam));
									}
								}
							}
						}
					}
				}
			);

			// Convert SemanticExp to Semantic, nuff said
			simplifyParamSemantics(graph, id);

			{
				scope stack2 = new StackBuffer;
				final toRemove = LocalDynArray!(ConFlow)(stack2);

				foreach (con; graph.flow.iterOutgoingConnections(id)) {
					if (OutputNodeConversion.Perform == outNodeConversion || !isOutputNode(con)) {
						foreach (fl; graph.flow.iterDataFlow(id, con)) {
							if (doManualFlow(
								graph,
								id,
								con, fl,
								ctx
							)) {
								toRemove.pushBack(ConFlow(
									id, fl.from,
									con, fl.to
								));
							}
						}
					}
				}

				foreach (rem; toRemove) {
					graph.flow.removeDataFlow(rem.fromNode, rem.fromParam, rem.toNode, rem.toParam);
				}
			}
		}
	}

	// The Input node is useless now, but don't remove any other node types
	if (KernelGraph.NodeType.Input == graph.getNode(input).type) {
		graph.removeNode(input);
	}
}


/**
 * Redirects the data flow from the 'output' node into the nodes connected
 * to the 'input' node, then removes both nodes, thus fusing two separate
 * sub-graphs.
 *
 * This should optimally be called before resolving auto flow, so that
 * some conversions may potentially be avoided.
 */
void fuseGraph(
	KernelGraph	graph,
	GraphNodeId	output,
	int delegate(int delegate(ref GraphNodeId)) graph1NodeIter,
	GraphNodeId	input,
	ConvCtx ctx,
	OutputNodeConversion outNodeConversion
) {
	scope stack = new StackBuffer;

	foreach (dummy; graph.flow.iterOutgoingConnections(output)) {
		error(
			"The 'output' node may not have any outgoing connections"
			" prior to calling fuseGraph"
		);
	}

	// Not disposed anywhere since its storage is on the StackBuffer
	DynamicBitSet graph1Nodes;
	
	graph1Nodes.alloc(graph.capacity, &stack.allocRaw);
	graph1Nodes.clearAll();

	//markPrecedingNodes(graph.backend_readOnly, &graph1Nodes, null, output);
	foreach (nid; graph1NodeIter) {
		graph1Nodes.set(nid.id);
	}

	final topological = stack.allocArray!(GraphNodeId)(graph.numNodes);
	findTopologicalOrder(graph.backend_readOnly, topological);

	int iterGraph1Nodes(int delegate(ref GraphNodeId) sink) {
		foreach (id; topological) {
			if (graph1Nodes.isSet(id.id)) {
				if (int r = sink(id)) {
					return r;
				}
			}
		}
		return 0;
	}

	int iterGraph2Nodes(int delegate(ref GraphNodeId) sink) {
		foreach (id; topological) {
			if (!graph1Nodes.isSet(id.id)) {
				if (int r = sink(id)) {
					return r;
				}
			}
		}
		return 0;
	}

	convertGraphDataFlowExceptOutput(
		graph,
		ctx,
		&iterGraph1Nodes
	);

	bool outputNodeIsFunc = KernelGraph.NodeType.Output != graph.getNode(output).type;

	fuseGraph(
		graph,
		input,
		ctx,
		&iterGraph2Nodes,
		(
			Param* dstParam,
			GraphNodeId* srcNid,
			Param** srcParam
		) {
			/*
			 * We perform the lookup by name only (TODO?).
			 */

			return .getOutputParamIndirect(
				graph,
				output,
				dstParam.name,
				srcNid,
				srcParam
			);
		},
		outNodeConversion
	);

	// The Output node is useless now, but don't remove any other node types
	if (!outputNodeIsFunc) {
		graph.removeNode(output);
	}
	
	graph.flow.removeAllAutoFlow();
}


enum FlowGenMode {
	InsertConversionNodes,
	DirectConnection,
	NoAction
}


struct NodeParam {
	GraphNodeId	node;
	Param*		param;
}


private struct ConFlow {
	GraphNodeId	fromNode;
	cstring		fromParam;
	GraphNodeId	toNode;
	cstring		toParam;
}


void verifyDataFlowNames(KernelGraph graph) {
	final flow = graph.flow();
	
	foreach (fromId; graph.iterNodes) {
		final fromNode = graph.getNode(fromId);
		
		foreach (toId; flow.iterOutgoingConnections(fromId)) {
			final toNode = graph.getNode(toId);
			
			foreach (fl; flow.iterDataFlow(fromId, toId)) {
				final op = fromNode.getOutputParam(fl.from);
				if (op is null) {
					error(
						"verifyDataFlowNames: The source node for flow {}->{}"
						" doesn't have an output parameter called '{}'",
						fromId.id, toId.id, fl.from
					);
				}
				assert (op.isOutput);

				final ip = toNode.getInputParam(fl.to);
				if (ip is null) {
					error(
						"verifyDataFlowNames: The target node for flow {}->{}"
						" doesn't have an input parameter called '{}'",
						fromId.id, toId.id, fl.to
					);
				}
				assert (ip.isInput);
				assert (ip.hasPlainSemantic);
			}
		}
	}

	scope stack = new StackBuffer;

	foreach (toId; graph.iterNodes) {
		final toNode = graph.getNode(toId);
		ParamList* plist;
		
		if (KernelGraph.NodeType.Kernel == toNode.type) {
			plist = &toNode.kernel.kernel.func.params;
		} else {
			plist = toNode.getParamList();
		}

		DynamicBitSet paramHasInput;
		paramHasInput.alloc(plist.length, &stack.allocRaw);
		paramHasInput.clearAll();

		void onDuplicateFlow(cstring to) {
			cstring[] sources;

			foreach (fromId; flow.iterIncomingConnections(toId)) {
				final fromNode = graph.getNode(fromId);
			
				foreach (fl; flow.iterDataFlow(fromId, toId)) {
					if (fl.to == to) {
						sources ~= Format("{}.{}", fromId.id, fl.from);
					}
				}
			}

			error(
				"Duplicate flow to {}.{} from {}.",
				toId.id, to, sources
			);
		}

		foreach (fromId; flow.iterIncomingConnections(toId)) {
			final fromNode = graph.getNode(fromId);
		
			foreach (fl; flow.iterDataFlow(fromId, toId)) {
				Param* dst;
				if (plist.getInput(fl.to, &dst)) {
					final idx = plist.indexOf(dst);
					if (paramHasInput.isSet(idx)) {
						onDuplicateFlow(fl.to);
					} else {
						paramHasInput.set(idx);
					}
				} else {
					error(
						"verifyDataFlowNames: The target node for flow {}->{}"
						" doesn't have an input parameter called '{}'",
						fromId.id, toId.id, fl.to
					);
				}
			}
		}
	}
}


private cstring _fmtChain(ConvSinkItem[] chain) {
	cstring res;
	foreach (c; chain) {
		res ~= Format(
			"    {} -> <{}>\n",
			c.converter.func.name,
			c.afterConversion.toString
		);
	}
	return res;
}


// returns true if any new connections were inserted
private bool _insertConversionNodes(
	KernelGraph graph,
	ConvSinkItem[] chain,
	GraphNodeId fromId,
	Param* fromParam,
	GraphNodeId toId,
	Param* toParam
) {
	GraphNodeId	srcId		= fromId;
	Param*		srcParam	= fromParam;

	foreach (c; chain) {
		final cnodeId = graph.addNode(KernelGraph.NodeType.Func);
		final cnode = graph.getNode(cnodeId).func();
		cnode.func = c.converter.func;

		assert (2 == cnode.func.params.length);
		assert (cnode.func.params[0].isInput);
		assert (cnode.func.params[0].hasPlainSemantic);
		assert (cnode.func.params[1].isOutput);
		
		graph.flow.addDataFlow(
			srcId,
			srcParam.name,
			cnodeId,
			cnode.func.params[0].name
		);
		
		void* delegate(uword) mem = &graph._mem.pushBack;
		cnode.params._allocator = mem;
		cnode.params.add(cnode.func.params[0].dup(mem));
		
		auto p = cnode.params.add(ParamDirection.Out, cnode.func.params[1].name);
		p.hasPlainSemantic = true;
		*p.semantic() = c.afterConversion.dup(mem);
		// No need to care about the default value here.
		// No need to care about whether the param wants auto flow or not, either

		srcId = cnodeId;
		srcParam = cnode.params[1];
	}

	bool newFlow;

	graph.flow.addDataFlow(
		srcId,
		srcParam.name,
		toId,
		toParam.name,
		&newFlow
	);

	return newFlow || chain.length > 0;
}


private enum ErrorHandlingMode {
	Throw,
	Ignore
}


private void findAutoFlow(
	KernelGraph graph,
	NodeParam[] fromParams,
	GraphNodeId toId,
	Param* toParam,
	ConvCtx ctx,
	void delegate(
			ConvSinkItem[] convChain,
			GraphNodeId fromId,
			Param* fromParam
	) result,
	ErrorHandlingMode errorHandlingMode = ErrorHandlingMode.Throw
) {
	scope stack = new StackBuffer;

	struct ConvInfo {
		ConvSinkItem[]	chain;
		GraphNodeId		fromId;
		Param*			fromParam;
		ConvInfo*		next;
	}
	
	int			bestCost = int.max;
	ConvInfo*	bestConvs;

	foreach (from_; fromParams) {
		GraphNodeId	fromId = from_.node;
		Param*		fromParam = from_.param;
		
		log.trace("findAutoFlow {} -> {}", fromId.id, toId.id);

		scope stack2 = new StackBuffer;
		
		assert (fromParam.isOutput);
		
		int convCost = 0;

		assert (toParam.isInput);
		assert (fromParam.hasPlainSemantic, fromParam.name);
		assert (toParam.hasPlainSemantic, toParam.name);
		
		findConversion(
			*fromParam.semantic,
			*toParam.semantic,
			ctx.semanticConverters,
			stack2,
			(ConvSinkItem[] convChain) {
				if (convCost > bestCost) {
					return;
				}
				
				stack2.mergeWith(stack);
				final info = stack._new!(ConvInfo)(
					convChain,
					fromId,
					fromParam,
					cast(ConvInfo*)null		// stupid DMD
				);
				
				if (convCost < bestCost) {
					// replace
					bestConvs = info;
					bestCost = convCost;
				} else if (convCost == bestCost) {
					// add
					info.next = bestConvs;
					bestConvs = info;
				}
			},
			&convCost
		);
	}

	if (bestCost < int.max) {
		assert (bestConvs !is null);
		if (bestConvs.next !is null) {
			// Ambiguity error
			
			cstring errMsg = Format(
				"Auto flow ambiguity while trying to find flow to an input param"
				" '{}' in graph node {}.\n"
				"Found multiple conversion paths with the cost {}:\n",
				toParam.toString, toId.id, bestCost
			);

			for (auto it = bestConvs; it !is null; it = it.next) {
				errMsg ~= Format(
					"  Path from node {}:\n",
					it.fromId.id
				);
				errMsg ~= _fmtChain(it.chain);
			}

			error("{}", errMsg);
		} else {
			// Found a unique conversion path

			result(
				bestConvs.chain,
				bestConvs.fromId, bestConvs.fromParam
			);
		}
	} else if (ErrorHandlingMode.Throw == errorHandlingMode) {
		// Conversion path not found

		uword numConv = 0;
		cstring suffix;
		
		foreach (from_; fromParams) {
			++numConv;
			if (suffix is null) {
				suffix = Format("{}.{}", from_.node.id, from_.param.name);
			} else {
				suffix ~= Format(", {}.{}", from_.node.id, from_.param.name);
			}
		}

		assert (toParam.wantAutoFlow, toParam.toString);

		// This error probably shouldn't even be triggered, as the
		// node may be unused.
		/+error(
			"Auto flow not found for an input param"
			" '{}' in graph node {}.\n"
			"Considered {} converters from:\n[{}]",
			toParam.toString, toId.id, numConv, suffix
		);+/
	}
}


private void simplifyParamSemantics(KernelGraph graph, GraphNodeId id) {
	final node = graph.getNode(id);

	if (KernelGraph.NodeType.Kernel == node.type) {
		foreach (ref Param par; node.kernel.kernel.func.params) {
			if (!par.hasPlainSemantic) {
				error("Special Kernel-type nodes must only have plain semantics.");
			}
		}
	}

	else if (KernelGraph.NodeType.Func == node.type) {
		final params = &node.func.params;
		foreach (ref Param par; *params) {
			if (par.isInput || par.hasPlainSemantic) {
				continue;
			}

			Semantic plainSem = Semantic(&graph._mem.pushBack);

			findOutputSemantic(
				&par,

				// getFormalParamSemantic
				(cstring name) {
					foreach (ref Param p; *params) {
						if (p.isInput && p.name == name) {
							return *p.semantic();
						}
					}
					error(
						"simplifyParamSemantics: output param '{}' refers to a"
						" nonexistent formal parameter '{}'.",
						par.name,
						name
					);
					assert (false);
				},

				// getActualParamSemantic
				(cstring name) {
					GraphNodeId	fromId;
					cstring		fromName;

					// Note: O (cons * flow * inputPorts). Maybe too slow?
					foreach (fromId_; graph.flow.iterIncomingConnections(id)) {
						foreach (fl; graph.flow.iterDataFlow(fromId_, id)) {
							if (fl.to == name) {
								if (fromName !is null) {
									error(
										"The semantic conversion process introduced"
										" duplicate flow\n    to {}.{}"
										" from {}.{} and {}.{}.",
										id.id, name,
										fromId.id, fromName,
										fromId_.id, fl.from
									);
								}
								
								fromId = fromId_;
								fromName = fl.from;
							}
						}
					}

					if (fromName !is null) {
						Param* dstParam;
						if (params.getInput(name, &dstParam)) {
							assert (dstParam !is null);
							if (!dstParam.wantAutoFlow) {
								error(
									"Output param {} of kernel {} used by node {}"
									" has an semantic expression using the actual"
									" parameter of the input {}, which has been"
									" marked as noauto and has no direct connection.",
									par.name, node.func.func.name, id.id,
									name
								);
							}
						} else {
							assert (false, name);
						}

						return *graph.getNode(fromId)
							.getOutputParam(fromName).semantic();
					} else {
						assert (false, "simplifyParamSemantics: No flow to " ~ name);
					}
				},
				
				&plainSem
			);

			par.hasPlainSemantic = true;
			*par.semantic() = plainSem;
		}

		foreach (ref Param par; *params) {
			if (par.isOutput) {
				continue;
			}

			GraphNodeId	fromId;
			cstring		fromName;

			// Note: O (cons * flow * inputPorts). Maybe too slow?
			foreach (fromId_; graph.flow.iterIncomingConnections(id)) {
				foreach (fl; graph.flow.iterDataFlow(fromId_, id)) {
					if (fl.to == par.name) {
						if (fromName !is null) {
							error(
								"The semantic conversion process introduced"
								" duplicate flow\n    to {}.{}"
								" from {}.{} and {}.{}.",
								id.id, par.name,
								fromId.id, fromName,
								fromId_.id, fl.from
							);
						}
						
						fromId = fromId_;
						fromName = fl.from;
					}
				}
			}

			if (fromName is null) {
				if (par.wantAutoFlow) {
					// the loop is to test whether there are any outgoing
					// connections at all
					foreach (id; graph.flow.iterOutgoingConnections(id)) {
						error("No flow to '{}' D:", par.name);
					}
				}
			} else {
				final srcParam = graph.getNode(fromId)
					.getOutputParam(fromName);

				*par.semantic() = *srcParam.semantic();
			}
		}
	}
}


private void doAutoFlow(
		KernelGraph graph,
		GraphNodeId toId,
		ConvCtx ctx,
		FlowGenMode flowGenMode
) {
	return doAutoFlow(
		graph,
		toId,
		ctx,
		flowGenMode,
		(Param*, void delegate(NodeParam) incomingSink) {
			foreach (fromId; graph.flow.iterIncomingConnections(toId)) {
				if (graph.flow.hasAutoFlow(fromId, toId)) {
					final fromNode = graph.getNode(fromId);
					ParamList* fromParams = fromNode.getParamList();

					foreach (ref fromParam; *fromParams) {
						if (fromParam.isOutput) {
							incomingSink(NodeParam(fromId, &fromParam));
						}
					}						
				}
			}
		}
	);
}

private void doAutoFlow(
		KernelGraph graph,
		GraphNodeId toId,
		ConvCtx ctx,
		FlowGenMode flowGenMode,
		void delegate(Param*, void delegate(NodeParam)) incomingGen
) {
	scope stack = new StackBuffer;

	final toNode = graph.getNode(toId);
	ParamList* plist = toNode.getParamList();
	
	switch (toNode.type) {
		case KernelGraph.NodeType.Func:
		case KernelGraph.NodeType.Output:
		case KernelGraph.NodeType.Kernel:
		case KernelGraph.NodeType.Bridge:
			break;

		default: return;		// just outputs here
	}

	DynamicBitSet portHasDataFlow;
	portHasDataFlow.alloc(plist.length, (uword num) { return stack.allocRaw(num); });
	portHasDataFlow.clearAll();

	foreach (i, ref param; *plist) {
		if (!param.wantAutoFlow) {
			portHasDataFlow.set(i);
		}
	}

	// Note: O (cons * flow * inputPorts). Maybe too slow?
	foreach (fromId; graph.flow.iterIncomingConnections(toId)) {
		foreach (fl; graph.flow.iterDataFlow(fromId, toId)) {
			final p = plist.get(fl.to);
			assert (p !is null);
			portHasDataFlow.set(plist.indexOf(p));
		}
	}

	foreach (paramI, ref param; *plist) {
		if (param.isInput && !portHasDataFlow.isSet(paramI)) {
			scope stack2 = new StackBuffer;
			
			final fromIds = LocalDynArray!(NodeParam)(stack2);
			
			incomingGen(&param, (NodeParam np) {
				fromIds.pushBack(np);
			});

			findAutoFlow(graph, fromIds.data, toId, &param, ctx,
				(	ConvSinkItem[] convChain,
					GraphNodeId fromId,
					Param* fromParam
				) {
					switch (flowGenMode) {
						case FlowGenMode.InsertConversionNodes: {
							log.info("Found a conversion path. Inserting nodes.");

							_insertConversionNodes(
								graph,
								convChain,
								fromId, fromParam,
								toId, &param
							);
						} break;

						case FlowGenMode.DirectConnection: {
							graph.flow.addDataFlow(
								fromId, fromParam.name,
								toId, param.name
							);
						} break;

						default: assert (false);
					}
				}
			);
		}
	}
}


private bool isTypeKernel(cstring type, KernelImpl* info, ConvCtx ctx) {
	return ctx.getKernel(type, info);
}


/*
 * Returns true if the node or its incoming subtree contains free params
 * not filtered out by the supplied delegate
 */
private bool buildFunctionSubgraph(
		KernelGraph graph,
		GraphNodeId id,
		bool delegate(Param*) paramFilter,
		
		void delegate(Param*, GraphNodeId) freeParamSink,
		DynamicBitSet* clonedNodesSet,
		KernelGraph newGraph,
		GraphNodeId newGraphDataNode,
		GraphNodeId oldGraphCompNode,
		GraphNodeId* newNode
) {
	bool result = false;
	scope stack = new StackBuffer;

	ParamList* plist = graph.getNode(id).getParamList();

	DynamicBitSet paramHasInput;
	paramHasInput.alloc(plist.length, &stack.allocRaw);
	paramHasInput.clearAll();

	foreach (from; graph.flow.iterIncomingConnections(id)) {
		foreach (fl; graph.flow.iterDataFlow(from, id)) {
			Param* dst;
			if (!plist.getInput(fl.to, &dst)) {
				error(
					"Shit happened. Destination flow invalid for {}.{}->{}.{}",
					from.id, fl.from, id.id, fl.to
				);
			} else {
				paramHasInput.set(plist.indexOf(dst));
			}
		}

		GraphNodeId prevNode;
		
		if (buildFunctionSubgraph(
			graph,
			from,
			paramFilter,
			freeParamSink,
			clonedNodesSet,
			newGraph,
			newGraphDataNode,
			oldGraphCompNode,
			&prevNode
		)) {
			if (!result) {
				auto node = graph.getNode(id);
				*newNode = newGraph.addNode(node.type);
				node.copyTo(newGraph.getNode(*newNode));
				clonedNodesSet.set(id.id);
				result = true;
			}

			foreach (fl; graph.flow.iterDataFlow(from, id)) {
				newGraph.flow.addDataFlow(prevNode, fl.from, *newNode, fl.to);
			}
		}
	}

	foreach (i, ref param; *plist) {
		if (!param.isInput) {
			continue;
		}
		
		if (!paramHasInput.isSet(i)) {
			if (paramFilter(&param)) {
				if (!result) {
					auto node = graph.getNode(id);
					*newNode = newGraph.addNode(node.type);
					node.copyTo(newGraph.getNode(*newNode));
					clonedNodesSet.set(id.id);
					result = true;
				}
				
				freeParamSink(
					newGraph.getNode(*newNode).getInputParam(param.name),
					*newNode
				);
			}
		}
	}

	if (result) {
		auto dataNode = newGraph.getNode(newGraphDataNode).data();
		auto oldCompNode = graph.getNode(oldGraphCompNode).composite();
		
		foreach (i, ref param; *plist) {
			if (!param.isInput) {
				continue;
			}

			if (paramHasInput.isSet(i)) {
				// This param will have to be bridged via the Data node
				
				formatTmp((Fmt fmt) {
					fmt.format("comp__p{}", dataNode.params.length);
				},
				(cstring pname) {
					/*
					 * Find where from the flow comes into the param back in the
					 * original graph. We'll copy the flow into the function node
					 * which graph the subgraph we're constructing.
					 */
					GraphNodeId	oldSrcNid;
					Param*		oldSrcParam;

					if (!findSrcParam(
						graph,
						id,
						param.name,
						&oldSrcNid,
						&oldSrcParam
					)) {
						error("Huh. Flow not found to param {}. But... but... D:", param.name);
					}

					/*
					 * Only copy the flow if the source is not already in the cloned
					 * subgraph. Otherwise the flow would be duplicate
					 */
					if (!clonedNodesSet.isSet(oldSrcNid.id)) {
						/*
						 * Add a param to the data node in the new subgraph.
						 * Use a unique name for it.
						 */
						auto dparam = dataNode.params.add(param, pname);
						dparam.dir = ParamDirection.Out;

						/*
						 * Now add flow from the newly added Data node param to the
						 * node we've just cloned as the main part of this function.
						 */
						newGraph.flow.addDataFlow(
							newGraphDataNode,
							pname,
							*newNode,
							param.name
						);

						/*
						 * Add the same param as in the Data node to the function node
						 * we're building in the old graph
						 */

						auto fparam = oldCompNode.params.add(param, pname);
						fparam.dir = ParamDirection.In;

						/*
						 * Finally, create flow to the function node
						 */

						graph.flow.addDataFlow(
							oldSrcNid,
							oldSrcParam.name,
							oldGraphCompNode,
							pname
						);
					}
				});
			}
		}
	}

	return result;
}


// returns true if any new connections were inserted
private bool doManualFlow(
		KernelGraph graph,
		GraphNodeId fromId,
		GraphNodeId toId,
		DataFlow fl,
		ConvCtx ctx
) {
	scope stack = new StackBuffer;

	final fromNode = graph.getNode(fromId);
	assert (fromNode !is null, "doManualfrom: fromNode not found");
	final fromParam = fromNode.getOutputParam(fl.from);
	assert (fromParam !is null, "doManualfrom: fromParam not found: " ~ fl.from);
	assert (fromParam.hasPlainSemantic);

	final toNode = graph.getNode(toId);
	assert (toNode !is null, "doManualfrom: toNode not found");
	final toParam = toNode.getInputParam(fl.to);
	assert (toParam !is null, "doManualfrom: toParam not found: " ~ fl.to);
	assert (toParam.hasPlainSemantic);

	{
		KernelImpl dstKernelImpl;

		final srcType = fromParam.type;
		
		if (	toParam.hasTypeConstraint
			&&	isTypeKernel(toParam.type, &dstKernelImpl, ctx)
			&&	(!fromParam.hasTypeConstraint || srcType != toParam.type)
		) {
			// The destination is a kernel, this is functional composition, not regular
			// param flow.

			if (dstKernelImpl.type != KernelImpl.Type.Kernel) {
				error(
					"Kernels used in functional composition may not be graph"
					" kernels. There's flow to a graph kernel '{}': {}.{} -> {}.{}.",
					toParam.type, fromId.id, fl.from, toId.id, fl.to
				);
			}

			auto dstFunc = dstKernelImpl.kernel.func;
			assert (dstFunc !is null);

			Param* funcOutputParam = null;

			uword numFuncOutputParams;
			foreach (ref param; dstFunc.params) {
				if (param.isOutput) {
					++numFuncOutputParams;
					funcOutputParam = &param;
				}
			}

			//assureNotCyclic(graph);

			assert (
				1 == numFuncOutputParams,
				"TODO: currently kernels used in functional composition may only"
				" have one output param."
			);

			assert (funcOutputParam !is null);

			KernelGraph subgraph = createKernelGraph();

			//assureNotCyclic(graph);

			/*
			 * There will be a subgraph of comprising the nodes being used in
			 * functional composition. Create an output node for it
			 */
			final outNodeId = subgraph.addNode(KernelGraph.NodeType.Output);
			final outNode = subgraph.getNode(outNodeId).output();
			final outNodeParam = outNode.params.add(*funcOutputParam);
			outNodeParam.dir = ParamDirection.In;

			/*
			 * Similarly with the input node.
			 */
			final inNodeId = subgraph.addNode(KernelGraph.NodeType.Input);
			final inNode = subgraph.getNode(inNodeId).input();
			foreach (ref param; dstFunc.params) {
				inNode.params.add(param).dir = ParamDirection.Out;
			}

			const kernelOutputName = "kernel";

			/*
			 * The functional composition will happen via a Composite node which
			 * will reside in the original graph and codegen into a struct in Cg
			 */
			final compNodeId = graph.addNode(KernelGraph.NodeType.Composite);
			final compNode = graph.getNode(compNodeId).composite();
			auto compOutParam = compNode.params.add(ParamDirection.Out, kernelOutputName);
			compOutParam.hasPlainSemantic = true;
			compOutParam.type = toParam.type;

			/*
			 * Params which go into the composition node on the side of the old
			 * graph, will appear in a data node on the side of the new graph.
			 */
			final dataNodeId = subgraph.addNode(KernelGraph.NodeType.Data);
			final dataNode = subgraph.getNode(dataNodeId).data();
			dataNode.sourceKernelType = SourceKernelType.Composite;

			compNode.targetFunc = dstFunc;
			compNode.graph = subgraph;
			compNode.dataNode = dataNodeId;
			compNode.inNode = inNodeId;
			compNode.outNode = outNodeId;

			//assureNotCyclic(graph);

			/*
			 * The input node's params must now be connected to the params in the
			 * source node's incoming tree which have no incoming flow.
			 * The matching is done by name, then semantic conversion is applied
			 * to each of them
			 */

			GraphNodeId fromNodeInSubgraph;

			//assureNotCyclic(graph);

			DynamicBitSet clonedNodesSet;
			clonedNodesSet.alloc(graph.capacity, &stack.allocRaw);
			clonedNodesSet.clearAll();
			

			buildFunctionSubgraph(
				graph,
				fromId,

				/* paramFilter */
				(Param* param) {
					assert (param.isInput);
					foreach (fp; dstFunc.params) {
						if (fp.isInput && fp.name == param.name) {
							return true;
						}
					}
					return false;
				},
				
				/* freeParamSink */
				(Param* param, GraphNodeId node) {
					Param* inParam = null;
					inNode.params.getOutput(param.name, &inParam);
					assert (inParam !is null);

					//assureNotCyclic(graph);
					
					if (!findConversion(
						*inParam.semantic,
						*param.semantic,
						ctx.semanticConverters,
						stack,
						(ConvSinkItem[] convChain) {
							_insertConversionNodes(
								subgraph,
								convChain,
								inNodeId,
								inParam,
								node,
								param
							);
						}
					)) {
						error(
							"Could not find a conversion for direct flow:"
							" {}:{} -> {}:{} when performing functional composition"
							" using kernel {}. The input param in the kernel was {}.",
							inNodeId.id, inParam.toString,
							node.id, param.toString,
							toParam.type, funcOutputParam.toString
						);
					}

					//assureNotCyclic(graph);
				},

				&clonedNodesSet,
				subgraph,
				dataNodeId,
				compNodeId,
				&fromNodeInSubgraph
			);

			//assureNotCyclic(graph);

			Semantic funcOutputPlainSem = Semantic(&subgraph._mem.pushBack);
			
			findOutputSemantic(
				funcOutputParam,

				// getFormalParamSemantic
				(cstring name) {
					foreach (ref Param p; dstFunc.params) {
						if (p.isInput && p.name == name) {
							return *p.semantic();
						}
					}
					error(
						"simplifyParamSemantics: output param '{}' refers to a"
						" nonexistent formal parameter '{}'.",
						funcOutputParam.name,
						name
					);
					assert (false);
				},

				// getActualParamSemantic
				(cstring name) {
					error(
						"Kernels used for functional composition must not use"
						" actual input param semantics."
					);
					return Semantic.init;
				},
				
				&funcOutputPlainSem
			);

			compNode.returnType = funcOutputPlainSem.getTrait("type");

			//assureNotCyclic(graph);

			/*
			 * The function's output param must be convertible to the destination
			 * param's semantic. The destination will sample the output param.
			 * Because the sampling may be performed directly by a kernel func,
			 * any conversion nodes must be inserted into the subgraph generated
			 * for the function.
			 */
			if (!findConversion(
				*fromParam.semantic,
				funcOutputPlainSem,
				ctx.semanticConverters,
				stack,
				(ConvSinkItem[] convChain) {
					_insertConversionNodes(
						subgraph,
						convChain,
						fromNodeInSubgraph,
						fromParam,
						outNodeId,
						outNodeParam
					);
				}
			)) {
				error(
					"Could not find a conversion for direct flow:"
					" {}:{} -> {}:{} when performing functional composition"
					" using kernel {}. The output param in the kernel was {}.",
					fromId.id, fromParam.toString,
					outNodeId.id, outNodeParam.toString,
					toParam.type, funcOutputParam.toString
				);
			}

			/*
			 * Finally, connect the output of the Composite node with the
			 * destination param from which we started the operation
			 */
			graph.flow.addDataFlow(
				compNodeId,
				kernelOutputName,
				toId,
				toParam.name
			);

			//assureNotCyclic(graph);

			/*
			 * New connections were added, remove the original one which caused
			 * the manual data flow func to be invoked.
			 */
			return true;
		}
	}

	bool anyNewCons = false;

	if (!findConversion(
		*fromParam.semantic,
		*toParam.semantic,
		ctx.semanticConverters,
		stack,
		(ConvSinkItem[] convChain) {
			anyNewCons = _insertConversionNodes(
				graph,
				convChain,
				fromId,
				fromParam,
				toId,
				toParam
			);
		}
	)) {
		error(
			"Could not find a conversion for direct flow:"
			" {}:{} -> {}:{}",
			fromId.id, fromParam.toString,
			toId.id, toParam.toString
		);
	}

	return anyNewCons;
}



// Assumes the consists of param/calc nodes only
void convertGraphDataFlow(
	KernelGraph graph,
	ConvCtx ctx
) {
	scope stack = new StackBuffer;

	final topological = stack.allocArray!(GraphNodeId)(graph.numNodes);
	findTopologicalOrder(graph.backend_readOnly, topological);

	return convertGraphDataFlow(graph, ctx, topological);
}


void convertGraphDataFlow(
	KernelGraph graph,
	ConvCtx ctx,
	GraphNodeId[] topological
) {
	foreach (id; topological) {
		doAutoFlow(
			graph,
			id,
			ctx,
			FlowGenMode.InsertConversionNodes
		);

		simplifyParamSemantics(graph, id);
		
		scope stack2 = new StackBuffer;
		final toRemove = LocalDynArray!(ConFlow)(stack2);

		foreach (con; graph.flow.iterOutgoingConnections(id)) {
			foreach (fl; graph.flow.iterDataFlow(id, con)) {
				if (doManualFlow(
					graph,
					id,
					con, fl,
					ctx
				)) {
					toRemove.pushBack(ConFlow(
						id, fl.from,
						con, fl.to
					));
				}
			}
		}

		foreach (rem; toRemove) {
			graph.flow.removeDataFlow(rem.fromNode, rem.fromParam, rem.toNode, rem.toParam);
		}
	}

	// NOTE: this was removed, m'kay?
	//graph.flow.removeAllAutoFlow();
}



void convertGraphDataFlowExceptOutput(
	KernelGraph graph,
	ConvCtx ctx
) {
	scope stack = new StackBuffer;

	final topological = stack.allocArray!(GraphNodeId)(graph.numNodes);
	findTopologicalOrder(graph.backend_readOnly, topological);

	return convertGraphDataFlowExceptOutput(graph, ctx, topological);
}


void convertGraphDataFlowExceptOutput(
	KernelGraph graph,
	ConvCtx ctx,
	GraphNodeId[] topological
) {
	return convertGraphDataFlowExceptOutput(
		graph,
		ctx,
		(int delegate(ref GraphNodeId) sink) {
			foreach (id; topological) {
				if (int r = sink(id)) {
					return r;
				}
			}
			return 0;
		}
	);
}

void convertGraphDataFlowExceptOutput(
	KernelGraph graph,
	ConvCtx ctx,
	int delegate(int delegate(ref GraphNodeId)) topological
) {
	bool isOutputNode(GraphNodeId id) {
		return KernelGraph.NodeType.Output == graph.getNode(id).type;
	}
	
	// Do auto flow for the first graph, but not generating conversions
	// for the output node
	foreach (id; topological) {
		doAutoFlow(
			graph,
			id,
			ctx,
			isOutputNode(id)
				? FlowGenMode.DirectConnection
				: FlowGenMode.InsertConversionNodes
		);
		
		simplifyParamSemantics(graph, id);

		scope stack2 = new StackBuffer;
		final toRemove = LocalDynArray!(ConFlow)(stack2);

		foreach (con; graph.flow.iterOutgoingConnections(id)) {
			bool markedForRemoval = false;
			
			if (!isOutputNode(con)) {
				foreach (fl; graph.flow.iterDataFlow(id, con)) {
					if (doManualFlow(
						graph,
						id,
						con, fl,
						ctx
					)) {
						toRemove.pushBack(ConFlow(
							id, fl.from,
							con, fl.to
						));
					}
				}
			}
		}

		foreach (rem; toRemove) {
			graph.flow.removeDataFlow(rem.fromNode, rem.fromParam, rem.toNode, rem.toParam);
		}
	}

	// NOTE: this was removed, m'kay?
	//graph.flow.removeAllAutoFlow();
}


void reduceGraphData(
	KernelGraph kg,
	void delegate(void delegate(
		GraphNodeId	nid,
		cstring		pname
	)) iterNodes,
	Function		reductionFunc,
	GraphNodeId*	outputNid,
	cstring*		outputPName
) {
	GraphNodeId	prevNid;
	cstring		prevPName;
	bool		gotAny = false;
	cstring		reductionPName;

	foreach (i, p; reductionFunc.params) {
		if (i > 3 || (i <= 1 && p.isOutput) || (2 == i && p.isInput)) {
			error(
				"reduceGraphData: '{}' is not a valid reduction func.",
				reductionFunc.name
			);
		}
		
		if (p.isOutput) {
			if (reductionPName is null) {
				reductionPName = p.name;
			} else {
				error(
					"reduceGraphData: The reduction func must only have"
					" one output param. The passed '{}' func has more.",
					reductionFunc.name
				);
			}
		}
	}

	iterNodes((
			GraphNodeId	nid,
			cstring		pname
		) {
			if (gotAny) {
				final rnid = kg.addFuncNode(reductionFunc);
				final rnode = kg.getNode(rnid);

				kg.flow.addDataFlow(
					prevNid, prevPName,
					rnid, reductionFunc.params[0].name
				);

				kg.flow.addDataFlow(
					nid, pname,
					rnid, reductionFunc.params[1].name
				);

				prevNid = rnid;
				prevPName = reductionPName;
			} else {
				prevNid = nid;
				prevPName = pname;
				gotAny = true;
			}
		}
	);

	*outputNid = prevNid;
	*outputPName = prevPName;
}
