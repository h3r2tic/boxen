module xf.gfx.Log;

private {
	import xf.utils.Log;
	import xf.utils.Error;
}


mixin(createLoggerMixin("gfxLog"));
mixin(createErrorMixin("GfxException", "gfxError"));
