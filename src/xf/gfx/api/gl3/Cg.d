module xf.gfx.api.gl3.Cg;

public {
	import xf.gfx.api.gl3.cg.Consts;
	import xf.gfx.api.gl3.cg.Functions;
	
	import tango.sys.SharedLib;
}


version (Windows) {
	char[] cgDyLibFileName = "cg.dll";
} else {
	static assert (false, "TODO");
}

version (Windows) {
	char[] cgGLDyLibFileName = "cgGL.dll";
} else {
	static assert (false, "TODO");
}

private {
	SharedLib cgDyLib;
	SharedLib cgGLDyLib;
}


void initCgBinding() {
	if (cgDyLib !is null) {
		cgDyLib.unload();
	}
	cgDyLib = SharedLib.load(cgDyLibFileName);

	if (cgGLDyLib !is null) {
		cgGLDyLib.unload();
	}
	cgGLDyLib = SharedLib.load(cgGLDyLibFileName);
	
	
	loadCgFunctions_(function void*(char* n) {
		return cgDyLib.getSymbol(n);
	});

	loadCgGLFunctions_(function void*(char* n) {
		return cgGLDyLib.getSymbol(n);
	});
}
