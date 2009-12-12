module xf.gfx.gl3.Window;

public {
	import xf.omg.core.LinearAlgebra : vec2i;
}

private {
	import xf.input.Input : InputChannel;
}



interface Window {
	char[]	title();
	Window	title(char[] t);
	
	Window	decorations(bool d);
	bool		decorations();
	
	Window	showCursor(bool);

	bool		interceptCursor();
	Window	interceptCursor(bool);

	Window	fullscreen(bool f);
	bool		fullscreen();
	
	Window	position(vec2i);
	vec2i	position();
	
	bool		visible();
	Window	update();
	
	InputChannel	inputChannel();
	Window inputChannel(InputChannel);
}
