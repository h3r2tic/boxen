module xf.test.Common;

private {
	import tango.time.StopWatch;
	import tango.core.Thread;
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
	Trace.formatln("Testing {} in {} threads, {} iterations each", info, threads, iters);
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
