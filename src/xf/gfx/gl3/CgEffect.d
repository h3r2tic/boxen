module xf.gfx.gl3.CgEffect;

public {
	import xf.gfx.GPUEffect;
}

private {
	import xf.Common;	
	import xf.gfx.Log : log = gfxLog, error = gfxError;
	import xf.gfx.api.gl3.Cg;
	import xf.gfx.VertexBuffer;
	
	import xf.mem.StackBuffer;
	import xf.mem.OSHeap;
	import xf.utils.IntrusiveList;
	
	// for the typeinfos of vectors and matrices
	import xf.omg.core.LinearAlgebra;
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
		this.instanceFreeList.itemSize = this.totalInstanceSize();
		
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
	
	RegisteredParam* createParam(cstring name, CGparameter handle) {
		final p = mem.alloc!(RegisteredParam);
		final n = mem.allocArray!(char)(name.length);
		n[] = name;
		p.name = cast(string)n;
		p.handle = handle;
		
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
			} break;

			case CG_PARAMETERCLASS_SAMPLER: {
				log.warn("TODO: CG_PARAMETERCLASS_SAMPLER");
			} break;
			
			default: {
				error(
					"Parameters of class '{}' are not currently supported.",
					fromStringz(cgGetParameterClassString(pclass))
				);
			} break;
		}
		
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
				
				final reg = createParam(name, param);

				size_t paramOffset = uniformStorageNeeded;
				size_t paramSize = reg.typeInfo.tsize();
				reg.dataSlice = UniformDataSlice(paramOffset, paramSize);
				
				uniformStorageNeeded += paramSize;
				
				// align to 4 bytes
				uniformStorageNeeded += 3;
				uniformStorageNeeded &= ~0b11;

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
			"Registered a total of {} uniforms ({} bytes) and {} varyings.",
			numUniforms,
			uniformStorageNeeded,
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

		effect.instanceDataSize = 0;
		
		if (numUniforms > 0) {
			final arr = &effect.uniformParams;
			arr.resize(numUniforms);
			
			foreach (i, ref p; uniforms.list) {
				arr.name[i] = convertParamName(p.name);
				arr.param[i] = cast(UniformParam)p.handle;
				arr.numFields[i] = p.numFields;
				arr.baseType[i] = p.baseType;
				arr.typeInfo[i] = p.typeInfo;
				arr.dataSlice[i] = p.dataSlice;
			}
		}
		effect.instanceDataSize += uniformStorageNeeded;

		if (numVaryings > 0) {
			final arr = &effect.varyingParams;
			arr.resize(numVaryings);
			
			foreach (i, ref p; varyings.list) {
				arr.name[i] = convertParamName(p.name);
				arr.param[i] = cast(VaryingParam)p.handle;
				arr.dataOffset[i] = effect.instanceDataSize;
				effect.instanceDataSize += VertexBuffer.sizeof;
			}
		}
		
		assert (nameData is nameDataEnd);
	}
	
	RegisteredParam* uniforms = null;
	RegisteredParam* varyings = null;
	
	int numUniforms = 0;
	int numVaryings = 0;
	
	size_t uniformStorageNeeded = 0;
	
	StackBufferUnsafe mem;
}

