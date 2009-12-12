module xf.gfx.gl3.backend.Native;


public {
	import xf.gfx.gl3.GLContext;
	
	version (Windows) {
		import xf.gfx.gl3.backend.native.Win32 : GLWindow;
	}
	else {
		static assert (false);		// TODO
	}
}
