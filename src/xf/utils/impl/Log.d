module xf.utils.impl.Log;

private {
	import xf.Common;
	import tango.util.log.model.ILogger;
	import tango.util.log.Log : TangoLog = Log, Level;
	import tango.io.Stdout;
}



static this() {
	TangoLog.config(Stdout);
}


extern (C) ILogger _xf_createLogger(cstring name) {
	final res = TangoLog.lookup(name);
	res.level(Level.Trace, true);
	return res;
}
