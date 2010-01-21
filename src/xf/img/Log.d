module xf.img.Log;

private {
	import xf.utils.Log;
	import xf.utils.Error;
}


mixin(createLoggerMixin("imgLog"));
mixin(createErrorMixin("ImgException", "imgError"));
