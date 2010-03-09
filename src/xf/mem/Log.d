module xf.mem.Log;

private {
	import xf.utils.Log;
	import xf.utils.Error;
}


mixin(createLoggerMixin("memLog"));
mixin(createErrorMixin("MemException", "memError"));
