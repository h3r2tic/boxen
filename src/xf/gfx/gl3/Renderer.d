module xf.gfx.gl3.Renderer;

public {
	import
		xf.gfx.Buffer,
		xf.gfx.VertexArray,
		xf.gfx.VertexBuffer,
		xf.gfx.IndexBuffer,
		xf.gfx.UniformBuffer,
		xf.gfx.Texture,
		xf.gfx.Mesh,
		xf.gfx.IRenderer,
		xf.gfx.RenderList,
		xf.gfx.gl3.Cg;
		
	import
		xf.img.Image,
		xf.omg.core.LinearAlgebra;
		
	import
		xf.mem.MainHeap,
		xf.mem.StackBuffer;
}

private {
	import
		xf.Common,

		xf.gfx.gl3.CgEffect,
		xf.gfx.gl3.Cg,
		xf.gfx.gl3.TextureInternalFormat,
	
		xf.gfx.Resource,
		xf.gfx.Buffer,

		xf.gfx.api.gl3.Cg,
		xf.gfx.api.gl3.OpenGL,
		xf.gfx.api.gl3.ext.ARB_map_buffer_range,
		xf.gfx.api.gl3.ext.ARB_vertex_array_object,
		xf.gfx.api.gl3.ext.ARB_half_float_pixel,
		xf.gfx.api.gl3.ext.ARB_framebuffer_object,

		xf.mem.FreeList,
		xf.mem.Array,
		
		xf.utils.ResourcePool;

	import
		xf.gfx.Log : log = gfxLog, error = gfxError;
}



class Renderer : IRenderer {
	// at the front because otherwise DMD is a bitch about forward refs
	private {
		GL			gl;
		CgCompiler	_cgCompiler;
		
		ThreadUnsafeResourcePool!(BufferImpl, BufferHandle)
			_buffers;
			
		ThreadUnsafeResourcePool!(VertexArrayImpl, VertexArrayHandle)
			_vertexArrays;

		ThreadUnsafeResourcePool!(TextureImpl, TextureHandle)
			_textures;
		
		// GCd for now
		EffectData[]
			_effects;

		ThreadUnsafeResourcePool!(EffectInstanceProxy, EffectInstanceHandle)
			_effectInstances;
	}


	this(GL gl) {
		_cgCompiler = new CgCompiler(gl);
		this.gl[] = gl;
		
		_buffers.initialize();
		_vertexArrays.initialize();
		_textures.initialize();
		_effectInstances.initialize();
		_renderLists.initialize();
	}
	
	
	// RenderList ----
	
	NondestructiveFreeList!(RenderList)	_renderLists;
	
	RenderList* createRenderList() {
		final reused = !_renderLists.isEmpty();
		final res = _renderLists.alloc();
		if (!reused) {
			*res = RenderList.init;
		}
		if (res.bins.length != _effects.length) {
			res.bins.resize(_effects.length);
		}
		res.clear();
		return res;
	}
	
	
	void disposeRenderList(RenderList* rl) {
		_renderLists.free(rl);
	}
	
	
	// Effect ----
	
	
	Effect createEffect(cstring name, EffectSource source) {
		final effect = _cgCompiler.createEffect(name, source);
		effect._idxInRenderer = _effects.length;
		effect.renderOrdinal = _effects.length;
		// TODO: effectsSorted = false
		_effects ~= EffectData(effect);
		return effect;
	}
	
	
	protected EffectData* getEffectData(Effect effect) {
		final idx = effect._idxInRenderer;
		assert (idx < _effects.length);
		final res = &_effects[idx];
		assert (res.effect is effect);
		return res;
	}
	
	
	// Mesh ----
	

	// implements IMeshMngr
	/// Allocated using mainHeap
	Mesh[] createMeshes(int num) {
		if (0 == num) {
			return null;
		}
		
		final meshes = (cast(Mesh*)mainHeap.allocRaw(
			Mesh.sizeof * num
		))[0..num];
		
		meshes[] = Mesh.init;
		return meshes;
	}
	
	
	// implements IMeshMngr
	void destroyMeshes(ref Mesh[] meshes) {
		if (meshes is null) {
			return;
		}
		
		mainHeap.freeRaw(meshes.ptr);
		meshes = null;
	}


	// Vertex Array ----
	
	
	// TODO: memory pooling
	EffectInstanceImpl* allocateEffectInstance(Effect effect) {
		final inst = cast(EffectInstanceImpl*)
			mainHeap.allocRaw(effect.totalInstanceSize);
		*inst = EffectInstanceImpl.init;
		memset(inst+1, 0, effect.instanceDataSize);
		inst._vertexArray = createVertexArray();
		inst._proto = effect;
		
		final ed = getEffectData(effect);
		ed.addInstance(inst);
		
		return inst;
	}
	
	

	EffectInstance toResourceHandle(_effectInstances.ResourceReturn resource) {
		EffectInstance res = void;
		res._resHandle = resource.handle;

		res._resMngr = cast(void*)cast(IEffectMngr)this;
		res._refMngr = cast(void*)this;
		final rcnt = &resCountEffectInstance;
		res._resCountAdjust = rcnt.funcptr;

		return res;
	}

	bool resCountEffectInstance(EffectInstanceHandle h, int cnt) {
		if (auto resData = _effectInstances.find(h, cnt > 0)) {
			final res = resData.res;
			bool goodBefore = res.refCount > 0;
			res.refCount += cnt;
			if (res.refCount > 0) {
				return true;
			} else if (goodBefore) {
				// TODO: free the other shit
				_effectInstances.free(resData);
			}
		}
		
		return false;
	}

	// implements IEffectMngr
	EffectInstance instantiateEffect(Effect effect) {
		return toResourceHandle(
			_effectInstances.alloc((EffectInstanceProxy* n) {
				n.impl = allocateEffectInstance(effect);
				n.refCount = 1;
			})
		);
	}


	// implements IEffectMngr
	Effect getEffect(EffectInstanceHandle h) {
		if (auto resData = _effectInstances.find(h)) {
			assert (resData.res !is null);
			final res = resData.res.impl;
			assert (res !is null);
			return res._proto;
		} else {
			return null;
		}
	}

	// implements IEffectMngr
	bool setVarying(EffectInstanceHandle h, cstring name, VertexBuffer buf, VertexAttrib vattr) {
		if (auto resData = _effectInstances.find(h)) {
			assert (resData.res !is null);
			final res = resData.res.impl;
			assert (res !is null);
			return res.setVarying(name, buf, vattr);
		} else {
			return false;
		}
	}

	// implements IEffectMngr
	void* getUniformsDataPtr(EffectInstanceHandle h) {
		if (auto resData = _effectInstances.find(h)) {
			assert (resData.res !is null);
			final res = resData.res.impl;
			assert (res !is null);
			return res.getUniformsDataPtr;
		} else {
			return null;
		}
	}

	// implements IEffectMngr
	VaryingParamData* getVaryingParamDataPtr(EffectInstanceHandle h) {
		if (auto resData = _effectInstances.find(h)) {
			assert (resData.res !is null);
			final res = resData.res.impl;
			assert (res !is null);
			return res.getVaryingParamDataPtr;
		} else {
			return null;
		}
	}

	// implements IEffectMngr
	size_t* getVaryingParamDirtyFlagsPtr(EffectInstanceHandle h) {
		if (auto resData = _effectInstances.find(h)) {
			assert (resData.res !is null);
			final res = resData.res.impl;
			assert (res !is null);
			return res.getVaryingParamDirtyFlagsPtr;
		} else {
			return null;
		}
	}
	
	
	u32 renderOrdinal(EffectInstanceHandle h) {
		final resData = _effectInstances.find(h);
		assert (resData !is null);
		assert (resData.res !is null);
		final res = resData.res.impl;
		assert (res !is null);
		return res.renderOrdinal;
	}
	
	
	// ----
	
	
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
	
	
	// Implements IVertexBufferMngr
	VertexBuffer createVertexBuffer(BufferUsage usage, void[] data) {
		return createVertexBuffer(usage, data.length, data.ptr);
	}

	// Implements IVertexBufferMngr
	VertexBuffer createVertexBuffer(BufferUsage usage, int size, void* data) {
		return cast(VertexBuffer)
			createBuffer(usage, size, data, ARRAY_BUFFER);
	}
	

	// Implements IIndexBufferMngr
	IndexBuffer createIndexBuffer(BufferUsage usage, u32[] data) {
		return createIndexBuffer(usage, data.length * u32.sizeof, data.ptr, IndexType.U32);
	}

	// Implements IIndexBufferMngr
	IndexBuffer createIndexBuffer(BufferUsage usage, u16[] data) {
		return createIndexBuffer(usage, data.length * u16.sizeof, data.ptr, IndexType.U16);
	}

	// Implements IIndexBufferMngr
	IndexBuffer createIndexBuffer(BufferUsage usage, int size, void* data, IndexType it) {
		auto buf = createBuffer(usage, size, data, ELEMENT_ARRAY_BUFFER);
		return IndexBuffer.fromBuffer(buf, it);
	}


	// implements IUniformBufferMngr
	UniformBuffer createUniformBuffer(BufferUsage usage, void[] data) {
		return createUniformBuffer(usage, data.length, data.ptr);
	}

	// implements IUniformBufferMngr
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
	

	// ---- Texture

	private {
		Texture toResourceHandle(_textures.ResourceReturn resource) {
			Texture res = void;
			res._resHandle = resource.handle;
			res._resMngr = cast(void*)cast(ITextureMngr)this;
			res._refMngr = cast(void*)this;
			final rcnt = &resCountTexture;
			res._resCountAdjust = rcnt.funcptr;
			
			return res;
		}
		
		
		bool resCountTexture(TextureHandle h, int cnt) {
			if (auto resData = _textures.find(h, cnt > 0)) {
				final res = resData.res;
				bool goodBefore = res.refCount > 0;
				res.refCount += cnt;
				if (res.refCount > 0) {
					return true;
				} else if (goodBefore) {
					_textures.free(resData);
				}
			}
			
			return false;
		}
	}
	
	Texture createTexture(Image img, TextureRequest req = TextureRequest.init) {
		assert (img.valid, "Invalid image passed to Renderer.createTexture()");
		
		return toResourceHandle(
			_textures.alloc((TextureImpl* n) {
				log.info("Creating a texture for {}.", img);
				
				n.refCount = 1;
				n.parent = null;
				n.request = req;
				n.size = vec3i(img.size.x, img.size.y, 1);
				n.target = TEXTURE_2D;

				gl.GenTextures(1, &n.handle);
				_bindTexture(n.target, n.handle);
				
				gl.PixelStorei(UNPACK_ALIGNMENT, 4);
				gl.TexImage2D(
					n.target,
					0,
					enumToGL(req.internalFormat),
					img.width,
					img.height,
					req.border,
					enumToGL(img.colorLayout),
					enumToGL(img.dataType),
					img.data.ptr
				);
				
				gl.TexParameteri(n.target, TEXTURE_MIN_FILTER, enumToGL(req.minFilter));
				gl.TexParameteri(n.target, TEXTURE_MAG_FILTER, enumToGL(req.magFilter));

				if (TextureWrap.NoWrap != req.wrapS) {
					gl.TexParameteri(n.target, TEXTURE_WRAP_S, enumToGL(req.wrapS));
				}
				
				if (TextureWrap.NoWrap != req.wrapT) {
					gl.TexParameteri(n.target, TEXTURE_WRAP_T, enumToGL(req.wrapT));
				}
				
				if (TextureWrap.NoWrap != req.wrapR) {
					gl.TexParameteri(n.target, TEXTURE_WRAP_R, enumToGL(req.wrapR));
				}
				
				if (req.border != 0) {
					gl.TexParameterfv(
						n.target,
						TEXTURE_BORDER_COLOR,
						req.borderColor.ptr
					);
				}
				
				gl.GenerateMipmap(n.target);
				gl.Disable(n.target);
			})
		);
	}
	
	
	void _bindTexture(GLenum target, GLuint id) {
		gl.BindTexture(target, id);
	}


	TextureImpl* _getTexture(TextureHandle h) {
		if (auto resData = _textures.find(h)) {
			assert (resData.res !is null);
			return resData.res;
		} else {
			return null;
		}
	}


	// implements ITextureMngr
	vec3i getSize(TextureHandle handle) {
		if (auto tex = _getTexture(handle)) {
			return tex.size;
		} else {
			log.error("getSize called on an invalid texture handle");
			return vec3i.zero;
		}
	}

	// implements ITextureMngr
	size_t getApiHandle(TextureHandle handle) {
		if (auto tex = _getTexture(handle)) {
			return tex.handle;
		} else {
			log.error("getApiHandle called on an invalid texture handle");
			return 0;
		}
	}
	
	
	// ----
	
	
	void render(RenderList* renderList) {
		renderList.computeMatrices();
		foreach (eidx, ref renderBin; renderList.bins) {
			if (eidx >= _effects.length) {
				error(
					"Invalid render list. Make sure to allocate it using"
					" Renderer.createRenderList before rendering each frame."
					" Also make sure not to create new effects in the middle"
					" of the rendering process"
				);
			}
			
			render(_effects[eidx].effect, &renderBin.objects);
		}
	}
	
	
	void render(Effect effect, typeof(RenderBin.objects)* objects) {
		if (0 == objects.length) {
			return;
		}
		
		void* prevUniformValues = null;
		
		final effectInstances = getEffectData(effect).instances.ptr;

		void setObjUniforms(
				void* base,
				RawUniformParamGroup* paramGroup,
				bool minimize,
				EffectInstanceImpl* efInst
		) {
			final up = &paramGroup.params;
			final numUniforms = up.length;

			void* uniformValues;
			
			if (minimize) {
				uniformValues =
					efInst.getUniformsDataPtr();
			}
			
			scope (success) if (minimize) {
				prevUniformValues =
					efInst.getUniformsDataPtr();
			}
			
			for (int ui = 0; ui < numUniforms; ++ui) {
				final unifDS = up.dataSlice[ui];
				
				/+if (minimize) {
					if (0 == memcmp(
						uniformValues + unifDS.offset,
						prevUniformValues + unifDS.offset,
						unifDS.length
					)) {
						continue;
					}
				}+/
				
				if (typeid(Texture) is up.typeInfo[ui]) {
					final tex = cast(Texture*)(base + unifDS.offset);
					if (tex.valid) {
						// log.trace("cgGLSetTextureParameter({})", tex.getApiHandle());
						final cgParam = cast(CGparameter)up.param[ui];
						
						cgGLSetTextureParameter(
							cgParam,
							tex.getApiHandle()
						);
						cgGLEnableTextureParameter(cgParam);
					}
				} else switch (up.baseType[ui]) {
					case ParamBaseType.Float: {
						auto func = &cgSetParameter1fv;
						switch (up.numFields[ui]) {
							case 1: break;
							case 2: {
								func = &cgSetParameter2fv;
							} break;
							case 3: {
								func = &cgSetParameter3fv;
							} break;
							case 4: {
								func = &cgSetParameter4fv;
							} break;
							default: {
								func = &cgSetMatrixParameterfc;
							}
						}
						
						func(
							cast(CGparameter)up.param[ui],
							cast(float*)(base + unifDS.offset)
						);
					} break;

					case ParamBaseType.Int: {
						cgSetParameterValueic(
							cast(CGparameter)up.param[ui],
							up.numFields[ui],
							cast(int*)(base + unifDS.offset)
						);
					} break;
					
					default: assert (false);
				}
			}
		}
		
		void unsetObjUniforms(
				void* base,
				RawUniformParamGroup* paramGroup
		) {
			final up = &paramGroup.params;
			final numUniforms = up.length;

			for (int ui = 0; ui < numUniforms; ++ui) {
				final unifDS = up.dataSlice[ui];
				
				if (typeid(Texture) is up.typeInfo[ui]) {
					final tex = cast(Texture*)(base + unifDS.offset);
					if (tex.valid) {
						cgGLDisableTextureParameter(
							cast(CGparameter)up.param[ui]
						);
					}
				}
			}
		}
		
		
		void setObjVaryings(EffectInstanceImpl* obj) {
			final vp = &effect.varyingParams;
			final numVaryings = vp.length;
			
			auto flags = obj.getVaryingParamDirtyFlagsPtr();
			auto varyingData = obj.getVaryingParamDataPtr();
			
			alias typeof(*flags) flagFieldType;
			const buffersPerFlag = flagFieldType.sizeof * 8;
			
			final varyingParams = obj._proto.varyingParams.param;
			
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
						
						final param
							= cast(CGparameter)varyingParams[varyingBase+idx];

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
			effect.getUniformParamGroup(),
			false,
			effectInstances[objects.eiRenderOrdinal[0]]
		);
		
		final instUnifParams = effect.objectInstanceUniformParams();
		final modelToWorldIndex = instUnifParams.getUniformIndex("modelToWorld");
		final worldToModelIndex = instUnifParams.getUniformIndex("worldToModel");

		bool minimizeStateChanges = false;		// <-
		
		for (uword objIdx = 0; objIdx < objects.length; ++objIdx) {
			final obj = &objects.renderable[objIdx];
			final efInst = effectInstances[objects.eiRenderOrdinal[objIdx]];
			
			if (0 == obj.numIndices) {
				continue;
			} else if (!minimizeStateChanges) {
				prevUniformValues =
					efInst.getUniformsDataPtr();
			}
			
			setObjUniforms(
				efInst.getUniformsDataPtr(),
				efInst.getUniformParamGroup(),
				minimizeStateChanges,			// <-
				efInst
			);
			
			minimizeStateChanges = true;		// <-
			
			efInst._vertexArray.bind();
			setObjVaryings(efInst);
			
			//if (0 == obj.flags & obj.flags.IndexBufferBound) {
				if (!obj.indexBuffer.valid) {
					continue;
				}				

				//obj.flags |= obj.flags.IndexBufferBound;
				obj.indexBuffer.bind();
			//}
			

			// model <-> world matrices are special and always set for every object

			if (modelToWorldIndex != UniformParamIndex.init) {
				cgSetMatrixParameterfc(
					cast(CGparameter)instUnifParams.params.param[modelToWorldIndex],
					cast(float*)(objects.modelToWorld + objIdx)
				);
			}
			
			if (worldToModelIndex != UniformParamIndex.init) {
				cgSetMatrixParameterfc(
					cast(CGparameter)instUnifParams.params.param[worldToModelIndex],
					cast(float*)(objects.worldToModel + objIdx)
				);
			}
			
			// ----

			
			if (1 == obj.numInstances) {
				if (obj.minIndex != 0 || obj.maxIndex != typeof(obj.maxIndex).max) {
					gl.DrawRangeElements(
						enumToGL(obj.topology),
						obj.minIndex,
						obj.maxIndex,
						obj.numIndices,
						enumToGL(obj.indexBuffer.indexType),
						cast(void*)obj.indexOffset
					);
				} else {
					gl.DrawElements(
						enumToGL(obj.topology),
						obj.numIndices,
						enumToGL(obj.indexBuffer.indexType),
						cast(void*)obj.indexOffset
					);
				}
			} else if (obj.numInstances > 1) {
				gl.DrawElementsInstanced(
					enumToGL(obj.topology),
					obj.numIndices,
					enumToGL(obj.indexBuffer.indexType),
					cast(void*)obj.indexOffset,
					obj.numInstances
				);
			}
			
			// prevent state leaking
			unsetObjUniforms(
				efInst.getUniformsDataPtr(),
				efInst.getUniformParamGroup()
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


private struct TextureImpl {
	ptrdiff_t		refCount;
	GLuint			handle;
	GLenum			target;
	vec3i			size;
	TextureRequest	request;
	TextureImpl*	parent;		// for cube map faces
	
	TextureImpl acquireCubeMapFace(CubeMapFace face) {
		if (TEXTURE_CUBE_MAP == target) {
			assert (false, "TODO");
			//return TextureImpl.init;
		} else {
			error("acquireCubeMapFace called on a texture that's not a cube map");
			assert (false);
		}
	}
}


private struct EffectInstanceProxy {
	ptrdiff_t			refCount;
	EffectInstanceImpl*	impl;
}


private struct EffectData {
	static assert (is(Effect == class));	// if fails, make 'effect' a pointer
	Effect						effect;
	Array!(EffectInstanceImpl*)	instances;
	bool						instancesSorted = false;
	
	
	void addInstance(EffectInstanceImpl* inst) {
		instancesSorted = false;
		inst.renderOrdinal = instances.length;
		instances.pushBack(inst);
	}
	
	void sortInstances() {
		if (!instancesSorted) {
			instancesSorted = true;
			assert (false);		// TODO
		}
	}
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


private GLenum enumToGL(IndexType it) {
	switch (it) {
		case IndexType.U16: return UNSIGNED_SHORT;
		case IndexType.U32: return UNSIGNED_INT;
		default: assert (false);
	}
}


private GLenum enumToGL(MeshTopology pt) {
	static const map = [
		POINTS,
		LINE_STRIP,
		LINE_LOOP,
		LINES,
		TRIANGLE_STRIP,
		TRIANGLE_FAN,
		TRIANGLES,
		LINES_ADJACENCY,
		LINE_STRIP_ADJACENCY,
		TRIANGLES_ADJACENCY,
		TRIANGLE_STRIP_ADJACENCY
	];
	
	return map[pt];
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


private GLenum enumToGL(Image.ColorLayout e) {
	switch (e) {
		case e.R: return RED;
		case e.RG: return RG;
		case e.RGB: return RGB;
		case e.RGBA: return RGBA;
		default: assert (false);
	}
}


private GLenum enumToGL(Image.DataType e) {
	switch (e) {
		case e.U8: return UNSIGNED_BYTE;
		case e.I8: return BYTE;
		case e.U16: return UNSIGNED_SHORT;
		case e.I16: return SHORT;
		case e.F16: return HALF_FLOAT_ARB;
		case e.F32: return FLOAT;
		case e.F64: return DOUBLE;
		default: assert (false);
	}
}


private GLenum enumToGL(TextureInternalFormat e) {
	return glTextureInternalFormatMap[e];
}


private GLenum enumToGL(TextureMinFilter e) {
	const GLenum[] map = [
		LINEAR,
		NEAREST,
		NEAREST_MIPMAP_NEAREST,
		NEAREST_MIPMAP_LINEAR,
		LINEAR_MIPMAP_NEAREST,
		LINEAR_MIPMAP_LINEAR
	];

	return map[e];
}


private GLenum enumToGL(TextureMagFilter e) {
	const GLenum[] map = [
		LINEAR,
		NEAREST
	];

	return map[e];
}


private GLenum enumToGL(TextureWrap e) {
	const GLenum[] map = [
		0,
		CLAMP,
		CLAMP_TO_EDGE,
		CLAMP_TO_BORDER
	];

	return map[e];
}
