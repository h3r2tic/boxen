module Main;

import tango.core.tools.TraceExceptions;

import xf.Common;
import xf.nucleus.graph.Graph;
import xf.nucleus.graph.GraphOps;
import xf.nucleus.graph.GraphMisc;
import tango.io.Stdout;
import tango.io.device.File : File;
import tango.text.convert.Format;
import tango.math.random.Kiss;



void checkOrder(Graph g, int[] order ...) {
	final output = new GraphNodeId[g.numNodes];
	assert (output.length == order.length);
	findTopologicalOrder(g, output);
	foreach (i, n; output) {
		if (n.id != order[i]) {
			cstring err = "Invalid topological order received:\n";
			foreach (n2; output) {
				err ~= Format(" {}", n2.id);
			}
			assert (false, err);
		}
	}
}


void main() {
	{
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
	}

	{
		auto g2 = createGraph();
		scope (exit) disposeGraph(g2);

		GraphNodeId[] n;
		for (int i = 0; i < 10; ++i) {
			n ~= g2.addNode();
		}

		// g2
		/* 0       1 2
		 * o-------o-o
		 *  \     /   \
		 *   >o--o---o-o--o--o
		 *  / 3  4   5 6  7  8
		 * o
		 * 9
		 */

		void fl(int from, int to) {
			g2.addDataFlow(n[from], "foo", n[to], "bar");
		}

		fl(0, 1);
		fl(0, 3);
		fl(1, 2);
		fl(2, 6);
		fl(3, 4);
		fl(4, 1);
		fl(4, 5);
		fl(5, 6);
		fl(6, 7);
		fl(7, 8);
		fl(9, 3);

		checkOrder(g2, 0, 9, 3, 4, 1, 5, 2, 6, 7, 8);

		File.set("g2.dot", toGraphviz(g2));

		// ----
		
		// g2b
		/* 0       1 2
		 * o-------o-o
		 *  \     /   \
		 *   >o--o     o--o--o
		 *    3  4     6  7  8
		 */

		g2.removeNode(n[5]);
		g2.removeNode(n[9]);

		checkOrder(g2, 0, 3, 4, 1, 2, 6, 7, 8);

		File.set("g2b.dot", toGraphviz(g2));

		// ----

		// g2c
		/* 0       1 2
		 * o-------o-o
		 *            \
		 *             o--o--o
		 *             6  7  8
		 */

		g2.removeNode(n[3]);
		g2.removeNode(n[4]);

		checkOrder(g2, 0, 1, 2, 6, 7, 8);

		File.set("g2c.dot", toGraphviz(g2));

		// ----

		// g2d
		/* 0       1
		 * o-------o
		 */

		g2.removeNode(n[2]);
		g2.removeNode(n[8]);
		g2.removeNode(n[7]);
		g2.removeNode(n[6]);

		checkOrder(g2, 0, 1);

		File.set("g2d.dot", toGraphviz(g2));
	}

	{
		auto g3 = createGraph();
		scope (exit) disposeGraph(g3);

		GraphNodeId[] n;
		for (int i = 0; i < 10; ++i) {
			n ~= g3.addNode();
		}

		// g3 == g2
		/* 0       1 2
		 * o-------o-o
		 *  \     /   \
		 *   >o--o---o-o--o--o
		 *  / 3  4   5 6  7  8
		 * o
		 * 9
		 */

		void fl2(int from, int to) {
			g3.addAutoFlow(n[from], n[to]);
		}

		fl2(0, 1);
		fl2(0, 3);
		fl2(1, 2);
		fl2(2, 6);
		fl2(3, 4);
		fl2(4, 1);
		fl2(4, 5);
		fl2(5, 6);
		fl2(6, 7);
		fl2(7, 8);
		fl2(9, 3);

		checkOrder(g3, 0, 9, 3, 4, 1, 5, 2, 6, 7, 8);

		File.set("g3.dot", toGraphviz(g3));

		g3.removeNode(n[5]);
		g3.removeNode(n[9]);

		checkOrder(g3, 0, 3, 4, 1, 2, 6, 7, 8);
	}

	{
		auto g4 = createGraph();
		scope (exit) disposeGraph(g4);

		GraphNodeId[] n;
		for (int i = 0; i < 10; ++i) {
			n ~= g4.addNode();
		}

		// g4 == g2
		/* 0       1 2
		 * o-------o-o
		 *  \     /   \
		 *   >o--o---o-o--o--o
		 *  / 3  4   5 6  7  8
		 * o
		 * 9
		 */

		g4.addAutoFlow(n[0], n[1]);
		g4.addDataFlow(n[0], "foo", n[3], "bar");
		g4.addAutoFlow(n[1], n[2]);
		g4.addAutoFlow(n[2], n[6]);
		g4.addDataFlow(n[3], "foo", n[4], "bar");
		g4.addAutoFlow(n[4], n[1]);
		g4.addDataFlow(n[4], "foo", n[5], "bar");
		g4.addDataFlow(n[5], "foo", n[6], "bar");
		g4.addAutoFlow(n[6], n[7]);
		g4.addDataFlow(n[7], "foo", n[8], "bar");
		g4.addAutoFlow(n[9], n[3]);

		checkOrder(g4, 0, 9, 3, 4, 1, 5, 2, 6, 7, 8);

		File.set("g4.dot", toGraphviz(g4));

		g4.removeNode(n[5]);
		g4.removeNode(n[9]);

		checkOrder(g4, 0, 3, 4, 1, 2, 6, 7, 8);
	}

	{
		auto g5 = createGraph();
		scope (exit) disposeGraph(g5);

		GraphNodeId[] n;
		for (int i = 0; i < 10; ++i) {
			n ~= g5.addNode();
		}

		// g5 == g2
		/* 0       1 2
		 * o-------o-o
		 *  \     /   \
		 *   >o--o---o-o--o--o
		 *  / 3  4   5 6  7  8
		 * o
		 * 9
		 */

		g5.addAutoFlow(n[0], n[1]);
		g5.addDataFlow(n[0], "foo", n[3], "bar");
		g5.addAutoFlow(n[1], n[2]);
		g5.addAutoFlow(n[2], n[6]);
		g5.addDataFlow(n[3], "foo", n[4], "bar");
		g5.addAutoFlow(n[4], n[1]);
		g5.addDataFlow(n[4], "foo", n[5], "bar");
		g5.addDataFlow(n[5], "foo", n[6], "bar");
		g5.addAutoFlow(n[6], n[7]);
		g5.addDataFlow(n[7], "foo", n[8], "bar");
		g5.addAutoFlow(n[9], n[3]);

		removeUnreachableBackwards(g5, n[5]);

		// should get reduced to:
		/* 0
		 * o
		 *  \
		 *   >o--o---o
		 *  / 3  4   5
		 * o
		 * 9
		 */

		checkOrder(g5, 0, 9, 3, 4, 5);
	}

	Stdout.formatln("Test passed!");
}
