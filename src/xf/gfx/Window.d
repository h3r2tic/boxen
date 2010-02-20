module xf.gfx.Window;

public {
	import xf.omg.core.LinearAlgebra : vec2i;
}

private {
	import xf.input.Input : InputChannel;
}



abstract class Window {
abstract:
	Window	create();
	Window	destroy();
	
	bool	created();
	
	Window	width(uint w);
	uint	width();
	
	Window	height(uint h);
	uint	height();
	
	Window	depthBits(uint d);
	uint	depthBits();
	
	Window	stencilBits(uint s);
	uint	stencilBits();
	
	Window	sRGB(bool b);
	bool	sRGB();
	
	Window	swapInterval(uint i);
	uint	swapInterval();
	
	// ----

	char[]	title();
	Window	title(char[] t);
	
	Window	decorations(bool d);
	bool	decorations();
	
	Window	showCursor(bool);

	bool	interceptCursor();
	Window	interceptCursor(bool);

	Window	fullscreen(bool f);
	bool	fullscreen();
	
	Window	position(vec2i);
	vec2i	position();
	
	bool	visible();
	Window	update();
	
	InputChannel	inputChannel();
	Window			inputChannel(InputChannel);
}
