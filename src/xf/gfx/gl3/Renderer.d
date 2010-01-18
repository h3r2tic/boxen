module xf.gfx.gl3.Renderer;

public {
	import
		xf.gfx.Buffer,
		xf.gfx.VertexArray,
		xf.gfx.VertexBuffer,
		xf.gfx.UniformBuffer,
		xf.gfx.Mesh,
		xf.gfx.gl3.Cg;
}

private {
	import
		xf.Common,

		xf.gfx.gl3.CgEffect,
		xf.gfx.gl3.Cg,
	
		xf.gfx.Resource,
		xf.gfx.Buffer,

		xf.gfx.api.gl3.Cg,
		xf.gfx.api.gl3.OpenGL,
		xf.gfx.api.gl3.ext.ARB_map_buffer_range,
		xf.gfx.api.gl3.ext.ARB_vertex_array_object,

		xf.mem.FreeList,
		xf.mem.Array,
		
		xf.utils.ResourcePool;

	import
		xf.gfx.Log : log = gfxLog, error = gfxError;
}



class Renderer : IBufferMngr, IVertexArrayMngr {
	// at the front because otherwise DMD is a bitch about forward refs
	private {
		GL			gl;
		CgCompiler	_cgCompiler;
		
		ThreadUnsafeResourcePool!(BufferImpl, BufferHandle)
			_buffers;
			
		ThreadUnsafeResourcePool!(VertexArrayImpl, VertexArrayHandle)
			_vertexArrays;
	}


	this(GL gl) {
		_cgCompiler = new CgCompiler(gl);
		this.gl[] = gl;
		
		_buffers.initialize();
		_vertexArrays.initialize();
	}
	
	
	GPUEffect createEffect(cstring name, EffectSource source) {
		return _cgCompiler.createEffect(name, source);
	}
	
	
	GPUEffectInstance* instantiateEffect(GPUEffect effect) {
		final inst = effect.createRawInstance();
		inst._vertexArray = createVertexArray();
		return inst;
	}
	
	
	private void _bindBuffer(GLenum target, GLuint handle) {
		// TODO: laziness
		gl.BindBuffer(target, handle);
	}
	
	
	BufferImpl* _getBuffer(BufferHandle h) {
		if (auto resData = _buffers.find(h)) {
			assert (resData.res !is null);
			return resData.res;
		} else {
			return null;
		}
	}
	
	
	// implements IBufferMngr
	void mapRange(
		BufferHandle handle,
		size_t offset,
		size_t length,
		BufferAccess access,
		void delegate(void[]) dg
	) {
		if (auto buf = _getBuffer(handle)) {
			/+if (UNIFORM_BUFFER == buf.target) {
				if (offset != 0) {
					error("Offset not supported in mapRange for uniform buffers.");
				}
				if (length != buf.size) {
					error("Partial mapping not supported in mapRange for uniform buffers.");
				}
				
				final ptr = cgMapBuffer(buf.cgHandle, enumToCg(access));
				
				defaultHandleCgError();

				scope (exit) {
					cgUnmapBuffer(buf.cgHandle);
					defaultHandleCgError();
				}
				
				dg(ptr[0..buf.size]);
			} else +/{
				_bindBuffer(buf.target, buf.handle);
				
				final ptr = gl.MapBufferRange(
					buf.target,
					offset,
					length,
					enumToGL(access)
				);
				
				scope (exit) {
					gl.UnmapBuffer(buf.target);
				}
				
				dg(ptr[0..length]);
			}
		}
	}
	

	// implements IBufferMngr
	void setData(BufferHandle handle, size_t length, void* data, BufferUsage usage) {
		if (auto buf = _getBuffer(handle)) {
			_bindBuffer(buf.target, buf.handle);
			gl.BufferData(buf.target, length, data, enumToGL(usage));
			buf.size = length;
		}
	}
	

	// implements IBufferMngr
	void setSubData(BufferHandle handle, ptrdiff_t offset, size_t length, void* data) {
		if (auto buf = _getBuffer(handle)) {
			//cgSetBufferSubData(buf.cgHandle, offset, length, data);
			_bindBuffer(buf.target, buf.handle);
			gl.BufferSubData(buf.target, offset, length, data);
		}
	}


	// implements IBufferMngr
	void flushMappedRange(BufferHandle handle, size_t offset, size_t length) {
		if (auto buf = _getBuffer(handle)) {
			_bindBuffer(buf.target, buf.handle);

			gl.FlushMappedBufferRange(
				buf.target,
				offset,
				length
			);
		}
	}


	// implements IBufferMngr
	size_t getApiHandle(BufferHandle handle) {
		if (auto buf = _getBuffer(handle)) {
			return buf.handle;
		} else {
			return 0;
		}
	}
	
	/+// implements IBufferMngr
	size_t getShaderApiHandle(BufferHandle handle) {
		if (auto buf = _getBuffer(handle)) {
			return cast(size_t)buf.cgHandle;
		} else {
			return 0;
		}
	}+/
	
	// implements IBufferMngr
	void bind(BufferHandle handle) {
		if (auto buf = _getBuffer(handle)) {
			_bindBuffer(buf.target, buf.handle);
		}
	}

	
	// implements IVertexArrayMngr
	void bind(VertexArrayHandle h) {
		if (auto resData = _vertexArrays.find(h)) {
			gl.BindVertexArray(resData.res.handle);
		}
	}
	
	
	// Vertex Array ----
	
	private {
		VertexArray toResourceHandle(_vertexArrays.ResourceReturn resource) {
			VertexArray res = void;
			res._resHandle = resource.handle;

			res._resMngr = cast(void*)cast(IVertexArrayMngr)this;
			res._refMngr = cast(void*)this;
			final rcnt = &resCountVertexArray;
			res._resCountAdjust = rcnt.funcptr;

			return res;
		}
		
		
		bool resCountVertexArray(VertexArrayHandle h, int cnt) {
			if (auto resData = _vertexArrays.find(h, cnt > 0)) {
				final res = resData.res;
				bool goodBefore = res.refCount > 0;
				res.refCount += cnt;
				if (res.refCount > 0) {
					return true;
				} else if (goodBefore) {
					_vertexArrays.free(resData);
				}
			}
			
			return false;
		}
	}


	VertexArray createVertexArray() {
		return toResourceHandle(
			_vertexArrays.alloc((VertexArrayImpl* n) {
				n.refCount = 1;
				gl.GenVertexArrays(1, &n.handle);
			})
		);
	}
	
	// ---- VertexBuffer

	private {
		Buffer toResourceHandle(_buffers.ResourceReturn resource) {
			Buffer res = void;
			res._resHandle = resource.handle;
			
			res._resMngr = cast(void*)cast(IBufferMngr)this;
			res._refMngr = cast(void*)this;
			final rcnt = &resCountBuffer;
			res._resCountAdjust = rcnt.funcptr;
			
			return res;
		}
		
		
		bool resCountBuffer(BufferHandle h, int cnt) {
			if (auto resData = _buffers.find(h, cnt > 0)) {
				final res = resData.res;
				bool goodBefore = res.refCount > 0;
				res.refCount += cnt;
				if (res.refCount > 0) {
					return true;
				} else if (goodBefore) {
					_buffers.free(resData);
				}
			}
			
			return false;
		}
	}
	
	
	VertexBuffer createVertexBuffer(BufferUsage usage, void[] data) {
		return createVertexBuffer(usage, data.length, data.ptr);
	}

	VertexBuffer createVertexBuffer(BufferUsage usage, int size, void* data) {
		return cast(VertexBuffer)
			createBuffer(usage, size, data, ARRAY_BUFFER);
	}
	

	UniformBuffer createUniformBuffer(BufferUsage usage, void[] data) {
		return createUniformBuffer(usage, data.length, data.ptr);
	}

	UniformBuffer createUniformBuffer(BufferUsage usage, int size, void* data) {
		return cast(UniformBuffer)
			createBuffer(usage, size, data, UNIFORM_BUFFER);
	}


	Buffer createBuffer(BufferUsage usage, int size, void* data, GLenum target) {
		return toResourceHandle(
			/+_buffers.alloc((BufferImpl* n) {
				n.refCount = 1;
				
				n.cgHandle = cgGLCreateBuffer(
					_cgCompiler.context,
					size,
					data,
					enumToGL(usage)
				);
				
				n.handle = cgGLGetBufferObject(n.cgHandle);
				n.target = target;
				n.size = size;
			})+/


			_buffers.alloc((BufferImpl* n) {
				n.refCount = 1;
				
				gl.GenBuffers(1, &n.handle);
				gl.BindBuffer(target, n.handle);
				gl.BufferData(
					target,
					size,
					data,
					enumToGL(usage)
				);
				
				n.target = target;
				n.size = size;
			})
		);
	}
	
	
	// ---- HACK
	
	void render(Mesh[] objects ...) {
		if (0 == objects.length) {
			return;
		}
		
		GPUEffect effect = objects[0].effect._proto;
		
		assert ({
			foreach (o; objects[1..$]) {
				if (o.effect._proto !is effect) {
					return false;
				}
			}
			return true;
		}(), "All objects must have the same GPUEffect");

		void setObjUniforms(void* base, RawUniformParamGroup* paramGroup) {
			final up = &paramGroup.params;
			final numUniforms = up.length;
			
			for (int ui = 0; ui < numUniforms; ++ui) {
				switch (up.baseType[ui]) {
					case ParamBaseType.Float: {
						cgSetParameterValuefc(
							cast(CGparameter)up.param[ui],
							up.numFields[ui],
							cast(float*)(base + up.dataSlice[ui].offset)
						);
					} break;

					case ParamBaseType.Int: {
						cgSetParameterValueic(
							cast(CGparameter)up.param[ui],
							up.numFields[ui],
							cast(int*)(base + up.dataSlice[ui].offset)
						);
					} break;
					
					default: assert (false);
				}
			}
		}
		
		void setObjVaryings(GPUEffectInstance* obj) {
			final vp = &effect.varyingParams;
			final numVaryings = vp.length;
			
			auto flags = obj.getVaryingParamDirtyFlagsPtr();
			auto varyingData = obj.getVaryingParamDataPtr();
			
			alias typeof(*flags) flagFieldType;
			const buffersPerFlag = flagFieldType.sizeof * 8;
			
			for (
				int varyingBase = 0;
				
				varyingBase < numVaryings;
				
				varyingBase += buffersPerFlag,
				++flags,
				varyingData += buffersPerFlag
			) {
				if (*flags != 0) {
					// one of the buffers in varyingBase .. varyingBase + buffersPerFlag
					// needs to be updated
					
					static if (
						ParameterTupleOf!(intrinsic.bsf)[0].sizeof
						==
						flagFieldType.sizeof
					) {
						auto flag = *flags;

					updateSingle:
						final idx = intrinsic.bsf(flag);
						final data = varyingData + idx;
						
						if (data.currentBuffer.valid) {
							data.currentBuffer.dispose();
						}
						
						final buf = &data.currentBuffer;
						final attr = &data.currentAttrib;

						*buf = data.newBuffer;
						*attr = data.newAttrib;
						
						GLenum glType = void;
						switch (attr.scalarType) {
							case attr.ScalarType.Float: {
								glType = FLOAT;
							} break;
							
							default: {
								error("Unhandled scalar type: {}", attr.scalarType);
							}
						}
						
						final param = cast(CGparameter)
							obj._proto.varyingParams.param[varyingBase+idx];

						buf.bind();
						cgGLEnableClientState(param);
						cgGLSetParameterPointer(
							param,
							attr.numFields(),
							glType,
							attr.stride,
							cast(void*)attr.offset
						);
						
						defaultHandleCgError();
						
						// should be a SUB instruction followed by JZ
						flag -= cast(flagFieldType)1 << idx;
						if (flag != 0) {
							goto updateSingle;
						}
						
						// write back the flag
						*flags = flag;
					} else {
						static assert (false, "TODO");
					}
				}
			}
		}
		
		effect.bind();
		setObjUniforms(
			effect.getUniformsDataPtr(),
			effect.getUniformParamGroup()
		);

		foreach (obj; objects) {
			auto efInst = obj.effect;
			setObjUniforms(
				efInst.getUniformsDataPtr(),
				efInst.getUniformParamGroup()
			);
			efInst._vertexArray.bind();
			setObjVaryings(efInst);
			
			gl.DrawElements(
				TRIANGLES,
				obj.indices.length,
				UNSIGNED_INT,
				obj.indices.ptr
			);
		}
	}
}



private struct BufferImpl {
	ptrdiff_t	refCount;
	GLuint		handle;
	//CGbuffer	cgHandle;
	GLenum		target;
	size_t		size;
}


private struct VertexArrayImpl {
	ptrdiff_t	refCount;
	GLuint		handle;
}


private GLenum enumToGL(BufferAccess bits) {
	GLenum en = 0;
	
	if (bits & bits.Read) {
		en |= xf.gfx.api.gl3.GL.MAP_READ_BIT;
	}
	
	if (bits & bits.Write) {
		en |= xf.gfx.api.gl3.GL.MAP_WRITE_BIT;
	}
	
	if (bits & bits.InvalidateRange) {
		en |= xf.gfx.api.gl3.GL.MAP_INVALIDATE_RANGE_BIT;
	}
	
	if (bits & bits.InvalidateBuffer) {
		en |= xf.gfx.api.gl3.GL.MAP_INVALIDATE_BUFFER_BIT;
	}
	
	if (bits & bits.FlushExplicit) {
		en |= xf.gfx.api.gl3.GL.MAP_FLUSH_EXPLICIT_BIT;
	}
	
	if (bits & bits.Unsynchronized) {
		en |= xf.gfx.api.gl3.GL.MAP_UNSYNCHRONIZED_BIT;
	}
	
	return en;
}


private GLenum enumToGL(BufferUsage usage) {
	static const map = [
		STREAM_DRAW,
		STREAM_READ,
		STREAM_COPY,
		STATIC_DRAW,
		STATIC_READ,
		STATIC_COPY,
		DYNAMIC_DRAW,
		DYNAMIC_READ,
		DYNAMIC_COPY
	];
	
	return map[usage];
}


private CGbufferaccess enumToCg(BufferAccess bits) {
	CGbufferaccess en;
	
	if (bits & bits.Read) {
		if (bits & bits.Write) {
			en |= CG_MAP_READ_WRITE;
		} else {
			en |= CG_MAP_READ;
		}
	} else {
		en |= CG_MAP_WRITE;
	}
	
	if (bits & (bits.InvalidateRange | bits.InvalidateBuffer)) {
		en |= CG_MAP_WRITE_DISCARD;
	}
	
	return en;
}
