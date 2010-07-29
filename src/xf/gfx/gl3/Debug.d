module xf.gfx.gl3.Debug;

private {
	import xf.Common;
	//import xf.utils.Log;
	import xf.gfx.api.gl3.OpenGL;
	import tango.stdc.stdio;
}

//mixin(createLoggerMixin("glLog"));


extern (System) {
	void openglDebugProc(
		GLenum source,
		GLenum type,
		GLuint id,
		GLenum severity,
		GLsizei length,
		GLchar* message,
		GLvoid* userParam
	) {
		fprintf(stderr, "GL debug: %s\n", message);
		//glLog.info("{}", fromStringz(message));
	}

	alias typeof (&openglDebugProc) GLDEBUGPROCARB;
	typedef void function(GLDEBUGPROCARB, void*) DebugMessageCallbackARB;

	typedef void function(
		GLenum source,
		GLenum type,
		GLenum severity,
		GLsizei count,
		GLuint* ids,
		GLboolean enabled
	) DebugMessageControlARB;
}


enum {
	DEBUG_OUTPUT_SYNCHRONOUS_ARB = 0x8242
}


void initializeOpenGLDebug(GL gl) {
	if (auto glDebugMessageCallbackARB = cast(DebugMessageCallbackARB)getExtensionFuncPtr(
		"glDebugMessageCallbackARB"
	)) {
		gl.Disable(DEBUG_OUTPUT_SYNCHRONOUS_ARB);
		glDebugMessageCallbackARB(&openglDebugProc, null);

		if (auto glDebugMessageControlARB = cast(DebugMessageControlARB)getExtensionFuncPtr(
			"glDebugMessageControlARB"
		)) {
			glDebugMessageControlARB(
				DONT_CARE,
				DONT_CARE,
				DONT_CARE,
				0,
				null,
				TRUE
			);
		} else {
			fprintf(stderr, "glDebugMessageControlARB not found. WTF.\n");
		}
	} else {
		fprintf(stderr, "GL_ARB_debug_output not supported :(\n");
	}
}
