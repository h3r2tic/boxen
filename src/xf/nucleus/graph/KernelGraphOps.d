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

	import xf.nucleus.Log : error = nucleusError;
}



void convertKernelNodesToFuncNodes(
	KernelGraph graph,
	Function delegate(cstring kname, cstring fname) getFuncImpl
) {
	foreach (nid, node; graph.iterNodes(KernelGraph.NodeType.Kernel)) {
		final ndata = node.kernel();
		final func = getFuncImpl(ndata.kernelName, ndata.funcName);
		
		if (func is null) {
			error(
				"Could not find a kernel func '{}'::'{}'",
				ndata.kernelName, ndata.funcName
			);
		}

		graph.resetNode(nid, KernelGraph.NodeType.Func);
		node.func.func = func;		// lolz
	}
}


void verifyDataFlowNames(KernelGraph graph) {
	final flow = graph.flow();
	
	foreach (fromId; graph.iterNodes) {
		final fromNode = graph.getNode(fromId);
		
		foreach (toId; flow.iterOutgoingConnections(fromId)) {
			final toNode = graph.getNode(toId);
			
			foreach (fl; flow.iterDataFlow(fromId, toId)) {
				if (fromNode.getOutputParam(fl.from) is null) {
					error(
						"verifyDataFlowNames: The source node for flow {}->{}"
						" doesn't have an output parameter called '{}'",
						fromId.id, toId.id, fl.from
					);
				}

				if (toNode.getInputParam(fl.to) is null) {
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
		final fromNode = graph.getNode(fromId);
		ParamList* fromParams = fromNode.getParamList();

		scope stack2 = new StackBuffer;
		
		foreach (ref fromParam; *fromParams) {
			int convCost = 0;
			
			findConversion(
				*fromParam.semantic,
				*toParam.semantic,
				semanticConverters,
				stack2,
				(ConvSinkItem[] convChain) {
					if (convCost > bestCost) {
						return;
					}
					
					stack2.forgetMemory();
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
			
			alias bestConvs conv;

			GraphNodeId	srcId		= conv.fromId;
			Param*		srcParam	= conv.fromParam;
			
			foreach (c; conv.chain) {
				final cnodeId = graph.addNode(KernelGraph.NodeType.Func);
				final cnode = graph.getNode(cnodeId).func();
				cnode.func = c.converter.func;

				assert (cnode.func.params[0].isInput);
				assert (!cnode.func.params[1].isInput);
				
				graph.flow.addDataFlow(
					srcId,
					srcParam.name,
					cnodeId,
					cnode.func.params[0].name
				);
				
				srcId = cnodeId;
				srcParam = cnode.func.params[1];
			}

			graph.flow.addDataFlow(
				srcId,
				srcParam.name,
				toId,
				toParam.name
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
			"Considered {} converters and the following nodes:\n{}",
			toParam.toString, toId.id, numConv, suffix
		);
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
			if (!portHasDataFlow.isSet(paramI)) {
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
		
		// TODO
	}

	void doManualFlow(GraphNodeId fromId, GraphNodeId toId, DataFlow fl) {
		// TODO
	}

	foreach (id; topological) {
		doAutoFlow(id);
		foreach (con; graph.flow.iterOutgoingConnections(id)) {
			foreach (fl; graph.flow.iterDataFlow(id, con)) {
				doManualFlow(id, con, fl);
			}
		}
	}
}
