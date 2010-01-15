module xf.gfx.gl3.CgEffect;

public {
	import xf.gfx.GPUEffect;
}

private {
	import xf.Common;	
	import xf.gfx.Log : log = gfxLog, error = gfxError;
	import xf.gfx.api.gl3.Cg;
}



class CgEffect : GPUEffect {
	this (cstring name, CGeffect handle) {
		this._name = name;
		this._handle = handle;
		
		assert (_handle !is null);
		assert (CG_NO_ERROR == cgGetError());
		
		findCgPrograms();
	}
	
	
	static CGprofile getProfileForDomain(GPUDomain domain) {
		switch (domain) {
			case GPUDomain.Vertex:
				return cgGLGetLatestProfile(CG_GL_VERTEX);
			case GPUDomain.Geometry:
				return cgGLGetLatestProfile(CG_GL_GEOMETRY);
			case GPUDomain.Fragment:
				return cgGLGetLatestProfile(CG_GL_FRAGMENT);
			default:
				assert (false);
		}
	}
	
	
	final override void setArraySize(cstring name, size_t size) {
		auto array = _getEffectParameter(name);
		if (array is null) {
			error("setArraySize: Invalid parameter '{}'", name);
		}
		
		cgSetArraySize(array, size);
		auto err = cgGetError();
		switch (err) {
			case CG_ARRAY_PARAM_ERROR: {
				error("The parameter '{}' is not an array", name);
			} break;
			
			case CG_ARRAY_HAS_WRONG_DIMENSION_ERROR: {
				error("The parameter array '{}' is not one-dimensional", name);
			} break;
			
			case CG_PARAMETER_IS_NOT_RESIZABLE_ARRAY_ERROR: {
				error("The parameter array '{}' is not resizable", name);
			} break;
			
			case CG_NO_ERROR: {
			} break;
			
			default: {
				error("Unknown Cg error: {}", fromStringz(cgGetErrorString(err)));
			}
		}

		log.info("Resized array '{}' to {} elements", name, size);
	}
	
	
	final override void setUniformType(cstring name, cstring typeName) {
		auto param = _getEffectParameter(name);
		if (param is null) {
			error("setUniformType: Invalid parameter '{}'", name);
		}
		
		auto type = cgGetNamedUserType(cast(CGhandle)_handle, toStringz(typeName));
		auto err = cgGetError();
		switch (err) {
			case CG_INVALID_PARAMETER_ERROR: {
				error("setUniformType: Invalid user type '{}'", typeName);
			} break;

			case CG_NO_ERROR: {
			} break;
			
			default: {
				error("Unknown Cg error: {}", fromStringz(cgGetErrorString(err)));
			}
		}
		
		auto param2 = cgCreateParameter(
			cgGetEffectContext(_handle),
			type
		);

		err = cgGetError();
		switch (err) {
			case CG_NO_ERROR: {
			} break;
			
			default: {
				error("Unknown Cg error: {}", fromStringz(cgGetErrorString(err)));
			}
		}
		
		cgConnectParameter(param2, param);

		err = cgGetError();
		switch (err) {
			case CG_PARAMETERS_DO_NOT_MATCH_ERROR: {
				error(
					"setUniformType: Parameters have different"
					" or their topologies do not match",
					typeName
				);
			} break;

			case CG_NO_ERROR: {
			} break;
			
			default: {
				error("Unknown Cg error: {}", fromStringz(cgGetErrorString(err)));
			}
		}
		
		log.info(
			"Set the type of uniform '{}' to '{}'.",
			name,
			typeName
		);
	}
	
	
	final override CgEffect copy() {
		assert (false, "TODO");
	}
	
	
	final override void compile() {
		if (_compiled) {
			error(
				"Trying to compile an already compiled Cg effect (name='{}').",
				_name
			);
		}
		
		foreach (prog; &iterCgPrograms) {
			if (!cgIsProgramCompiled(prog)) {
				log.info("Compiling a Cg program.");
				cgCompileProgram(prog);

				auto err = cgGetError();
				switch (err) {
					case CG_INVALID_PROGRAM_HANDLE_ERROR: {
						error("Program handle passed to cgCompileProgram was not valid");
					} break;
					
					case CG_COMPILER_ERROR: {
						error(
							"Compilation error\n{}",
							fromStringz(cgGetLastListing(cgGetEffectContext(_handle)))
						);
					} break;
					
					case CG_NO_ERROR: {
					} break;
					
					default: {
						error("Unknown Cg error: {}", fromStringz(cgGetErrorString(err)));
					}
				}
			} else {
				log.info("Good, Cg program already compiled.");
			}
		}
		
		findEffectParameters();
		
		_compiled = true;
	}
	

	private {
		CGprogram extractProgram(char* name, GPUDomain domain) {
			auto prog = cgCreateProgramFromEffect(
				_handle,
				getProfileForDomain(domain),
				name,
				null
			);
			
			auto err = cgGetError();
			switch (err) {
				case CG_INVALID_EFFECT_HANDLE_ERROR: {
					error(
						"cgCreateProgramFromEffect: invalid effect supplied"
					);
				} break;
				
				case CG_UNKNOWN_PROFILE_ERROR: {
					error(
						"cgCreateProgramFromEffect: unknown profile"
					);
				} break;
				
				case CG_COMPILER_ERROR: {
					error(
						"Compilation error\n{}",
						fromStringz(cgGetLastListing(cgGetEffectContext(_handle)))
					);
				} break;
				
				case CG_INVALID_PROGRAM_HANDLE_ERROR: {
					error(
						"Compilation error\n{}",
						fromStringz(cgGetLastListing(cgGetEffectContext(_handle)))
					);
				}
				
				case CG_NO_ERROR: {
				} break;
				
				default: {
					error("Unknown Cg error: {}", fromStringz(cgGetErrorString(err)));
				} break;
			}
			
			return prog;
		}
		

		CGparameter _getEffectParameter(cstring name) {
			cstring realName;
			if (name.startsWith(fromStringz(_domainProgramNames[
				GPUDomain.Vertex
			]), &realName)) {
				if (_vertexProgram is null) {
					return null;
				} else {
					return _getProgramParameter(_vertexProgram, realName[1..$]);
				}
			}
			else if (name.startsWith(fromStringz(_domainProgramNames[
				GPUDomain.Fragment
			]), &realName)) {
				if (_fragmentProgram is null) {
					return null;
				} else {
					return _getProgramParameter(_fragmentProgram, realName[1..$]);
				}
			}
			else if (
				_useGeometryProgram
				&& name.startsWith(fromStringz(_domainProgramNames[
					GPUDomain.Geometry
				]), &realName))
			{
				if (_geometryProgram is null) {
					return null;
				} else {
					return _getProgramParameter(_geometryProgram, realName[1..$]);
				}
			}
			else {
				char[256] buf = void;
				return cgGetNamedEffectParameter(
					_handle,
					toStringz(name, buf[])
				);
			}
		}
		
		
		CGparameter _getProgramParameter(CGprogram prog, cstring name) {
			char[256] buf = void;
			return cgGetNamedParameter(
				prog,
				toStringz(name, buf[])
			);
		}
		
		
		void findCgPrograms() {
			_vertexProgram = extractProgram(
				_domainProgramNames[GPUDomain.Vertex],
				GPUDomain.Vertex
			);
			
			if (_useGeometryProgram) {
				_geometryProgram = extractProgram(
					_domainProgramNames[GPUDomain.Geometry],
					GPUDomain.Geometry
				);
			}
			
			_fragmentProgram = extractProgram(
				_domainProgramNames[GPUDomain.Fragment],
				GPUDomain.Fragment
			);
		}
		
		
		int iterCgPrograms(int delegate(ref CGprogram) dg) {
			if (_vertexProgram !is null) {
				if (auto r = dg(_vertexProgram))	return r;
			}
			if (_geometryProgram !is null) {
				if (auto r = dg(_geometryProgram))	return r;
			}
			if (_fragmentProgram !is null) {
				if (auto r = dg(_fragmentProgram))	return r;
			}
			return 0;
		}
		
		
		void findEffectParameters() {
			log.warn("findEffectParameters: TODO");
		}

		
		bool		_compiled = false;
		cstring		_name;
		CGeffect	_handle;
		CGprogram	_vertexProgram;
		CGprogram	_geometryProgram;
		CGprogram	_fragmentProgram;
	}
}
