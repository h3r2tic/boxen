module Main;

import xf.test.Common;

import xf.mem.StackBuffer;
import tango.stdc.stdlib;


void main() {
	const int numTests = 2_000_000;
	
	Trace.formatln("Testing {} local data (stack-able) allocations", numTests);
	Trace.formatln("");
	
	const size_t chunkSize = 16 * 1024;
	
	for (int i = 1; i <= 4; i *= 2) {
		//for (int j = 0; j < 2; ++j) {
			// The extra inline delegate in each of these tests is needed for alloca()'s sake, as it
			// causes a stack overflow without it. It's also present in the other tests for fairness.
			// the comparison and exception is there so the code is not optimized-out
			
			measure({
				for (int x = 0; x < numTests; ++x) {
					({
						auto ptr = alloca(chunkSize / i);
						if (cast(size_t)ptr == size_t.max) {
							throw new Exception("this should never happen");
						}
					})();
				}
			}, 1, i, "alloca");

			measure({
				for (int x = 0; x < numTests; ++x) {
					({
						if (StackBuffer.bytesUsed != 0) {
							throw new Exception("stack buffer cleanup failed");
						}
						
						scope buf = new StackBuffer;
						auto ptr = buf.allocArrayNoInit!(ubyte)(chunkSize / i);
						if (cast(size_t)ptr.ptr == size_t.max) {
							throw new Exception("this should never happen");
						}
					})();
				}
				
				StackBuffer.releaseThreadData();
			}, 1, i, "StackBuffer");

			measure({
				for (int x = 0; x < numTests; ++x) {
					({
						auto ptr = new byte[](chunkSize / i);
						if (cast(size_t)ptr.ptr == size_t.max) {
							throw new Exception("this should never happen");
						}
						delete ptr;
					})();
				}
			}, 1, i, "new");
		//}
	}
}
