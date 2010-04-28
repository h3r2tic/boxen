module xf.hybrid.Log;

private {
	import xf.utils.Log;
	import xf.utils.Error;
}


mixin(createLoggerMixin("hybridLog"));
mixin(createErrorMixin("HybridException", "hybridError"));
