module xf.utils.impl.Log;

private {
	import xf.Common;
	import tango.util.log.model.ILogger;
	import tango.util.log.Log : TangoLog = Log;
}



extern (C) ILogger _xf_createLogger(cstring name) {
	return TangoLog.lookup(name);
}
