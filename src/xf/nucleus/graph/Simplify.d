module xf.nucleus.graph.Simplify;

private {
	import xf.Common;
	import xf.nucleus.graph.KernelGraph;
}



/**
 * Removes duplicate Func nodes
 * Note: does not consider auto flow at all.
 * Note: turns the removed node ids into GraphNodeId.init
 */
void simplifyKernelGraph(KernelGraph graph, GraphNodeId[] topological) {
	alias KernelGraph.NodeType NT;

	foreach (nidx, nid; topological) {
		final node = graph.getNode(nid);
		if (NT.Func != node.type) {
			continue;
		}

		struct ParamSrc {
			GraphNodeId	node;
			cstring		name;
		}

		// TODO: mem
		ParamSrc[cstring] paramSrc;
		foreach (from; graph.flow.iterIncomingConnections(nid)) {
			foreach (fl; graph.flow.iterDataFlow(from, nid)) {
				paramSrc[fl.to] = ParamSrc(
					from,
					fl.from
				);
			}
		}

		// TODO: This has O(n^2) complexity, maybe figure out something else
		if (nidx > 0)
		candidateIter: foreach (ref nid2; topological[0..nidx]) {
			if (!nid2.valid) {
				continue;
			}

			assert (nid != nid2);
			
			final node2 = graph.getNode(nid2);
			if (NT.Func != node2.type) {
				continue candidateIter;
			}

			if (node.func.func !is node2.func.func) {
				continue candidateIter;
			}

			foreach (from; graph.flow.iterIncomingConnections(nid2)) {
				foreach (fl; graph.flow.iterDataFlow(from, nid2)) {
					if (auto src = fl.to in paramSrc) {
						if (from != src.node || fl.from != src.name) {
							continue candidateIter;
						}
					} else {
						assert (false, "Wat? No flow to a param?");
					}
				}
			}

			// Can replace the nid2 node with the nid node \o/

			// TODO: Reuse the connections instead of creating new ones
			{
				foreach (to; graph.flow.iterOutgoingConnections(nid2)) {
					foreach (fl; graph.flow.iterDataFlow(nid2, to)) {
						graph.flow.addDataFlow(nid, fl.from, to, fl.to);
					}
				}

				graph.removeNode(nid2);
				nid2 = GraphNodeId.init;
			}
		}
	}
}
