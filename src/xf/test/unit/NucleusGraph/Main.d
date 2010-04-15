module Main;

import tango.core.tools.TraceExceptions;

import xf.Common;
import xf.nucleus.Graph;
import xf.nucleus.GraphMisc;
import tango.io.Stdout;
import tango.io.device.File : File;
import tango.text.convert.Format;
import tango.math.random.Kiss;



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

		File.set("g2d.dot", toGraphviz(g2));
	}

	Stdout.formatln("Test passed!");
}
