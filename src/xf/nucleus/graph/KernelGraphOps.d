module xf.nucleus.graph.KernelGraphOps;

private {
	import xf.Common;
	import xf.nucleus.Function;
	import xf.nucleus.kernel.KernelDef;
	import xf.nucleus.graph.KernelGraph;

	// for the conversion
	import xf.nucleus.Param;
	import xf.nucleus.TypeSystem;
	import xf.nucleus.graph.Graph;
	import xf.nucleus.graph.GraphOps;
	import xf.nucleus.TypeConversion;
	import xf.mem.StackBuffer;
	import xf.utils.LocalArray;
	import tango.text.convert.Format;
	// ----

	import xf.nucleus.Log : error = nucleusError, log = nucleusLog;
}



enum OutputNodeConversion {
	Perform,
	Skip
}


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


void fuseGraph(
	KernelGraph	graph,
	GraphNodeId	input,
	SemanticConverterIter semanticConverters,
	KernelLookup getKernel,
	GraphNodeId[] dstGraphTopological,
	bool delegate(
		cstring dstParam,
		GraphNodeId* srcNid,
		Param** srcParam
	) _findSrcParam,
	OutputNodeConversion outNodeConversion
) {
	return fuseGraph(
		graph,
		input,
		semanticConverters,
		getKernel,
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


void fuseGraph(
	KernelGraph	graph,
	GraphNodeId	input,
	SemanticConverterIter semanticConverters,
	KernelLookup getKernel,
	int delegate(int delegate(ref GraphNodeId)) dstGraphTopological,
	bool delegate(
		cstring dstParam,
		GraphNodeId* srcNid,
		Param** srcParam
	) _findSrcParam,
	OutputNodeConversion outNodeConversion
) {
	scope stack = new StackBuffer;

	foreach (dummy; graph.flow.iterIncomingConnections(input)) {
		error(
			"The 'input' node may not have any incoming connections"
			" prior to calling fuseGraph"
		);
	}

	// A list of all output ports on the Input node, to be used in custom
	// auto flow port generation
	final outputPorts = LocalDynArray!(NodeParam)(stack);
	foreach (ref fromParam; *graph.getNode(input).getParamList()) {
		if (!fromParam.isInput) {
			outputPorts.pushBack(NodeParam(input, &fromParam));
		}
	}						

	bool isOutputNode(GraphNodeId id) {
		return KernelGraph.NodeType.Output == graph.getNode(id).type;
	}

	// Do auto flow for the second graph, extending the incoming flow of the
	// input node to the inputs of the output node from the first graph
	foreach (id; dstGraphTopological) {
		if (input == id) {
			foreach (outCon; graph.flow.iterOutgoingConnections(input)) {
				if (OutputNodeConversion.Perform == outNodeConversion || !isOutputNode(outCon)) {
					foreach (outFl; graph.flow.iterDataFlow(input, outCon)) {
						GraphNodeId	fromNode;
						Param*		fromParam;
						
						if (!_findSrcParam(
							outFl.from,
							&fromNode,
							&fromParam
						)) {
							assert (false);
						}

						doManualFlow(
							graph,
							fromNode, outCon,
							DataFlow(fromParam.name, outFl.to),
							semanticConverters,
							getKernel
						);
					}
				}
			}
		} else {
			doAutoFlow(
				graph,
				id,
				semanticConverters,
				getKernel,
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
							 * Input node, we will want to override it.
							 */
							if (input == fromId) {
								/* First, we figure out to which port auto
								 * flow would connect this param to, but we
								 * don't connect to it and instead dig deeper
								 */

								findAutoFlow(
									graph,
									outputPorts.data,
									id,
									toParam,
									semanticConverters,

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
												intermediateParam.name,
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

											assert (!fromParam.isInput);

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
									}
								);
							} else {
								/* Data flow from a node different than the
								 * Input node. Regular stuff
								 */
								
								final fromNode = graph.getNode(fromId);
								ParamList* fromParams = fromNode.getParamList();

								foreach (ref fromParam; *fromParams) {
									if (!fromParam.isInput) {
										incomingSink(NodeParam(fromId, &fromParam));
									}
								}
							}
						}
					}
				}
			);


			foreach (con; graph.flow.iterOutgoingConnections(id)) {
				simplifyParamSemantics(graph, id, getKernel);

				if (OutputNodeConversion.Perform == outNodeConversion || !isOutputNode(con)) {
					foreach (fl; graph.flow.iterDataFlow(id, con)) {
						doManualFlow(
							graph,
							id,
							con, fl,
							semanticConverters,
							getKernel
						);
					}
				}
			}
		}
	}

	graph.removeNode(input);
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
	SemanticConverterIter semanticConverters,
	KernelLookup getKernel,
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
		semanticConverters,
		getKernel,
		&iterGraph1Nodes
	);

	fuseGraph(
		graph,
		input,
		semanticConverters,
		getKernel,
		&iterGraph2Nodes,
		(
			cstring dstParam,
			GraphNodeId* srcNid,
			Param** srcParam
		) {
			/*
			 * We perform the lookup by name only (TODO?).
			 */

			return .findSrcParam(
				graph,
				output,
				dstParam,
				srcNid,
				srcParam
			);
		},
		outNodeConversion
	);

	graph.removeNode(output);
	graph.flow.removeAllAutoFlow();
}


void convertKernelNodesToFuncNodes(
	KernelGraph graph,
	Function delegate(cstring kname, cstring fname) getFuncImpl,
	bool delegate(cstring kname, cstring fname) filter = null
) {
	foreach (nid, ref node; graph.iterNodes(KernelGraph.NodeType.Kernel)) {
		final ndata = node.kernel();

		if (filter is null || filter(ndata.kernelName, ndata.funcName)) {
			final func = getFuncImpl(ndata.kernelName, ndata.funcName);
			
			if (func is null) {
				error(
					"Could not find a kernel func '{}'::'{}'",
					cast(char[])ndata.kernelName, cast(char[])ndata.funcName
				);
			}

			log.info("Got a func for kernel {}'s function {}", cast(char[])ndata.kernelName, cast(char[])ndata.funcName);
			foreach (p; func.params) {
				log.info("   param: {}", p.toString);
			}

			graph.resetNode(nid, KernelGraph.NodeType.Func);
			node.func.func = func;
			node.func.params = func.params.dup(&graph._mem.pushBack);
		}
	}
}


alias KernelDef delegate(cstring) KernelLookup;


enum FlowGenMode {
	InsertConversionNodes,
	DirectConnection,
	NoAction
}


struct NodeParam {
	GraphNodeId	node;
	Param*		param;
}


void verifyDataFlowNames(KernelGraph graph, KernelLookup getKernel) {
	final flow = graph.flow();
	
	foreach (fromId; graph.iterNodes) {
		final fromNode = graph.getNode(fromId);
		
		foreach (toId; flow.iterOutgoingConnections(fromId)) {
			final toNode = graph.getNode(toId);
			
			foreach (fl; flow.iterDataFlow(fromId, toId)) {
				final op = fromNode.getOutputParam(fl.from, getKernel);
				if (op is null) {
					error(
						"verifyDataFlowNames: The source node for flow {}->{}"
						" doesn't have an output parameter called '{}'",
						fromId.id, toId.id, fl.from
					);
				}
				assert (ParamDirection.Out == op.dir);

				final ip = toNode.getInputParam(fl.to, getKernel);
				if (ip is null) {
					error(
						"verifyDataFlowNames: The target node for flow {}->{}"
						" doesn't have an input parameter called '{}'",
						fromId.id, toId.id, fl.to
					);
				}
				assert (ParamDirection.In == ip.dir);
				assert (ip.hasPlainSemantic);
			}
		}
	}

	scope stack = new StackBuffer;

	foreach (toId; graph.iterNodes) {
		final toNode = graph.getNode(toId);
		ParamList* plist;
		
		if (KernelGraph.NodeType.Kernel == toNode.type) {
			plist = &getKernel(toNode.kernel.kernelName)
				.getFunction(toNode.kernel.funcName).params;
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


private void _insertConversionNodes(
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
		assert (!cnode.func.params[1].isInput);
		
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

		srcId = cnodeId;
		srcParam = cnode.params[1];
	}

	graph.flow.addDataFlow(
		srcId,
		srcParam.name,
		toId,
		toParam.name
	);
}


private void findAutoFlow(
	KernelGraph graph,
	NodeParam[] fromParams,
	GraphNodeId toId,
	Param* toParam,
	SemanticConverterIter semanticConverters,
	void delegate(
			ConvSinkItem[] convChain,
			GraphNodeId fromId,
			Param* fromParam
	) result
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
		
		assert (!fromParam.isInput);
		
		int convCost = 0;

		assert (toParam.isInput);
		assert (fromParam.hasPlainSemantic);
		assert (toParam.hasPlainSemantic);
		
		findConversion(
			*fromParam.semantic,
			*toParam.semantic,
			semanticConverters,
			stack2,
			(ConvSinkItem[] convChain) {
				if (convCost > bestCost) {
					return;
				}
				
				stack2.mergeWith(stack);
				final info = stack.alloc!(ConvInfo)(
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
	} else {
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

		error(
			"Auto flow not found for an input param"
			" '{}' in graph node {}.\n"
			"Considered {} converters from:\n[{}]",
			toParam.toString, toId.id, numConv, suffix
		);
	}
}


private void simplifyParamSemantics(KernelGraph graph, GraphNodeId id, KernelLookup getKernel) {
	final node = graph.getNode(id);

	if (KernelGraph.NodeType.Kernel == node.type) {
		auto kernel = getKernel(node.kernel.kernelName);
		foreach (ref Param par; kernel.getFunction(node.kernel.funcName).params) {
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

					assert (fromName !is null, "No flow D:");
					return *graph.getNode(fromId)
						.getOutputParam(fromName, getKernel).semantic();
				},
				
				&plainSem
			);

			par.hasPlainSemantic = true;
			*par.semantic() = plainSem;
		}

		foreach (ref Param par; *params) {
			if (!par.isInput) {
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

			assert (fromName !is null, "No flow D:");
			final srcParam = graph.getNode(fromId)
				.getOutputParam(fromName, getKernel);

			/+assert (srcParam.hasPlainSemantic);
			*toParam.semantic() = srcParam.semantic().dup(&graph._mem.pushBack);+/

			*par.semantic() = *srcParam.semantic();
		}
	}
}


private void doAutoFlow(
		KernelGraph graph,
		GraphNodeId toId,
		SemanticConverterIter semanticConverters,
		KernelLookup getKernel,
		FlowGenMode flowGenMode
) {
	return doAutoFlow(
		graph,
		toId,
		semanticConverters,
		getKernel,
		flowGenMode,
		(Param*, void delegate(NodeParam) incomingSink) {
			foreach (fromId; graph.flow.iterIncomingConnections(toId)) {
				if (graph.flow.hasAutoFlow(fromId, toId)) {
					final fromNode = graph.getNode(fromId);
					ParamList* fromParams = fromNode.getParamList();

					foreach (ref fromParam; *fromParams) {
						if (!fromParam.isInput) {
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
		SemanticConverterIter semanticConverters,
		KernelLookup getKernel,
		FlowGenMode flowGenMode,
		void delegate(Param*, void delegate(NodeParam)) incomingGen
) {
	scope stack = new StackBuffer;

	ParamList* plist = void;
	final toNode = graph.getNode(toId);
	switch (toNode.type) {
		case KernelGraph.NodeType.Func: {
			plist = &toNode.func.func.params;
		} break;

		case KernelGraph.NodeType.Output: {
			plist = &toNode.output.params;
		} break;

		case KernelGraph.NodeType.Kernel: {
			plist = &getKernel(toNode.kernel.kernelName)
				.getFunction(toNode.kernel.funcName).params;
		} break;

		default: return;		// just outputs here
	}

	DynamicBitSet portHasDataFlow;
	portHasDataFlow.alloc(plist.length, (uword num) { return stack.allocRaw(num); });
	portHasDataFlow.clearAll();

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

			findAutoFlow(graph, fromIds.data, toId, &param, semanticConverters,
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


private void doManualFlow(
		KernelGraph graph,
		GraphNodeId fromId,
		GraphNodeId toId,
		DataFlow fl,
		SemanticConverterIter semanticConverters,
		KernelLookup getKernel
) {
	scope stack = new StackBuffer;

	final fromParam = graph.getNode(fromId).getOutputParam(fl.from, getKernel);
	assert (fromParam !is null);
	assert (fromParam.hasPlainSemantic);
	
	final toParam = graph.getNode(toId).getInputParam(fl.to, getKernel);
	assert (toParam !is null);
	assert (toParam.hasPlainSemantic);

	if (!findConversion(
		*fromParam.semantic,
		*toParam.semantic,
		semanticConverters,
		stack,
		(ConvSinkItem[] convChain) {
			_insertConversionNodes(
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
			"  {}:{} -> {}:{}",
			fromId.id, fromParam.toString,
			toId.id, toParam.toString
		);
	}
}



// Assumes the consists of param/calc nodes only
void convertGraphDataFlow(
	KernelGraph graph,
	SemanticConverterIter semanticConverters,
	KernelLookup getKernel
) {
	scope stack = new StackBuffer;

	final topological = stack.allocArray!(GraphNodeId)(graph.numNodes);
	findTopologicalOrder(graph.backend_readOnly, topological);

	return convertGraphDataFlow(graph, semanticConverters, getKernel, topological);
}


void convertGraphDataFlow(
	KernelGraph graph,
	SemanticConverterIter semanticConverters,
	KernelLookup getKernel,
	GraphNodeId[] topological
) {
	foreach (id; topological) {
		doAutoFlow(
			graph,
			id,
			semanticConverters,
			getKernel,
			FlowGenMode.InsertConversionNodes
		);

		simplifyParamSemantics(graph, id, getKernel);
		
		foreach (con; graph.flow.iterOutgoingConnections(id)) {
			foreach (fl; graph.flow.iterDataFlow(id, con)) {
				doManualFlow(
					graph,
					id,
					con, fl,
					semanticConverters,
					getKernel
				);
			}
		}
	}

	// NOTE: this was removed, m'kay?
	//graph.flow.removeAllAutoFlow();
}



void convertGraphDataFlowExceptOutput(
	KernelGraph graph,
	SemanticConverterIter semanticConverters,
	KernelLookup getKernel
) {
	scope stack = new StackBuffer;

	final topological = stack.allocArray!(GraphNodeId)(graph.numNodes);
	findTopologicalOrder(graph.backend_readOnly, topological);

	return convertGraphDataFlowExceptOutput(graph, semanticConverters, getKernel, topological);
}


void convertGraphDataFlowExceptOutput(
	KernelGraph graph,
	SemanticConverterIter semanticConverters,
	KernelLookup getKernel,
	GraphNodeId[] topological
) {
	return convertGraphDataFlowExceptOutput(
		graph,
		semanticConverters,
		getKernel,
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
	SemanticConverterIter semanticConverters,
	KernelLookup getKernel,
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
			semanticConverters,
			getKernel,
			isOutputNode(id)
				? FlowGenMode.DirectConnection
				: FlowGenMode.InsertConversionNodes
		);
		
		simplifyParamSemantics(graph, id, getKernel);

		foreach (con; graph.flow.iterOutgoingConnections(id)) {
			if (!isOutputNode(con)) {
				foreach (fl; graph.flow.iterDataFlow(id, con)) {
					doManualFlow(
						graph,
						id,
						con, fl,
						semanticConverters,
						getKernel
					);
				}
			}
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
		if (i > 3 || (i <= 1 && !p.isInput) || (2 == i && p.isInput)) {
			error(
				"reduceGraphData: '{}' is not a valid reduction func.",
				reductionFunc.name
			);
		}
		
		if (!p.isInput) {
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
				final rnid = kg.addNode(KernelGraph.NodeType.Func);
				final rnode = kg.getNode(rnid);
				rnode.func.func = reductionFunc;
				rnode.func.params = reductionFunc.params.dup(&kg._mem.pushBack);

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
