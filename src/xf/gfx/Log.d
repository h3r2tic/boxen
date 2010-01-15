module xf.gfx.Log;

private {
	import xf.Common;
	import xf.utils.Log;
	import tango.util.log.model.ILogger;
	import tango.text.convert.Format;
}


mixin(createLoggerMixin("gfxLog"));

class GfxException : Exception {
	this (cstring msg) {
		super(msg);
	}
}

void gfxError(cstring fmt, ...) {
	char[256] buffer;
	cstring msg = Format.vprint(buffer, fmt, _arguments, _argptr);
	throw new GfxException(msg.dup);
}
