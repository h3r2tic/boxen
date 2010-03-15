module xf.boxen.Log;

private {
	import xf.utils.Log;
	import xf.utils.Error;
}


mixin(createLoggerMixin("boxenLog"));
mixin(createErrorMixin("BoxenException", "boxenError"));
