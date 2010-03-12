module xf.net.Log;

private {
	import xf.utils.Log;
	import xf.utils.Error;
}


mixin(createLoggerMixin("netLog"));
mixin(createErrorMixin("NetException", "netError"));
