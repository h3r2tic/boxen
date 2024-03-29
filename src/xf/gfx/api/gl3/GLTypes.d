module xf.gfx.api.gl3.GLTypes;

public {
	import xf.gfx.api.gl3.Common;
	import xf.gfx.api.gl3.ExtensionGenConsts;
	import xf.gfx.api.gl3.Exceptions;
}


public {
	alias uint		GLenum;
	alias ubyte	GLboolean;
	alias uint		GLbitfield;
	alias void		GLvoid;
	alias byte		GLbyte;
	alias short		GLshort;
	alias int			GLint;
	alias ubyte	GLubyte;
	alias ushort	GLushort;
	alias uint		GLuint;
	alias int			GLsizei;
	alias float		GLfloat;
	alias float		GLclampf;
	alias double	GLdouble;
	alias double	GLclampd;
	alias char		GLchar;
	alias ptrdiff_t	GLintptr;
	alias ptrdiff_t GLsizeiptr;
	alias long		GLint64;
	alias ulong		GLuint64;
	alias long		GLint64EXT;
	alias ulong		GLuint64EXT;

	typedef ushort	GLhalfNV;
	alias ptrdiff_t	GLintptrARB;
	alias ptrdiff_t	GLsizeiptrARB;
	typedef void*	GLsync;

	alias char GLcharARB;
	alias uint GLhandleARB;
}

public {
	typedef void* GLUnurbs;
	typedef void* GLUquadric;
	typedef void* GLUtesselator;

	typedef GLUnurbs GLUnurbsObj;
	typedef GLUquadric GLUquadricObj;
	typedef GLUtesselator GLUtesselatorObj;
	typedef GLUtesselator GLUtriangulatorObj;
	
	static extern(System) typedef void function() _GLUfuncptr;
}

private {
	import tango.stdc.stdio;
	import xf.gfx.api.gl3.GLContextData;
}


void* function(char*)	_getCoreFuncPtr;
void* function(char*)	_getExtensionFuncPtr;



// up-align to 4
pragma (ctfe) uint upTo4(uint x) {
	return (x + 3) & ~cast(uint)3;
}


void* gl_getCoreFuncPtr(char* name, uint fnId_, GLContextData* gl) {
	const int extFuncsOffsetof = gl.extFunctions.offsetof;
	const int arrSizeOf = (void*[]).sizeof;
	const int frameSize = typeof(name).sizeof + typeof(fnId_).sizeof;
	const int maxExtensions = extensionFuncCounts.length;
	
	asm {
		naked;
	}
	version (GL3AsmChecks) asm {
		cmp EAX, 0;
		jne glHandleOK;
	}
	asm {
	glHandleOK:
		mov EDX, dword ptr [ESP+size_t.sizeof];		// fnId
		mov ECX, EDX;
		and EDX, 0xffff;		// EDX == extIdx
		shr ECX, 16;			// ECX == fnIdx
	}
	version (GL3AsmChecks) asm {
		cmp EDX, maxExtensions;
		jge onoz;
	}
	asm {
		mov EAX, [EAX + extFuncsOffsetof + size_t.sizeof];
		mov EAX, [EAX + EDX * arrSizeOf + size_t.sizeof];
		lea EAX, [EAX + ECX * size_t.sizeof];		// EAX == pointer to the func pointer in the context data
		
		cmp [EAX], 0;
		je mustLoad;
		mov EAX, [EAX];
		ret frameSize;
		
	mustLoad:
		mov EDX, EAX;
		mov EAX, [ESP+frameSize];
		
		push EDX;
		call _getCoreFuncPtr;
		pop EDX;
		
		mov [EDX], EAX;
		jz procMissing;
		ret frameSize;
		
	procMissing:
		mov EAX, [ESP+frameSize];	// name
		call handleMissingProc;
		mov EAX, 0;
		ret frameSize;
	}
	version (GL3AsmChecks) asm {
	onoz:
		int 3;
	}
}


void* gl_getExtensionFuncPtr(char* name, uint fnId_, GLContextData* gl) {
	const int extFuncsOffsetof = gl.extFunctions.offsetof;
	const int arrSizeOf = (void*[]).sizeof;
	const int frameSize = typeof(name).sizeof + typeof(fnId_).sizeof;
	const int maxExtensions = extensionFuncCounts.length;
	
	asm {
		naked;
	}
	version (GL3AsmChecks) asm {
		cmp EAX, 0;
		jne glHandleOK;
	}
	asm {
	glHandleOK:
		mov EDX, dword ptr [ESP+size_t.sizeof];		// fnId
		mov ECX, EDX;
		and EDX, 0xffff;		// EDX == extIdx
		shr ECX, 16;			// ECX == fnIdx
	}
	version (GL3AsmChecks) asm {
		cmp EDX, maxExtensions;
		jge onoz;
	}
	asm {
		mov EAX, [EAX + extFuncsOffsetof + size_t.sizeof];
		mov EAX, [EAX + EDX * arrSizeOf + size_t.sizeof];
		lea EAX, [EAX + ECX * size_t.sizeof];		// EAX == pointer to the func pointer in the context data
		
		cmp [EAX], 0;
		je mustLoad;
		mov EAX, [EAX];
		ret frameSize;
		
	mustLoad:
		mov EDX, EAX;
		mov EAX, [ESP+frameSize];
		
		push EDX;
		call _getExtensionFuncPtr;
		pop EDX;
		
		mov [EDX], EAX;
		jz procMissing;
		ret frameSize;
		
	procMissing:
		mov EAX, [ESP+frameSize];	// name
		call handleMissingProc;
		mov EAX, 0;
		ret frameSize;
	}
	version (GL3AsmChecks) asm {
	onoz:
		int 3;
	}
}


extern (System) GLenum function() _glGetError;

extern (C) size_t _glErrorChecker(char* fname, int frameSize, size_t retVal) {
	/+printf(
		"validate func call called with %s, %d and %d\n",
		fname, frameSize, retVal
	);+/

	if (_glGetError is null) {
		_glGetError = cast(typeof(_glGetError))_getCoreFuncPtr("glGetError");
		assert (_glGetError !is null);
	}
	
	enum GLError {
		NO_ERROR = 0,
		INVALID_ENUM = 0x0500,
		INVALID_VALUE = 0x0501,
		INVALID_OPERATION = 0x0502,
		STACK_OVERFLOW = 0x0503,
		STACK_UNDERFLOW = 0x0504,
		OUT_OF_MEMORY = 0x0505,
		TABLE_TOO_LARGE_EXT = 0x8031,
		TEXTURE_TOO_LARGE_EXT = 0x8065
	}

	final err = _glGetError();
	if (err == GLError.NO_ERROR) {
		return retVal;
	} else {
		void handleError(char[] str) {
			throw new Exception(str);
		}
		
		switch (err) {
			case GLError.INVALID_ENUM:	handleError("OpenGL error: INVALID_ENUM");
			case GLError.INVALID_VALUE:	handleError("OpenGL error: INVALID_VALUE");
			case GLError.INVALID_OPERATION:	handleError("OpenGL error: INVALID_OPERATION");
			case GLError.STACK_OVERFLOW:	handleError("OpenGL error: STACK_OVERFLOW");
			case GLError.STACK_UNDERFLOW:	handleError("OpenGL error: STACK_UNDERFLOW");
			case GLError.OUT_OF_MEMORY:	handleError("OpenGL error: OUT_OF_MEMORY");
			case GLError.TABLE_TOO_LARGE_EXT:	handleError("OpenGL error: TABLE_TOO_LARGE_EXT");
			case GLError.TEXTURE_TOO_LARGE_EXT:	handleError("OpenGL error: TEXTURE_TOO_LARGE_EXT");
			default: {
				handleError("Unknown OpenGL error");
			}
		}
	}
}

void validateFuncCallProc() {
	asm {
		naked;
		push EAX;
		push ECX;
		push EDX;
		call _glErrorChecker;
		pop EDX;
		pop ECX;
		pop EAX;

		/+cmp EAX, 123;
		je validated;

		call foo2_errorHandler;
		ret;+/
validated:
		add ESP, ECX;	// <--- remove the arguments of the GL function
		ret;
	}
}


struct _GL3ExtraSpace {
	size_t dummy = 0xdeadc0de;
}
