module xf.utils.FormatTmp;

private {
	import xf.Common;

	static import tango.io.stream.Format;
	static import tango.text.convert.Format;
	static import tango.io.device.Array;
}

alias tango.io.stream.Format.FormatOutput!(char) Fmt;

void formatTmp(
	void delegate(Fmt) fmtCB,
	void delegate(cstring) sinkCB,
	int bufSize = 256
) {
	cstring mem = (cast(char*)alloca(bufSize))[0..bufSize];
	
	auto layout = tango.text.convert.Format.Layout!(char).instance;
	scope arrrr = new tango.io.device.Array.Array(mem, 0);

	{
		scope fmt = new Fmt(layout, arrrr, "\n");
		fmtCB(fmt);
		fmt.flush();
	}

	sinkCB(cast(char[])arrrr.slice());
}
