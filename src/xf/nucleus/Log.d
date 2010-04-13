module xf.nucleus.Log;

private {
	import xf.utils.Log;
	import xf.utils.Error;
}


mixin(createLoggerMixin("nucleusLog"));
mixin(createErrorMixin("NucleusException", "nucleusError"));
