module xf.gfx.gl3.GLContext;

public {
	import xf.gfx.gl3.Common;
	import xf.utils.Use;
}



abstract class GLContext {
	abstract GLContext	create();
	abstract GLContext	destroy();
	abstract GLContext	show();
	abstract void				useInHandler(void delegate(GL) dg);


	GLContext width(uint w) {
		_width = w;
		return this;
	}
	
	
	uint width() {
		return _width;
	}
	
	
	GLContext height(uint h) {
		_height = h;
		return this;
	}
	
	
	uint height() {
		return _height;
	}
	
	
	GLContext colorBits(uint b) {
		_colorBits = b;
		return this;
	}
	
	
	uint colorBits() {
		return _colorBits;
	}
	
	
	GLContext depthBits(uint d) {
		_depthBits = d;
		return this;
	}
	
	
	uint depthBits() {
		return _depthBits;
	}
	
	
	GLContext alphaBits(uint a) {
		_alphaBits = a;
		return this;
	}
	
	
	uint alphaBits() {
		return _alphaBits;
	}
	
	
	GLContext stencilBits(uint s) {
		_stencilBits = s;
		return this;
	}
	
	
	uint stencilBits() {
		return _stencilBits;
	}
	
	
	bool created() {
		return _created;
	}
	

	void reshape(void delegate(uint width, uint height) dg) {
		_reshapeCallback = dg;
	}
	
	
	protected {
		uint		_width			= 640;
		uint		_height			= 480;
		uint		_colorBits 		= 0;
		uint		_depthBits		= 16;
		uint		_alphaBits		= 0;
		uint		_stencilBits	= 0;
		
		bool		_created = false;

		void delegate(uint width, uint height)	_reshapeCallback;
	}
}
