module xf.gfx.gl3.Cg;

public {
	import xf.gfx.gl3.CgEffect;
}

private {
	import xf.Common;
	
	import
		xf.gfx.api.gl3.OpenGL,
		xf.gfx.api.gl3.Cg;
		
	import xf.gfx.Log : error = gfxError;
}


struct EffectSource {
	enum Type {
		FilePath
	}
	
	static EffectSource filePath(cstring path) {
		return EffectSource(path, toStringz(path), Type.FilePath);
	}
	
	cstring _path;
	char*	_pathStringz;
	Type	_type;
}


class CgCompiler {
	this(GL gl, CGcontext context = null) {
		this.gl[] = gl;
		initCgBinding();
		
		if (context is null) {
			_context = cgCreateContext();
		} else {
			_context = context;
		}
		
		cgGLSetDebugMode(CG_TRUE);
		cgSetParameterSettingMode(_context, CG_IMMEDIATE_PARAMETER_SETTING);
		cgGLRegisterStates(_context);
		cgGLSetManageTextureParameters(_context, CG_TRUE);
		cgSetLockingPolicy(CG_NO_LOCKS_POLICY);
		cgSetAutoCompile(_context, CG_COMPILE_MANUAL);
	}
	
	
	/+CgProgram createProgram(EffectSource source, GPUDomain domain, cstring name) {
		CgProgram result;
		
		switch (source._type) {
			case EffectSource.Type.FilePath: {
				result = CgProgram(
					domain,
					name,
					cgCreateProgramFromFile(
						_context,
						CG_SOURCE,
						source._pathStringz,
						getProfileForDomain(domain),
						toStringz(name),
						null
					)
				);
			} break;
		}

		auto err = cgGetError();
		switch (err) {
			case CG_COMPILER_ERROR: {
				error(
					"Compilation error\n{}",
					fromStringz(cgGetLastListing(_context))
				);
			} break;
			
			case CG_NO_ERROR: {
			} break;
			
			default: {
				error("Unknown Cg error: {}", fromStringz(cgGetErrorString(err)));
			}
		}
		
		return result;
	}+/
	
	
	CgEffect createEffect(cstring name, EffectSource source) {
		CGeffect eh;
		
		switch (source._type) {
			case EffectSource.Type.FilePath: {
				eh = cgCreateEffectFromFile(
					_context,
					toStringz(source._path),
					null
				);
			} break;
			
			default: assert (false);
		}

		auto err = cgGetError();
		switch (err) {
			case CG_COMPILER_ERROR: {
				error(
					"Compilation error\n{}",
					fromStringz(cgGetLastListing(_context))
				);
			} break;
			
			case CG_NO_ERROR: {
			} break;
			
			default: {
				error("Unknown Cg error: {}", fromStringz(cgGetErrorString(err)));
			}
		}
		
		assert (eh !is null);

		return new CgEffect(name, eh, gl);
	}
	
	
	CGcontext context() {
		return _context;
	}


	private {
		CGcontext	_context;
		GL			gl;
	}
}
