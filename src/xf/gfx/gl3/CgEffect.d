module xf.gfx.gl3.CgEffect;

public {
	import xf.gfx.GPUEffect;
}

private {
	import xf.Common;	
	import xf.gfx.Log : log = gfxLog, error = gfxError;
	import xf.gfx.api.gl3.Cg;
	import xf.mem.StackBuffer;
	import xf.mem.OSHeap;
	import xf.utils.IntrusiveList;
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
		final array = _getEffectParameter(name);
		if (array is null) {
			error("setArraySize: Invalid parameter '{}'", name);
		}
		
		cgSetArraySize(array, size);
		final err = cgGetError();
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

		log.trace("Resized array '{}' to {} elements", name, size);
	}
	
	
	final override void setUniformType(cstring name, cstring typeName) {
		final param = _getEffectParameter(name);
		if (param is null) {
			error("setUniformType: Invalid parameter '{}'", name);
		}
		
		final type = cgGetNamedUserType(cast(CGhandle)_handle, toStringz(typeName));
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
		
		final param2 = cgCreateParameter(
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
					" or their topologies do not match"
				);
			} break;

			case CG_NO_ERROR: {
			} break;
			
			default: {
				error("Unknown Cg error: {}", fromStringz(cgGetErrorString(err)));
			}
		}
		
		log.trace(
			"Set the type of uniform '{}' to '{}'.",
			name,
			typeName
		);
	}
	
	
	final override CgEffect copy() {
		final nh = cgCopyEffect(_handle);

		auto err = cgGetError();
		switch (err) {
			case CG_INVALID_EFFECT_HANDLE_ERROR: {
				error("Effect handle passed to cgCopyEffect was not valid");
			} break;
			
			case CG_NO_ERROR: {
			} break;
			
			default: {
				error("Unknown Cg error: {}", fromStringz(cgGetErrorString(err)));
			}
		}
		
		if (nh is null) {
			error("Error copying Cg effect '{}': unknown reason :(", _name);
		}

		final res = new CgEffect(_name, nh);
		this.copyToNew(res);
		return res;
	}
	
	
	final override void compile() {
		if (_compiled) {
			error(
				"Trying to compile an already compiled Cg effect (name='{}').",
				_name
			);
		}

		foreach (domain, prog; &iterCgPrograms) {
			if (!cgIsProgramCompiled(prog)) {
				auto dname = GPUDomainName(domain);
				
				log.info("Compiling a Cg program for the {} domain.", dname);
				cgCompileProgram(prog);

				auto err = cgGetError();
				switch (err) {
					case CG_INVALID_PROGRAM_HANDLE_ERROR: {
						error("Program handle passed to cgCompileProgram was not valid");
					} break;
					
					case CG_COMPILER_ERROR: {
						error(
							"Program compilation error for domain {}\n{}",
							dname,
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
				log.trace("Good, Cg program already compiled.");
			}
		}
		
		scope buf = new StackBuffer;
		auto builder = CgEffectBuilder(buf);
		
		findSharedEffectParams(&builder);
		findEffectParams(&builder);
		

		builder.finish(this);
		
		_compiled = true;
	}
	

//	private {
	public {
		CGprogram extractProgram(char* name, GPUDomain domain) {
			final prog = cgCreateProgramFromEffect(
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
				
				// NOTE: This error of is undocumented in Cg.
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
			
			if (prog is null) {
				error("Program '{}' not found", fromStringz(name));
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
		
		
		int iterCgPrograms(int delegate(ref GPUDomain, ref CGprogram) dg) {
			GPUDomain d;
			
			if (_vertexProgram !is null) {
				d = GPUDomain.Vertex;
				if (auto r = dg(d, _vertexProgram)) return r;
			}
			if (_useGeometryProgram && _geometryProgram !is null) {
				d = GPUDomain.Geometry;
				if (auto r = dg(d, _geometryProgram)) return r;
			}
			if (_fragmentProgram !is null) {
				d = GPUDomain.Fragment;
				if (auto r = dg(d, _fragmentProgram)) return r;
			}
			
			return 0;
		}
		

		void findSharedEffectParams(CgEffectBuilder* builder) {
			assert (CG_NO_ERROR == cgGetError());
			
			for (
				auto p = cgGetFirstLeafEffectParameter(_handle);
				p;
				p = cgGetNextLeafParameter(p)
			) {
				char* name = cgGetParameterName(p);
				log.trace("Found a shared effect param: '{}'.", fromStringz(name));

				bool usedAnywhere = false;
				
				foreach (domain, prog; &iterCgPrograms) {
					if (auto p2 = cgGetNamedProgramParameter(
						prog,
						CG_GLOBAL,
						name
					)) {
						if (!cgIsParameterUsed(p2, cast(CGhandle)prog)) {
							log.trace(
								"Shared param '{}' is not used in the {} domain.",
								fromStringz(name),
								GPUDomainName(domain)
							);
							continue;
						}
						
						usedAnywhere = true;
						
						cgConnectParameter(p, p2);
						auto err = cgGetError();
						switch (err) {
							case CG_PARAMETERS_DO_NOT_MATCH_ERROR: {
								error(
									"setUniformType: Parameters have different"
									" or their topologies do not match"
								);
							} break;

							case CG_NO_ERROR: {
							} break;
							
							default: {
								error("Unknown Cg error: {}", fromStringz(cgGetErrorString(err)));
							}
						}

						log.trace(
							"Connected the shared param '{}' to a {} program param.",
							fromStringz(name),
							GPUDomainName(domain)
						);
					}
				}
				
				if (usedAnywhere) {
					builder.registerFoundParam(p, true, GPUDomain.init);
				}
			}
		}

		
		void findEffectParams(CgEffectBuilder* builder) {
			foreach (domain, prog; &iterCgPrograms) {
				for (
					auto p = cgGetFirstLeafParameter(prog, CG_PROGRAM);
					p;
					p = cgGetNextLeafParameter(p)
				) {
					final dir = cgGetParameterDirection(p);
					
					if (dir != CG_IN && dir != CG_INOUT) {
						continue;
					}

					final connected = cgGetConnectedParameter(p);
					
					if (connected !is null) {
						// These are shared between programs
						if (cgGetParameterEffect(connected) !is null) {
							continue;
						}
					}
					
					builder.registerFoundParam(p, false, domain);
				}
			}
		}
		
				
		bool		_compiled = false;
		cstring		_name;
		CGeffect	_handle;
		CGprogram	_vertexProgram;
		CGprogram	_geometryProgram;
		CGprogram	_fragmentProgram;
	}
}


struct CgEffectBuilder {
	struct RegisteredParam {
		string		name;
		CGparameter	handle;
		
		mixin(intrusiveList("list"));
	}
	
	static CgEffectBuilder opCall(StackBufferUnsafe mem) {
		CgEffectBuilder res;
		res.mem = mem;
		return res;
	}
	
	RegisteredParam* createParam(cstring name, CGparameter handle) {
		final p = mem.alloc!(RegisteredParam);
		final n = mem.allocArray!(char)(name.length);
		n[] = name;
		p.name = cast(string)n;
		p.handle = handle;
		return p;
	}

	void registerFoundParam(CGparameter param, bool share, GPUDomain domain) {
		final variability = cgGetParameterVariability(param);
		switch (variability) {
			case CG_VARYING: {
				cstring name = fromStringz(cgGetParameterName(param));
				
				log.trace(
					"Varying {} input param: {}",
					share ? "Shared" : GPUDomainName(domain),
					name
				);
				
				final reg = createParam(name, param);
				if (varyings) {
					varyings.list ~= reg;
				} else {
					varyings = reg;
				}
				++numVaryings;
			} break;
			
			case CG_UNIFORM:
			case CG_LITERAL: {
				cstring name = fromStringz(cgGetParameterName(param));

				log.trace(
					"Uniform {} input param: {}",
					share ? "Shared" : GPUDomainName(domain),
					name
				);
				
				final reg = createParam(name, param);
				if (uniforms) {
					uniforms.list ~= reg;
				} else {
					uniforms = reg;
				}
				++numUniforms;
			} break;
			
			case CG_CONSTANT: {
				// nothing to do
			} break;
			
			case CG_MIXED: {
				error("Got CG_MIXED variability for a leaf param o_O");
			} break;
			
			default: assert (false);
		}
	}
	
	void finish(CgEffect effect) {
		log.info(
			"Registered a total of {} uniforms and {} varyings.",
			numUniforms,
			numVaryings
		);
		
		int stringLenNeeded = 0;
		foreach (ref p; uniforms.list) {
			stringLenNeeded += p.name.length+1;
		}
		foreach (ref p; varyings.list) {
			stringLenNeeded += p.name.length+1;
		}
		
		char* nameData = cast(char*)osHeap.allocRaw(stringLenNeeded);
		final char* nameDataEnd = nameData + stringLenNeeded;
		log.trace("Allocated {} bytes for param names.", stringLenNeeded);
		
		cstring convertParamName(string name) {
			int len = name.length+1;
			cstring buf = nameData[0..len];
			nameData += len;
			buf[0..$-1] = cast(cstring)name;
			buf[$-1] = '\0';
			return buf[0..$-1];
		}
		
		// TODO: find the data size and allocate proper structures in GPUEffect
		
		if (numUniforms > 0) {
			final arr = &effect.uniformParams;
			arr.resize(numUniforms);
			
			foreach (i, ref p; uniforms.list) {
				arr.name[i] = convertParamName(p.name);
				arr.param[i] = cast(UniformParam)p.handle;
				// arr.dataSlice[i] = ... TODO
			}
		}

		if (numVaryings > 0) {
			final arr = &effect.varyingParams;
			arr.resize(numVaryings);
			
			foreach (i, ref p; varyings.list) {
				arr.name[i] = convertParamName(p.name);
				arr.param[i] = cast(VaryingParam)p.handle;
			}
		}
		
		assert (nameData is nameDataEnd);
	}
	
	RegisteredParam* uniforms = null;
	RegisteredParam* varyings = null;
	
	int numUniforms = 0;
	int numVaryings = 0;
	
	StackBufferUnsafe mem;
}

