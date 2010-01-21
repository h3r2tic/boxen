module xf.test.Common;

private {
	import tango.time.StopWatch;
	import tango.core.Thread;
	
	static import xf.utils.impl.Log;
}

public {
	import tango.util.log.Trace;
	import tango.text.convert.Format;
}



void measure(void delegate() dg, int iters, int threads, char[] info) {
	if (threads > 32) {
		throw new Exception(Format("Uh, you probably meant {} iters, not threads", threads));
	}
	
	StopWatch t;
	if (iters != 1) {
		Trace.formatln("Testing {} in {} threads, {} iterations each", info, threads, iters);
	} else {
		Trace.formatln("Testing {} in {} threads", info, threads);
	}
	t.start;
	
	struct ThreadWrap {
		void delegate() dg;
		int iters;
		
		void run() {
			for (int i = 0; i < iters; ++i) {
				dg();
			}
		}
	}
	
	ThreadWrap[] thFuncs;
	
	while (threads--) {
		thFuncs ~= ThreadWrap(dg, iters);
	}
	
	foreach (ref th; thFuncs) {
		(new Thread(&th.run)).start();
	}
	
	thread_joinAll();
	
	Trace.formatln("Done in {} sec.", t.stop);
	Trace.formatln("");
}


void assertEqual(T)(T a, T b) {
	if (a != b) {
		throw new Exception(Format(
			"assertEqual failed: {} != {}", a, b
		));
	}
}
