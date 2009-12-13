module xf.gfx.gl3.platform.Win32;

public {
	import xf.gfx.gl3.LoaderCommon;
	import xf.platform.win32.windef;
	import xf.platform.win32.wingdi : LAYERPLANEDESCRIPTOR, COLORREF, GLYPHMETRICSFLOAT, PIXELFORMATDESCRIPTOR;
}

private {
	import GLTypes = xf.gfx.gl3.GLTypes;
	import tango.stdc.stringz;
}


public static extern (System) {
	BOOL function(HGLRC,HGLRC) wglCopyContext;
	HGLRC function(HDC) wglCreateContext;
	HGLRC function(HDC,int) wglCreateLayerContext;
	BOOL function(HGLRC) wglDeleteContext;
	BOOL function(HDC,int,int,UINT,LAYERPLANEDESCRIPTOR*) wglDescribeLayerPlane;
	HGLRC function() wglGetCurrentContext;
	HDC function() wglGetCurrentDC;
	int function(HDC,int,int,int,COLORREF*) wglGetLayerPaletteEntries;
	FARPROC function(LPCSTR) wglGetProcAddress;
	BOOL function(HDC,HGLRC) wglMakeCurrent;
	BOOL function(HDC,int,BOOL) wglRealizeLayerPalette;
	int function(HDC,int,int,int,COLORREF*) wglSetLayerPaletteEntries;
	BOOL function(HGLRC,HGLRC) wglShareLists;
	BOOL function(HDC,UINT) wglSwapLayerBuffers;
	BOOL function(HDC,int, PIXELFORMATDESCRIPTOR*) wglSetPixelFormat;
	BOOL function(HDC,DWORD,DWORD,DWORD) wglUseFontBitmapsA;
	BOOL function(HDC,DWORD,DWORD,DWORD,FLOAT,FLOAT,int,GLYPHMETRICSFLOAT*) wglUseFontOutlinesA;
	BOOL function(HDC,DWORD,DWORD,DWORD) wglUseFontBitmapsW;
	BOOL function(HDC,DWORD,DWORD,DWORD,FLOAT,FLOAT,int,GLYPHMETRICSFLOAT*) wglUseFontOutlinesW;
}


void loadPlatformFunctions_(void* function(char*) loadFuncFromLib) {
	// could check all but what the hell...
	if (wglUseFontOutlinesW !is null) return;

	*cast(void**)&wglCopyContext = loadFuncFromLib("wglCopyContext");
	*cast(void**)&wglCreateContext = loadFuncFromLib("wglCreateContext");
	*cast(void**)&wglCreateLayerContext = loadFuncFromLib("wglCreateLayerContext");
	*cast(void**)&wglDeleteContext = loadFuncFromLib("wglDeleteContext");
	*cast(void**)&wglDescribeLayerPlane = loadFuncFromLib("wglDescribeLayerPlane");
	*cast(void**)&wglGetCurrentContext = loadFuncFromLib("wglGetCurrentContext");
	*cast(void**)&wglGetCurrentDC = loadFuncFromLib("wglGetCurrentDC");
	*cast(void**)&wglGetLayerPaletteEntries = loadFuncFromLib("wglGetLayerPaletteEntries");
	*cast(void**)&wglGetProcAddress = loadFuncFromLib("wglGetProcAddress");
	*cast(void**)&wglMakeCurrent = loadFuncFromLib("wglMakeCurrent");
	*cast(void**)&wglRealizeLayerPalette = loadFuncFromLib("wglRealizeLayerPalette");
	*cast(void**)&wglSetLayerPaletteEntries = loadFuncFromLib("wglSetLayerPaletteEntries");
	*cast(void**)&wglShareLists = loadFuncFromLib("wglShareLists");
	*cast(void**)&wglSwapLayerBuffers = loadFuncFromLib("wglSwapLayerBuffers");
	*cast(void**)&wglSetPixelFormat = loadFuncFromLib("wglSetPixelFormat");
	*cast(void**)&wglUseFontBitmapsA = loadFuncFromLib("wglUseFontBitmapsA");
	*cast(void**)&wglUseFontOutlinesA = loadFuncFromLib("wglUseFontOutlinesA");
	*cast(void**)&wglUseFontBitmapsW = loadFuncFromLib("wglUseFontBitmapsW");
	*cast(void**)&wglUseFontOutlinesW = loadFuncFromLib("wglUseFontOutlinesW");
}


public void* getExtensionFuncPtr(char* name) {
	auto foo = wglGetProcAddress(name);
	assert (foo, `couldnt load: '` ~ fromStringz(name) ~ `'`);
	return foo;
}


static this() {
	appendLibSearchPaths(`.`, ``);
	appendLibNames(`opengl32.dll`);
	appendGluLibNames(`glu32.dll`);
	
	GLTypes._getExtensionFuncPtr = &getExtensionFuncPtr;
}
