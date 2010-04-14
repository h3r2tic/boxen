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
		numConnections = 500
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

		cstring fromPort = "foo";
		cstring toPort = "bar";

		auto fl = g1.addDataFlow(nodeIds[from], fromPort, nodeIds[to], toPort);

		assert (fl.from == fromPort);
		assert (fl.to == toPort);

		// check that it reallocates properly
		assert (fl.from !is fromPort);
		assert (fl.to !is toPort);
	}

	{
		int i = 0;
		foreach (n; g1.iterNodes) {
			assert (n is nodeIds[i], Format("Node id mismatch at {}", i));
			++i;
		}
	}

	Stdout.formatln("Mem usage before minimization: {}", g1.countUsedBytes());
	g1.minimizeMemoryUsage();
	Stdout.formatln("Mem usage after minimization: {}", g1.countUsedBytes());

	foreach (n; nodeIds) {
		g1.removeNode(n);
	}
	assert (0 == g1.numNodes);

	g1.minimizeMemoryUsage();
	assert (0 == g1.countUsedBytes());

	Stdout.formatln("Test passed!");
}
