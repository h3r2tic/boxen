module xf.nucleus.graph.KernelGraphOps;

private {
	import xf.Common;
	import xf.nucleus.Function;
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



void convertKernelNodesToFuncNodes(
	KernelGraph graph,
	Function delegate(cstring kname, cstring fname) getFuncImpl
) {
	foreach (nid, ref node; graph.iterNodes(KernelGraph.NodeType.Kernel)) {
		final ndata = node.kernel();
		final func = getFuncImpl(ndata.kernelName, ndata.funcName);
		
		if (func is null) {
			error(
				"Could not find a kernel func '{}'::'{}'",
				ndata.kernelName, ndata.funcName
			);
		}

		graph.resetNode(nid, KernelGraph.NodeType.Func);
		node.func.func = func;
		node.func.params = func.params.dup(&graph._mem.pushBack);
	}
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
				assert (ParamDirection.Out == op.dir);

				final ip = toNode.getInputParam(fl.to);
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
		ParamList* plist = toNode.getParamList();

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
	GraphNodeId[] fromIds,
	GraphNodeId toId,
	Param* toParam,
	SemanticConverterIter semanticConverters
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
	
	foreach (fromId; fromIds) {
		log.trace("findAutoFlow {} -> {}", fromId.id, toId.id);

		final fromNode = graph.getNode(fromId);
		ParamList* fromParams = fromNode.getParamList();

		scope stack2 = new StackBuffer;
		
		foreach (ref fromParam; *fromParams) {
			if (fromParam.isInput) {
				continue;
			}
			
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
						&fromParam,
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

			log.info("Found a conversion path. Inserting nodes.");

			_insertConversionNodes(
				graph,
				bestConvs.chain,
				bestConvs.fromId, bestConvs.fromParam,
				toId, toParam
			);
		}
	} else {
		// Conversion path not found
		
		cstring suffix;
		foreach (id; fromIds) {
			if (suffix is null) {
				suffix = Format("{}", id.id);
			} else {
				suffix ~= Format(", {}", id.id);
			}
		}

		uword numConv = 0;
		foreach (conv; semanticConverters) {
			++numConv;
		}

		error(
			"Auto flow not found for an input param"
			" '{}' in graph node {}.\n"
			"Considered {} converters and the following nodes:\n[{}]",
			toParam.toString, toId.id, numConv, suffix
		);
	}
}


private void simplifyParamSemantics(KernelGraph graph, GraphNodeId id) {
	final node = graph.getNode(id);
	if (KernelGraph.NodeType.Func == node.type) {
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
					return *graph.getNode(fromId).getOutputParam(fromName).semantic();
				},
				
				&plainSem
			);

			par.hasPlainSemantic = true;
			*par.semantic() = plainSem;
		}
	}
}


// Assumes the consists of param/calc nodes only
void convertGraphDataFlow(
	KernelGraph graph,
	SemanticConverterIter semanticConverters
) {
	scope stack = new StackBuffer;

	final topological = stack.allocArray!(GraphNodeId)(graph.numNodes);
	findTopologicalOrder(graph.backend_readOnly, topological);


	void doAutoFlow(GraphNodeId toId) {
		ParamList* plist = void;
		final toNode = graph.getNode(toId);
		switch (toNode.type) {
			case KernelGraph.NodeType.Func: {
				plist = &toNode.func.func.params;
			} break;

			case KernelGraph.NodeType.Output: {
				plist = &toNode.output.params;
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
				
				final fromIds = LocalDynArray!(GraphNodeId)(stack2);

				foreach (fromId; graph.flow.iterIncomingConnections(toId)) {
					if (graph.flow.hasAutoFlow(fromId, toId)) {
						fromIds.pushBack(fromId);
					}
				}

				findAutoFlow(graph, fromIds.data, toId, &param, semanticConverters);
			}
		}		
	}

	void doManualFlow(GraphNodeId fromId, GraphNodeId toId, DataFlow fl) {
		scope stack = new StackBuffer;

		final fromParam = graph.getNode(fromId).getOutputParam(fl.from);
		assert (fromParam !is null);
		
		final toParam = graph.getNode(toId).getInputParam(fl.to);
		assert (toParam !is null);

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

	foreach (id; topological) {
		doAutoFlow(id);
		foreach (con; graph.flow.iterOutgoingConnections(id)) {
			foreach (fl; graph.flow.iterDataFlow(id, con)) {
				doManualFlow(id, con, fl);
			}
		}
		simplifyParamSemantics(graph, id);
	}

	graph.flow.removeAllAutoFlow();
}
