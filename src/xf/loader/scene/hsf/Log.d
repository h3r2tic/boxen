module xf.loader.scene.hsf.Log;

private {
	import xf.utils.Log;
	import xf.utils.Error;
}


mixin(createLoggerMixin("hsfLog"));
mixin(createErrorMixin("HsfException", "hsfError"));
