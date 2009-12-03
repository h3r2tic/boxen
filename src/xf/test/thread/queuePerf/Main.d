module Main;

import xf.test.Common;

import xf.mem.ChunkQueue;
import tango.util.container.more.Vector;


void main() {
	const int numTests = 1_000_000;
	const int chunkSize = 4 * 1024;
	
	Trace.formatln("Testing simple queue allocation and release performance for {} items", numTests);
	Trace.formatln("");
	
	for (int i = 1; i <= 4; i *= 2) {
		measure({
			ChunkQueue!(int) q;
			for (int x = 0; x < numTests; ++x) {
				q ~= x;
			}
			q.clear();
		}, 1, i, "ChunkQueue");

		measure({
			int[] q;
			for (int x = 0; x < numTests; ++x) {
				q ~= x;
			}
			delete q;
		}, 1, i, "naive new");

		measure({
			Vector!(int) q;
			for (int x = 0; x < numTests; ++x) {
				q.add(x);
			}
			q.clear();
		}, 1, i, "Tango's Vector");
	}
}
