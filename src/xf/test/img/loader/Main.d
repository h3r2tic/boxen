module Main;

import
	tango.core.tools.StackTrace,
	xf.Common,
	xf.test.Common,
	xf.img.Image,
	xf.img.FreeImageLoader;

void main() {
	scope loader = new FreeImageLoader;
	final img = loader.load("../../media/img/Walk_Of_Fame/Mans_Outside_2k.hdr");
	assert (img.valid);

	Trace.formatln("Loaded {}", img);
	img.dispose();
}

