module Main;

import tango.core.tools.TraceExceptions;

import xf.Common;
import xf.nucleus.Graph;
import tango.io.Stdout;
import tango.text.convert.Format;
import tango.math.random.Kiss;



void main() {
	auto g1 = createGraph();
	scope (exit) disposeGraph(g1);

	enum {
		numNodes = 160,		// around 160 nodes are max with chunks at 4kB
							// TODO: break-up the auto-connection matrix
		numConnections = 0
	}
	
	GraphNodeId[] nodeIds;

	for (int i = 0; i < numNodes; ++i) {
		nodeIds ~= g1.addNode();
	}

	for (int i = 0; i < numConnections; ++i) {
		int from = Kiss.instance.natural() % numNodes;
		int to = from;
		while (to == from) {
			to = Kiss.instance.natural() % numNodes;
		}

		g1.addDataFlow(nodeIds[from], "foo", nodeIds[to], "bar");
	}

	Stdout.formatln("Mem usage before minimization: {}", g1.countUsedBytes);
	g1.minimizeMemoryUsage();
	Stdout.formatln("Mem usage after minimization: {}", g1.countUsedBytes);

	Stdout.formatln("Test passed!");
}
