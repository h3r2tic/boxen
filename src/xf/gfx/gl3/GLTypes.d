module xf.gfx.gl3.GLTypes;

public {
	import xf.gfx.gl3.Common;
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
}



// up-align to 4
pragma (ctfe) uint upTo4(uint x) {
	return (x + 3) & ~cast(uint)3;
}

void* gl_getCoreFuncPtr(char* name, int fnId, void* GLptr) {
	assert (false);
	return null;		// TODO
}

extern (C) size_t poopie(char* fname, int frameSize, size_t retVal) {
	printf(
		"validate func call called with %s, %d and %d\n",
		fname, frameSize, retVal
	);
	return retVal;
}

void validateFuncCallProc() {
	asm {
		naked;
		push EAX;
		push ECX;
		push EDX;
		call poopie;
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
