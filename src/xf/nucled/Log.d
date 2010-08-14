module xf.nucled.Log;

private {
	import xf.utils.Log;
	import xf.utils.Error;
}


mixin(createLoggerMixin("nucledLog"));
mixin(createErrorMixin("NucledException", "nucledError"));
