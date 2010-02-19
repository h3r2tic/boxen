module xf.gfx.api.gl3.OpenGL;

private {
	import tango.io.FileScan;
	//import tango.text.Regex;
	import tango.text.Util;
	import tango.stdc.stringz;
	import tango.sys.SharedLib;
	import Path = tango.io.Path;
	
	import tango.io.Stdout;

	import xf.gfx.api.gl3.Exceptions;
	import xf.gfx.api.gl3.LoaderCommon;
	//import xf.dog.GLExt;
}

public {
	import xf.gfx.api.gl3.Common;
	import xf.gfx.api.gl3.GL;
	import xf.gfx.api.gl3.Window;
	import xf.gfx.api.gl3.GLTypes;
	//import xf.gfx.api.gl3.backend.Native;		// HACK
	//import xf.gfx.api.gl3.GLUFunctions;
	//import xf.gfx.api.gl3.GLFunctions;
}


version (Windows) {
	public import xf.gfx.api.gl3.WGL;
	private import xf.gfx.api.gl3.platform.Win32;	// HACK
}
else {
	static assert (false);		// TODO
}



private {
	void loadGLFunctionsFromLib_(void* function(char*) loadFuncFromLib) {
		loadPlatformFunctions_(loadFuncFromLib);
		//loadCoreFunctions_(loadFuncFromLib);
	}

	SharedLib	glLib;
	//SharedLib	gluLib;


	bool loadGlLib_(char[] src) {
		unloadGlLib_();
		try {
			glLib = SharedLib.load(src);
			return glLib !is null;
		} catch (SharedLibException e) {
			return false;
		}
	}
	
	
	void unloadGlLib_() {
		if (glLib !is null) {
			glLib.unload();
			glLib = null;
		}
	}


	/+bool loadGluLib_(char[] src) {
		unloadGluLib_();
		try {
			gluLib = SharedLib.load(src);
			return gluLib !is null;
		} catch (SharedLibException) {
			return false;
		}
	}
	
	
	void unloadGluLib_() {
		if (gluLib !is null) {
			gluLib.unload();
			gluLib = null;
		}
	}+/
}



private Object loaderMutex;
static this() {
	loaderMutex = new Object;
}

void findAndLoadLibs() {
	synchronized (loaderMutex) {
		static bool loaded = false;
		if (loaded) return;
		scope (success) loaded = true;
		
		void load(char[][] namesList, void delegate() loadFunc, bool function(char[]) loadLibFunc) {
			foreach (path; libSearchPaths) {
				if (0 == path.length) {		// load from default locations
					foreach (name; namesList) {
						if (loadLibFunc(name)) {
							loadFunc();
							return;
						} else {
							continue;
						}
					}
				}
				auto rootPath = FilePath(path);
					
				if (rootPath.exists && rootPath.isFolder) {
					foreach (filePath; rootPath.toList) {
						try {
							if (filePath.isFolder) continue;
						} catch {
							continue;
						}

						foreach (name; namesList) {
							if (Path.patternMatch(filePath.file, name)) {
								if (loadLibFunc(FilePath().join(path, filePath.file))) {
									loadFunc();
									return;
								} else {
									continue;
								}
							}
						}
					}
				}
			}
			
			handleLibNotFound(namesList, libSearchPaths);
		}

		load(libNames, { loadGLFunctionsFromLib_(&loadFuncFromLib); }, &loadGlLib_);
		//load(gluLibNames, { loadGluFunctions_(&loadFuncFromGluLib); }, &loadGluLib_);
		
		xf.gfx.api.gl3.GLTypes._getCoreFuncPtr = &loadFuncFromLib;
	}
}


bool extractVersionNumbers(char[] str, char delim, int* major, int* minor) {
	int dot = str.locate(delim);
	if (dot+1 >= str.length || 0 == dot) return false;
	
	char d1 = str[dot-1];
	char d2 = str[dot+1];
	
	if (d1 > '9' || d1 < '0' || d2 > '9' || d2 < '0') return false;
	
	*major = d1 - '0';
	*minor = d2 - '0';
	
	return true;
}


/+bool isOpenGLVersionSupported(char[] versionStr, char delim) {
	int implMajor, implMinor;
	int chkMajor, chkMinor;
	
	Stdout.formatln(fromStringz(fp_glGetString(xf.dog.Common.GL_VERSION)));
	
	if	(	extractVersionNumbers(fromStringz(fp_glGetString(xf.dog.Common.GL_VERSION)), '.', &implMajor, &implMinor) &&
			extractVersionNumbers(versionStr, delim, &chkMajor, &chkMinor))
	{
		if (implMajor > chkMajor) return true;
		if (implMajor == chkMajor && implMinor >= chkMinor) return true;
	}
	
	return false;
}+/


void* loadFuncFromLib(char* name) {
	void* func = glLib.getSymbol(name);
	
	if (func is null) {
		handleMissingProc(name);
		return null;
	} else {
		return func;
	}
}


/+void* loadFuncFromGluLib(char* name) {
	void* func = gluLib.getSymbol(name);
	
	if (func is null) {
		handleMissingProc(name);
		return null;
	} else {
		return func;
	}
	return null;
}
+/
