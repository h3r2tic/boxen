module xf.gfx.api.gl3.backend.Root;


public {
	import xf.gfx.api.gl3.GLContext;
	
	version (Windows) {
		import xf.gfx.api.gl3.backend.root.Win32 : GLRootWindow;
	}
	else {
		static assert (false);		// TODO
	}
}
