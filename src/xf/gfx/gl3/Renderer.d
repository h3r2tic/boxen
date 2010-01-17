module xf.gfx.gl3.Renderer;

public {
	import
		xf.gfx.Buffer,
		xf.gfx.VertexArray,
		xf.gfx.VertexBuffer,
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
		_cgCompiler = new CgCompiler;
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
	

	// implements IBufferMngr
	void setData(BufferHandle handle, size_t length, void* data, BufferUsage usage) {
		if (auto buf = _getBuffer(handle)) {
			_bindBuffer(buf.target, buf.handle);
			gl.BufferData(buf.target, length, data, enumToGL(usage));
		}
	}
	

	// implements IBufferMngr
	void setSubData(BufferHandle handle, ptrdiff_t offset, size_t length, void* data) {
		if (auto buf = _getBuffer(handle)) {
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

	VertexBuffer createVertexBuffer() {
		final buf = toResourceHandle(
			_buffers.alloc((BufferImpl* n) {
				n.refCount = 1;
				gl.GenBuffers(1, &n.handle);
				n.target = ARRAY_BUFFER;
			})
		);
		return *cast(VertexBuffer*)&buf;
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

		effect.bind();
		
		void setObjUniforms(GPUEffectInstance* obj) {
			final up = &effect.uniformParams;
			final numUniforms = up.length;
			void* base = obj.getUniformsDataPtr();
			
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
		
		foreach (obj; objects) {
			auto efInst = obj.effect;
			setObjUniforms(efInst);
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
	GLenum		target;
}


private struct VertexArrayImpl {
	ptrdiff_t	refCount;
	GLuint		handle;
}


private GLenum enumToGL(BufferAccess bits) {
	GLenum en = 0;
	
	if (bits & bits.Read) {
		if (bits & bits.Write) {
			en |= READ_WRITE;
		} else {
			en |= READ_ONLY;
		}
	} else {
		if (bits & bits.Write) {
			en |= WRITE_ONLY;
		} else {
			error("Invalid BufferAccess enum: {}", bits);
		}
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
