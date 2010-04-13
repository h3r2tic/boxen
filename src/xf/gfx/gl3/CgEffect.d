module xf.gfx.gl3.CgEffect;

public {
	import xf.gfx.Effect;
}

private {
	import xf.Common;	
	import xf.gfx.Log : log = gfxLog, error = gfxError;

	import
		xf.gfx.api.gl3.Cg,
		xf.gfx.api.gl3.OpenGL,
		xf.gfx.api.gl3.ext.NV_parameter_buffer_object,
		xf.gfx.api.gl3.ext.NV_transform_feedback,
		xf.gfx.Buffer,
		xf.gfx.VertexBuffer,
		xf.gfx.Texture;
	
	import
		xf.mem.StackBuffer,
		xf.mem.MainHeap;
		
	import xf.utils.IntrusiveList;
	
	// for the typeinfos of vectors and matrices
	import xf.omg.core.LinearAlgebra;
}



enum {
	// According to Cg 2.2
	MaxUniformBuffers = 12
}


void defaultHandleCgError() {
	final err = cgGetError();
	if (err != CG_NO_ERROR) {
		error("Cg error: {}", fromStringz(cgGetErrorString(err)));
	}
}



class CgEffect : Effect {
	this (cstring name, CGeffect handle, GL gl, EffectCompilationOptions opts) {
		this._name = name;
		this._handle = handle;
		this.gl[] = gl;
		
		assert (_handle !is null);
		assert (CG_NO_ERROR == cgGetError());

		_opts = opts;
		_useGeometryProgram = opts.useGeometryProgram;
		
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
		defaultHandleCgError();
		
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

		final res = new CgEffect(_name, nh, gl, _opts);
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
				
				cgGLLoadProgram(prog);
				defaultHandleCgError();
			} else {
				log.trace("Good, Cg program already compiled.");
			}
		}
		
		scope buf = new StackBuffer;
		auto builder = CgEffectBuilder(buf);
		
		findSharedEffectParams(&builder);
		findEffectParams(&builder);
		
		builder.finish(this);
		findInstanceSortingKeys();
		
		_compiled = true;
	}
	
	
	override void bind() {
		defaultHandleCgError();
		
		cgGLEnableProfile(cgGetProgramProfile(_vertexProgram));
		cgGLBindProgram(_vertexProgram);
		if (_opts.useGeometryProgram) {
			cgGLEnableProfile(cgGetProgramProfile(_geometryProgram));
			cgGLBindProgram(_geometryProgram);
		}
		cgGLEnableProfile(cgGetProgramProfile(_fragmentProgram));
		cgGLBindProgram(_fragmentProgram);
		
		defaultHandleCgError();
	}
	
	
	override void bindUniformBuffer(int idx, Buffer buf) {
		defaultHandleCgError();
		
		/+CGbuffer cgBuf = buf.valid()
			? cast(CGbuffer)buf.getShaderApiHandle()
			: null;
		
		if (cgBuf) {
			log.trace("Binding a non-null uniform buffer for an effect.");
		}+/
		
		foreach (domain, prog; &iterCgPrograms) {
			/+cgSetProgramBuffer(
				prog,
				idx,
				cgBuf
			);+/
			
			// HACK: this probably should not be done like this,
			// but Cg 2.2 refuses to update the uniform buffer
			// when not using Cg functions directly on it.
			// additionally, Cg forces the creation of buffer objects
			// through its own API, taking control of the 'target' param.
			GLenum target = void;
			switch (domain) {
				case GPUDomain.Vertex: {
					target = VERTEX_PROGRAM_PARAMETER_BUFFER_NV;
				} break;

				case GPUDomain.Geometry: {
					target = GEOMETRY_PROGRAM_PARAMETER_BUFFER_NV;
				} break;

				case GPUDomain.Fragment: {
					target = FRAGMENT_PROGRAM_PARAMETER_BUFFER_NV;
				} break;
				
				default: assert (false);
			}
			gl.BindBufferBaseNV(
				target,
				idx,
				buf.getApiHandle()
			);
		}

		defaultHandleCgError();
	}
	
	
	private {
		CGprogram extractProgram(char* name, GPUDomain domain) {
			final profile = getProfileForDomain(domain);
			
			final prog = cgCreateProgramFromEffect(
				_handle,
				profile,
				name,
				cgGLGetOptimalOptions(profile)
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
				_opts.useGeometryProgram
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
			
			if (_opts.useGeometryProgram) {
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
			if (_opts.useGeometryProgram && _geometryProgram !is null) {
				d = GPUDomain.Geometry;
				if (auto r = dg(d, _geometryProgram)) return r;
			}
			if (_fragmentProgram !is null) {
				d = GPUDomain.Fragment;
				if (auto r = dg(d, _fragmentProgram)) return r;
			}
			
			return 0;
		}
		
		
		// return true if processed and should be skipped from normal params
		private bool processSpecialParam(CGparameter p) {
			if (0 == strcmp("INSTANCEID", cgGetParameterSemantic(p))) {
				return true;
			} else {
				return false;
			}
		}
		

		void findSharedEffectParams(CgEffectBuilder* builder) {
			defaultHandleCgError();
			
			for (
				auto p = cgGetFirstLeafEffectParameter(_handle);
				p;
				p = cgGetNextLeafParameter(p)
			) {
				char* name = cgGetParameterName(p);

				if (processSpecialParam(p)) {
					continue;
				}

				log.trace("Found a shared effect param: '{}'.", fromStringz(name));

				bool usedAnywhere = false;
				
				foreach (domain, prog; &iterCgPrograms) {
					if (auto p2 = cgGetNamedProgramParameter(
						prog,
						CG_GLOBAL,
						name
					)) {
						final bufIdx = cgGetParameterBufferIndex(p2);

						if (-1 == bufIdx &&
							!cgIsParameterUsed(p2, cast(CGhandle)prog)
						) {
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
					
					if (processSpecialParam(p)) {
						continue;
					}

					final connected = cgGetConnectedParameter(p);
					
					if (connected !is null) {
						// These are shared between programs
						if (cgGetParameterEffect(connected) !is null) {
							continue;
						}
					}
					
					builder.registerFoundParam(
						p,
						false, 
						domain,
						fromStringz(getDomainProgramName(domain))
					);
				}
			}
		}
		
				
		cstring		_name;
		CGeffect	_handle;
		CGprogram	_vertexProgram;
		CGprogram	_geometryProgram;
		CGprogram	_fragmentProgram;
		GL			gl;

		EffectCompilationOptions	_opts;
	}
}


struct CgEffectBuilder {
	struct RegisteredParam {
		string		name;
		CGparameter	handle;
		
		// the D type of the Cg param
		TypeInfo	typeInfo;
		
		// for vectors and matrices
		ushort				numFields;
		
		ParamBaseType		baseType;
		UniformDataSlice	dataSlice;
		
		mixin(intrusiveList("list"));
	}
	
	static CgEffectBuilder opCall(StackBufferUnsafe mem) {
		CgEffectBuilder res;
		res.mem = mem;
		return res;
	}
	
	
	/* 
	 * Model transformations are not stored in the EffectInstance, because
	 * the same object might be rendered multiple times in a frame - e.g.
	 * with planar reflections. Furthermore, storing the transformations
	 * in the EffectInstance is a waste of space for a paramter that's
	 * available through regular fields of renderable objects
	 * 
	 * Please refer to the documentation for Effect's
	 * objectInstanceUniformParams for more information.
	 */
	bool isObjectInstanceParam(CGparameter p) {
		final name = cgGetParameterName(p);
		
		if (
			0 == strcmp(name, "modelToWorld")
		||	0 == strcmp(name, "worldToModel")
		) {
			final ptype = cgGetParameterType(p);
			if (ptype != CG_FLOAT3x4 && ptype != CG_HALF3x4) {
				error(
					"modelToWorld and worldToModel uniforms must be float3x4"
					" or half3x4, not '{}'", fromStringz(cgGetTypeString(ptype))
				);
			}
			
			return true;
		}

		if (0 == strcmp(name, "modelScale")) {
			final ptype = cgGetParameterType(p);
			if (ptype != CG_FLOAT3 && ptype != CG_HALF3) {
				error(
					"The modelScale uniform must be float3"
					" or half3, not '{}'", fromStringz(cgGetTypeString(ptype))
				);
			}
			
			return true;
		}
		
		return false;
	}
	
	
	RegisteredParam* createParam(cstring name, CGparameter handle) {
		final p = mem.alloc!(RegisteredParam);
		final n = mem.allocArray!(char)(name.length);
		n[] = name;
		p.name = cast(string)n;
		p.handle = handle;
		
		defaultHandleCgError();

		final pclass = cgGetParameterClass(handle);
		
		// We should be operating on individual fields of arrays
		// as we're using leaf params. Not to mention that param arrays
		// are broken (or used to be around Cg 2.1).
		assert (pclass != CG_PARAMETERCLASS_ARRAY);
		
		TypeInfo getScalarTypeInfo() {
			final baseType = cgGetParameterBaseType(handle);
			switch (baseType) {
				case CG_FLOAT:
					p.baseType = ParamBaseType.Float;
					return typeid(float);
					
				case CG_INT:
					p.baseType = ParamBaseType.Int;
					return typeid(int);
				
				default: {
					error(
						"Parameters of type '{}' are not currently supported.",
						fromStringz(cgGetTypeString(baseType))
					);
				} break;
			}
			
			return null;	// should never get here
		}
		
		switch (pclass) {
			case CG_PARAMETERCLASS_SCALAR:{
				p.typeInfo = getScalarTypeInfo();
				p.numFields = 1;
			} break;

			case CG_PARAMETERCLASS_VECTOR: {
				int numFields =
					cgGetParameterRows(handle) * cgGetParameterColumns(handle);
				assert (numFields >= 0 && numFields < cast(int)ushort.max);
				p.numFields = cast(ushort)numFields;

				final scalarTypeInfo = getScalarTypeInfo();
					
				static typeInfos = [
					[ typeid(vec2), typeid(vec3), typeid(vec4) ],
					[ typeid(vec2i), typeid(vec3i), typeid(vec4i) ],
				];
				
				int scalarType = -1;
				if (scalarTypeInfo is typeid(float)) {
					scalarType = 0;
				}
				else if (scalarTypeInfo is typeid(int)) {
					scalarType = 1;
				}
				
				if (numFields >= 2 && numFields <= 4 && scalarType != -1) {
					p.typeInfo = typeInfos[scalarType][numFields-2];
				} else {
					error(
						"Parameters of type '{}' are not currently supported.",
						fromStringz(cgGetTypeString(cgGetParameterType(handle)))
					);
				}
			} break;
			
			case CG_PARAMETERCLASS_MATRIX: {
				int numRows = cgGetParameterRows(handle);
				int numCols = cgGetParameterColumns(handle);

				final scalarTypeInfo = getScalarTypeInfo();

				static typeInfos = [
					[ typeid(mat2), typeid(mat3), typeid(mat34), typeid(mat4) ]
				];
				static const vec2i[] matSizes = [
					{x:2, y:2}, {x:3, y:3}, {x:3, y:4}, {x:4, y:4}
				];
				
				int scalarType = -1;
				if (scalarTypeInfo is typeid(float)) {
					scalarType = 0;
				}
				
				int sizeIdx = -1;
				final wantedSize = vec2i(numRows, numCols);
				
				log.info("wanted matrix size: {}", wantedSize);
				
				foreach (i, s; matSizes) {
					// must be equal in the number of rows due to sending
					// the data in a column-major format to OpenGL
					if (wantedSize.x == s.x && wantedSize.y <= s.y) {
						sizeIdx = i;
						break;
					}
				}
				
				if (scalarType != -1 && sizeIdx != -1) {
					p.typeInfo	= typeInfos[scalarType][sizeIdx];
					final ms = matSizes[sizeIdx];
					final nf = ms.x * ms.y;
					assert (nf >= 0 && nf < cast(int)ushort.max);
					p.numFields	= cast(ushort)nf;
				} else {
					error(
						"Parameters of type '{}' are not currently supported.",
						fromStringz(cgGetTypeString(cgGetParameterType(handle)))
					);
				}
				
				log.info("chosen {}", p.typeInfo);
			} break;

			case CG_PARAMETERCLASS_SAMPLER: {
				p.typeInfo = typeid(Texture);
				p.numFields = 1;
			} break;
			
			default: {
				error(
					"Parameters of class '{}' are not currently supported.",
					fromStringz(cgGetParameterClassString(pclass))
				);
			} break;
		}
		
		defaultHandleCgError();

		return p;
	}

	void registerFoundParam(
		CGparameter param,
		bool share,
		GPUDomain domain,
		cstring scopeName = null
	) {
		final variability = cgGetParameterVariability(param);
		
		cstring name = fromStringz(cgGetParameterName(param));
		if (scopeName.length > 0) {
			cstring n2 = mem.allocArray!(char)(
				scopeName.length + 1 + name.length
			);
			
			n2[0..scopeName.length] = scopeName;
			n2[scopeName.length] = '.';
			n2[scopeName.length+1..$] = name;
			name = n2;
		}
		
		int uniformBufferIdx	= -1;
		int uniformBufferOffset	= 0;
		int uniformGPUSize		= 0;
		
		if (share) {
			int numCon = cgGetNumConnectedToParameters(param);

			for (int i = 0; i < numCon; ++i) {
				final	conPar = cgGetConnectedToParameter(param, i);
				final	bufIdx = cgGetParameterBufferIndex(conPar);
				int		bufOff = 0;
				
				if (bufIdx != -1) {
					bufOff = cgGetParameterBufferOffset(conPar);
					uniformGPUSize = cgGetParameterResourceSize(conPar);
				}
				
				defaultHandleCgError();
				
				if (-1 == uniformBufferIdx) {
					uniformBufferIdx = bufIdx;
					uniformBufferOffset = bufOff;
				} else if (bufIdx != -1) {
					if (uniformBufferIdx != bufIdx) {
						error(
							"Shared effect parameter '{}' has multiple buffer"
							" indices: {} and {}",
							name,
							uniformBufferIdx,
							bufIdx
						);
					}

					if (uniformBufferOffset != bufOff) {
						error(
							"Shared effect parameter '{}' has multiple buffer"
							" offsets: {} and {}",
							name,
							uniformBufferOffset,
							bufOff
						);
					}
				}
			}
		} else {
			uniformBufferIdx = cgGetParameterBufferIndex(param);
			if (uniformBufferIdx != -1) {
				uniformBufferOffset = cgGetParameterBufferOffset(param);
				uniformGPUSize = cgGetParameterResourceSize(param);
			}
		}
		
		if (uniformBufferIdx != -1) {
			assert (CG_UNIFORM == variability);
		}
		
		switch (variability) {
			case CG_VARYING: {
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
				log.trace(
					"Uniform {} input param: {}",
					share ? "Shared" : GPUDomainName(domain),
					name
				);
				
				enum Scope {
					Object,
					ObjectInstance,
					Effect,
					Buffer
				}
				
				Scope sc = -1 == uniformBufferIdx ? Scope.Object : Scope.Buffer;
				
				if (Scope.Object == sc && isObjectInstanceParam(param)) {
					sc = Scope.ObjectInstance;
				}
				
				if (sc != Scope.Buffer)	for (
					auto ann = cgGetFirstParameterAnnotation(param);
					ann;
					ann = cgGetNextAnnotation(ann)
				) {
					final annName = fromStringz(cgGetAnnotationName(ann));
					switch (annName) {
						case "scope": {
							final annType = cgGetAnnotationType(ann);
							
							if (annType != CG_STRING) {
								error(
									"Wrong type for 'scope' annotation of"
									" parameter '{}': Got {}, expected a string.",
									name,
									cgGetTypeString(annType)
								);
							}
							
							final annVal =
								fromStringz(cgGetStringAnnotationValue(ann));
								
							switch (annVal) {
								case "object": {
									sc = Scope.Object;
								} break;
								
								case "effect": {
									sc = Scope.Effect;
								} break;
								
								default: {
									error(
										"Wrong value for 'scope' annotation of"
										" parameter '{}': Got '{}', while the only"
										" valid values are 'object' and 'effect'.",
										name,
										annVal
									);
								}
							}
						} break;
						
						default: {
							error(
								"Unrecognized annotation '{}' for parameter '{}'.",
								annName, name
							);
						}
					}
				}
				
				final reg = createParam(name, param);

				void addUniformToScope(ref UniformScope scope_) {
					with (scope_) {
						size_t paramOffset = uniformStorageNeeded;
						size_t paramSize = reg.typeInfo.tsize();
						
						if (Scope.Buffer == sc) {
							paramOffset = uniformBufferOffset;
							assert (paramSize <= uniformGPUSize);
							paramSize = uniformGPUSize;
						}
						
						reg.dataSlice = UniformDataSlice(paramOffset, paramSize);
						
						if (Scope.Buffer == sc) {
							size_t paramEnd = paramOffset + paramSize;
							
							if (paramEnd > uniformStorageNeeded) {
								uniformStorageNeeded = paramEnd;
							}
						} else {
							uniformStorageNeeded += paramSize;
							
							// align to 4 bytes
							uniformStorageNeeded += 3;
							uniformStorageNeeded &= ~0b11;
						}

						if (uniforms) {
							uniforms.list ~= reg;
						} else {
							uniforms = reg;
						}
						++numUniforms;
					}
				}

				switch (sc) {
					case Scope.Object: {
						addUniformToScope(objectScope);
					} break;
					
					case Scope.Effect: {
						addUniformToScope(effectScope);
					} break;
					
					case Scope.Buffer: {
						addUniformToScope(bufferScope[uniformBufferIdx]);
						if (uniformBufferIdx > maxUniformBufferIdx) {
							maxUniformBufferIdx = uniformBufferIdx;
						}
					} break;
					
					case Scope.ObjectInstance: {
						addUniformToScope(objectInstanceScope);
					} break;
					
					default: assert (false);
				}
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
		int numUnifBufs = maxUniformBufferIdx+1;
		
		// Calculate the storage needed for uniform param names
		
		int stringLenNeeded = 0;
		with (objectScope) {
			if (numUniforms > 0) foreach (ref p; uniforms.list) {
				stringLenNeeded += p.name.length+1;
			}
		}
		with (effectScope) {
			if (numUniforms > 0) foreach (ref p; uniforms.list) {
				stringLenNeeded += p.name.length+1;
			}
		}
		for (int i = 0; i < numUnifBufs; ++i) {
			with (bufferScope[i]) {
				if (numUniforms > 0) foreach (ref p; uniforms.list) {
					stringLenNeeded += p.name.length+1;
				}
			}
		}
		with (objectInstanceScope) {
			if (numUniforms > 0) foreach (ref p; uniforms.list) {
				stringLenNeeded += p.name.length+1;
			}
		}
		foreach (ref p; varyings.list) {
			stringLenNeeded += p.name.length+1;
		}
		
		// Allocate the space for uniform param names as one chunk
		
		char* nameData = cast(char*)mainHeap.allocRaw(stringLenNeeded);
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

		effect.instanceDataSize = 0;
		
		void copyUniforms(ref UniformScope sc, RawUniformParamGroup* pg) {
			final arr = &pg.params;
			arr.resize(sc.numUniforms);
			
			foreach (i, ref p; sc.uniforms.list) {
				arr.name[i] = convertParamName(p.name);
				arr.param[i] = cast(UniformParam)p.handle;
				arr.numFields[i] = p.numFields;
				arr.baseType[i] = p.baseType;
				arr.typeInfo[i] = p.typeInfo;
				arr.dataSlice[i] = p.dataSlice;
			}
		}
		
		// Create object-scope param groups

		if (objectScope.numUniforms > 0) {
			final arr = effect.uniformParams();
			copyUniforms(objectScope, arr);
			effect.uniformPtrsDataSize =
				objectScope.numUniforms * size_t.sizeof;
				//objectScope.uniformStorageNeeded;
			effect.instanceDataSize += effect.uniformPtrsDataSize;
		}
		
		// Create effect-scope param groups

		if (effectScope.numUniforms > 0) {
			final arr = effect.effectUniformParams();
			copyUniforms(effectScope, arr);
			//effect.uniformData = mainHeap.allocRaw(effectScope.uniformStorageNeeded);
			
			effect.uniformPtrsData = cast(void**)
				mainHeap.allocRaw(effectScope.numUniforms * size_t.sizeof);
				
			memset(effect.uniformPtrsData, 0,
				effectScope.numUniforms * size_t.sizeof
				//effectScope.uniformStorageNeeded
			);
		}
		
		// Create uniform buffer param groups
		
		if (maxUniformBufferIdx > -1) {
			final int unifBufMemSize = UniformParamGroup.sizeof * numUnifBufs;
			
			effect.uniformBuffers =
				(cast(UniformParamGroup*)mainHeap.allocRaw(
					unifBufMemSize
				))[0..numUnifBufs];
				
			memset(effect.uniformBuffers.ptr, 0, unifBufMemSize);
			
			log.info(
				"Set up the effect for {} uniform buffer object{}.",
				numUnifBufs,
				numUnifBufs > 1 ? "s" : ""
			);
				
			for (int i = 0; i < numUnifBufs; ++i) {
				copyUniforms(
					bufferScope[i],
					cast(RawUniformParamGroup*)&effect.uniformBuffers[i]
				);
				
				effect.uniformBuffers[i].overrideTotalSize(
					bufferScope[i].uniformStorageNeeded
				);
			}
		}
		
		// Create object instance-scope param groups

		if (objectInstanceScope.numUniforms > 0) {
			final arr = effect.objectInstanceUniformParams();
			copyUniforms(objectInstanceScope, arr);
		}
		

		// Create varying param groups

		if (numVaryings > 0) {
			final arr = &effect.varyingParams;
			arr.resize(numVaryings);
			
			foreach (i, ref p; varyings.list) {
				arr.name[i] = convertParamName(p.name);
				arr.param[i] = cast(VaryingParam)p.handle;
			}
		}
		
		// ----

		assert (nameData is nameDataEnd);

		effect.varyingParamsOffset = effect.instanceDataSize;
		effect.instanceDataSize += VaryingParamData.sizeof * numVaryings;
		
		// total size of one-bit flags held for each varying, chunked in size_t-s
		size_t perVaryingFlagsSize = void; {
			const flagFieldBits = size_t.sizeof * 8;
			
			size_t numFlagFields =
				(numVaryings + (flagFieldBits - 1))
				/ flagFieldBits;
			
			perVaryingFlagsSize = numFlagFields * flagFieldBits / 8;
		}
		
		{
			// pad flags to size_t.sizeof
			effect.instanceDataSize += size_t.sizeof - 1;
			effect.instanceDataSize &= ~(size_t.sizeof - 1);
			
			effect.varyingParamsDirtyOffset = effect.instanceDataSize;
			effect.instanceDataSize += perVaryingFlagsSize;
		}
		
		
		log.info(
			"Total bytes needed for effect instance: {}.",
			effect.instanceDataSize
		);
	}
	
	
	struct UniformScope {
		RegisteredParam*	uniforms = null;
		int					numUniforms = 0;
		size_t				uniformStorageNeeded = 0;
	}
	
	RegisteredParam*	varyings = null;
	int					numVaryings = 0;
	
	UniformScope		objectScope;
	UniformScope		effectScope;
	
	UniformScope[MaxUniformBuffers]
						bufferScope;
						
	UniformScope		objectInstanceScope;
						
	int					maxUniformBufferIdx = -1;
	
	StackBufferUnsafe	mem;
}
