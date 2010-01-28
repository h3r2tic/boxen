module xf.loader.Log;

private {
	import xf.utils.Log;
	import xf.utils.Error;
}


mixin(createLoggerMixin("loaderLog"));
mixin(createErrorMixin("LoaderException", "loaderError"));
