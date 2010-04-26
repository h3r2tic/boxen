module xf.hybrid.HybridException;

private {
	import tango.text.convert.Format;
}


class HybridException : Exception {
	this(char[] msg) {
		super(msg);
	}
}


void hybridThrow(char[] formatStr, ...) {
	throw new HybridException(Format.convert(_arguments, _argptr, formatStr));
}
