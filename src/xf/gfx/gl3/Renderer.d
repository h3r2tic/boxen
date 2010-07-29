module xf.gfx.gl3.Renderer;

private {
	import
		xf.Common,
		xf.core.Registry,

		xf.gfx.gl3.CgEffect,
		xf.gfx.gl3.Cg,
		xf.gfx.gl3.TextureInternalFormat,
		xf.gfx.gl3.Debug,
	
		xf.gfx.Resource,
		xf.gfx.Buffer,
		xf.gfx.VertexArray,
		xf.gfx.VertexBuffer,
		xf.gfx.IndexBuffer,
		xf.gfx.IndexData,
		xf.gfx.UniformBuffer,
		xf.gfx.Texture,
		xf.gfx.Framebuffer,
		xf.gfx.Mesh,
		xf.gfx.IRenderer,
		xf.gfx.RenderList,
		xf.gfx.RenderState,
		xf.gfx.gl3.Cg,

		xf.gfx.api.gl3.backend.Native,
		xf.gfx.api.gl3.Cg,
		xf.gfx.api.gl3.OpenGL,
		xf.gfx.api.gl3.ext.ARB_map_buffer_range,
		xf.gfx.api.gl3.ext.ARB_vertex_array_object,
		xf.gfx.api.gl3.ext.ARB_half_float_pixel,
		xf.gfx.api.gl3.ext.ARB_framebuffer_object,
		xf.gfx.api.gl3.ext.EXT_framebuffer_object,
		xf.gfx.api.gl3.ext.EXT_framebuffer_sRGB,
		xf.gfx.api.gl3.ext.EXT_depth_bounds_test;
	import
		ARB_blend_func_extended = xf.gfx.api.gl3.ext.ARB_blend_func_extended;
	import
		GLTextureMagFilter = xf.gfx.api.gl3.ext.TextureMagFilter;
	import
		GLTextureMinFilter = xf.gfx.api.gl3.ext.TextureMinFilter;
	import
		GLTextureWrapMode = xf.gfx.api.gl3.ext.TextureWrapMode;
	import
		xf.img.Image,
		xf.omg.core.LinearAlgebra,

		xf.mem.FreeList,
		xf.mem.Array,
		xf.mem.MainHeap,
		xf.mem.StackBuffer,
		xf.utils.LocalArray,
		
		xf.utils.ResourcePool;

	import
		xf.gfx.Log : log = gfxLog, error = gfxError;
		
	static import tango.core.Array;
	import Search = tango.text.Search;
}



struct RendererCaps {
	static RendererCaps opCall(GL gl) {
		cstring ext = fromStringz(gl.GetString(EXTENSIONS));
		RendererCaps caps;
		caps.depthClamp = Search.find("GL_ARB_depth_clamp").within(ext);
		caps.isNV = 0 == strcmp("NVIDIA Corporation", gl.GetString(VENDOR));
		return caps;
	}
	
	bool	isNV;
	bool	depthClamp;
}


class Renderer : IRenderer {
	mixin(Implements("IRenderer"));
	
	
	RendererStats _stats;

	
	// at the front because otherwise DMD is a bitch about forward refs
	private {
		GLWindow	_window;
		
		GL			gl;
		CgCompiler	_cgCompiler;
		
		ThreadUnsafeResourcePool!(BufferImpl, BufferHandle)
			_buffers;
			
		ThreadUnsafeResourcePool!(VertexArrayImpl, VertexArrayHandle)
			_vertexArrays;

		ThreadUnsafeResourcePool!(TextureImpl, TextureHandle)
			_textures;
		
		ThreadUnsafeResourcePool!(FramebufferImpl, FramebufferHandle)
			_framebuffers;
			
		Framebuffer				_currentFramebuffer;
		Framebuffer				_mainFramebuffer;
		GLuint[][RenderBuffer]	_unusedRenderBuffers;

		// GCd for now
		EffectData[]
			_effects;

		ThreadUnsafeResourcePool!(EffectInstanceProxy, EffectInstanceHandle)
			_effectInstances;
			
		RenderState
			_nextState;

		RendererCaps
			_caps;
	}


	this() {
		_window = new GLWindow;
		final view = &_nextState.viewport;
		view.x = view.y = 0;
		view.width = _window.width;
		view.height = _window.height;
		_window.reshape = &reshapeCallback;
	}


	private void reshapeCallback(uint w, uint h) {
		final view = &_nextState.viewport;
		view.width = w;
		view.height = h;
	}
	
	
	// implements IRenderer
	Window window() {
		return _window;
	}
	
	
	// implements IRenderer
	void window(Window w) {
		_window = cast(GLWindow)w;
		if (_window is null) {
			error("Invalid window passed to the Renderer.");
		}
	}
	
	
	// implements IRenderer
	void initialize() {
		use (_window) in (GL gl) {
			_cgCompiler = new CgCompiler(gl);
			this.gl[] = gl;
			
			initializeOpenGLDebug(gl);

			_caps = RendererCaps(gl);

			gl.Enable(FRAMEBUFFER_SRGB_EXT);
		};


		_buffers.initialize();
		_vertexArrays.initialize();
		_textures.initialize();
		_effectInstances.initialize();
		_renderLists.initialize();
		_framebuffers.initialize();


		_currentFramebuffer = _mainFramebuffer = toResourceHandle(
			_framebuffers.alloc((FramebufferImpl* n) {
				*n = FramebufferImpl(0);
				n.cfg.size = vec2i(_window.width, _window.height);
				n.isMainFB = true;
				n.cfg.color[0].present = true;
				n.cfg.depth.present = true;
			})
		);
		
		// one extra ref for _currentFramebuffer
		_currentFramebuffer.acquire();
	}
	
	
	// implements IRenderer
	void swapBuffers() {
		_window.show();
	}
	
	
	// implements IRenderer
	void clearBuffers() {
		bindCurrentFramebuffer();
		final resData = _framebuffers.find(_currentFramebuffer._resHandle);
		assert (resData !is null);
		final fb = resData.res;
		assert (fb !is null);
		
		// TODO: optimize me
		
		if (fb.cfg.depth.present && fb.settings.clearDepthEnabled) {
			gl.ClearDepth(fb.settings.clearDepthValue);
			gl.Clear(DEPTH_BUFFER_BIT);
		}
		
		foreach (i, ref a; fb.cfg.color) {
			if (fb.isMainFB) {
				if (0 == i) {
					assert (a.present);
				} else {
					assert (!a.present);
				}
			}
			
			if (a.present && fb.settings.clearColorEnabled[i]) {
				if (fb.isMainFB) {
					gl.DrawBuffer(BACK);
				} else {
					gl.DrawBuffer(fb.attachments.color[i].glAttachment);
				}
				
				gl.ClearColor(fb.settings.clearColorValue[i].tuple);
				gl.Clear(COLOR_BUFFER_BIT);
			}
		}

		setupDrawReadBuffers(fb);
	}
	
	
	void resetStats() {
		_stats = RendererStats.init;
	}
	
	
	RendererStats getStats() {
		return _stats;
	}
	
	
	RenderState* state() {
		return &_nextState;
	}

	
	
	// RenderList ----
	
	NondestructiveFreeList!(RenderList)	_renderLists;
	
	// implements IRenderer
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
	
	
	// implements IRenderer
	void disposeRenderList(RenderList* rl) {
		_renderLists.free(rl);
	}
	
	
	// Effect ----
	
	
	Effect createEffect(cstring name, EffectSource source, EffectCompilationOptions opts) {
		if (_caps.isNV) {
			opts.useNVExtensions = true;
		}

		final effect = _cgCompiler.createEffect(name, source, opts);
		effect._idxInRenderer = _effects.length;
		effect.renderOrdinal = _effects.length;
		// TODO: effectsSorted = false
		_effects ~= EffectData(effect);
		return effect;
	}


	// TODO: do anything about Effect ordinals?
	void disposeEffect(Effect effect_) {
		if (auto effect = cast(CgEffect)effect_) {
			log.info("Disposing an effect.");
			
			auto data = &_effects[effect._idxInRenderer];
			data.dispose();
			
			if (effect._idxInRenderer+1 != _effects.length) {
				auto other = &_effects[$-1];
				other.effect._idxInRenderer = effect._idxInRenderer;
				*data = *other;
				*other = EffectData.init;
			}

			_effects = _effects[0..$-1];
			
			_cgCompiler.disposeEffect(effect);
		} else {
			error("disposeEffect: the argument is not an instance of CgEffect.");
		}		
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
				log.info("Disposing an effect instance.");

				// TODO: free anything else?
				EffectInstanceImpl* inst = res.impl;
				_effects[inst._proto._idxInRenderer].disposeInstance(inst);
				_effectInstances.free(resData);
				mainHeap.freeRaw(inst);
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

	/+// implements IEffectMngr
	bool setVarying(EffectInstanceHandle h, cstring name, VertexBuffer buf, VertexAttrib vattr) {
		if (auto resData = _effectInstances.find(h)) {
			assert (resData.res !is null);
			final res = resData.res.impl;
			assert (res !is null);
			return res.setVarying(name, buf, vattr);
		} else {
			return false;
		}
	}+/

	// implements IEffectMngr
	void** getUniformPtrsDataPtr(EffectInstanceHandle h) {
		if (auto resData = _effectInstances.find(h)) {
			assert (resData.res !is null);
			final res = resData.res.impl;
			assert (res !is null);
			return res.getUniformPtrsDataPtr;
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
	/+size_t* getVaryingParamDirtyFlagsPtr(EffectInstanceHandle h) {
		if (auto resData = _effectInstances.find(h)) {
			assert (resData.res !is null);
			final res = resData.res.impl;
			assert (res !is null);
			return res.getVaryingParamDirtyFlagsPtr;
		} else {
			return null;
		}
	}+/
	

	// implements IEffectMngr
	void setVaryingParamsDirty(EffectInstanceHandle h) {
		if (auto resData = _effectInstances.find(h)) {
			assert (resData.res !is null);
			final res = resData.res.impl;
			assert (res !is null);
			return res._varyingParamsDirty = true;
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

				if (needsMipmap(req.minFilter)) {
					gl.GenerateMipmap(n.target);
				}
			})
		);
	}
	
	pragma (ctfe) static char[] _genCubeXform(char[] sc, char[] tc, char[] ma) {
		return "(vec2 tc) { vec3 res = void;"
		" res." ~ ma ~ ";"
		" res." ~ sc[1] ~ "=" ~ sc[0] ~ "(tc.x*2.f-1.f);"
		" res." ~ tc[1] ~ "=" ~ tc[0] ~ "(tc.y*2.f-1.f);"
		" return res; }";
	}


	Texture createTexture(
			vec2i size,
			TextureRequest req,
			vec4 delegate(vec3) colorGen = null
	) {
		return toResourceHandle(
			_textures.alloc((TextureImpl* n) {
				log.info("Creating a procedural texture.");
				
				n.refCount = 1;
				n.parent = null;
				n.request = req;
				n.size = vec3i(size.x, size.y, 1);

				switch (req.type) {
					case TextureType.Texture2D: {
						n.target = TEXTURE_2D;
					} break;
					case TextureType.TextureCube: {
						n.target = TEXTURE_CUBE_MAP;
					} break;
					default: assert (false, "TODO");
				}


				gl.GenTextures(1, &n.handle);
				_bindTexture(n.target, n.handle);
				
				gl.PixelStorei(UNPACK_ALIGNMENT, 4);

				// ----

				int width = size.x;
				int height = size.y;

				scope stack = new StackBuffer;
				LocalArray!(vec4) _dataArr;
				vec4[] data = null;

				if (colorGen !is null) {
					_dataArr = LocalArray!(vec4)(width * height, stack);
					data = _dataArr.data;
				}
				scope (exit) {
					_dataArr.dispose();
				}
				
				void initTextureData(vec3 delegate(vec2) transform) {
					for (uint i = 0; i < width; ++i) {
						float u = (cast(float)i + 0.5f) / width;
						for (uint j = 0; j < height; ++j) {
							float v = (cast(float)j + 0.5f) / height;
							
							data[(width * j + i)] = colorGen(transform(vec2(u, v)));
						}
					}
				}
		
				/+if (TextureType.TextureCube == request.type) {
					auto cube = new TextureCube;
					tex = cube;
					foreach (fi, ref f; cube.faces) {
						auto ft = new TextureImpl;
						ft.target = GL_TEXTURE_CUBE_MAP_POSITIVE_X+fi;
						ft.size = size;
						ft.request = request;
						ft.id = texId;
						f = mkImpl(ft);
					}
				} else {
					tex = new TextureImpl;
				}+/
				
				//tex.type = request.type;
				const uint level	= 0;
				
				void initSingleFace(GLenum target, vec3 delegate(vec2) transform = null) {
					if (colorGen !is null) {
						if (transform is null) {
							initTextureData((vec2 uv) { return vec3(uv.x, uv.y, 0); });
						} else {
							initTextureData(transform);
						}
					}

					GLenum dataLayout = RGBA;

					final internal = enumToGL(req.internalFormat);
					switch (req.internalFormat) {
						case TextureInternalFormat.DEPTH_COMPONENT16:
						case TextureInternalFormat.DEPTH_COMPONENT24:
						case TextureInternalFormat.DEPTH24_STENCIL8:
						case TextureInternalFormat.DEPTH_COMPONENT32F:
						case TextureInternalFormat.DEPTH32F_STENCIL8:
							assert (data.ptr is null);		// TODO
							dataLayout = DEPTH_COMPONENT;
							break;
						default: break;
					}
					
					gl.TexImage2D(
						target,
						level,
						internal,
						width,
						height,
						0,		// TODO: border
						dataLayout,
						FLOAT,
						data.ptr
					);
				}
				
				if (TextureType.TextureCube == req.type) {
					/** http://developer.nvidia.com/object/cube_map_ogl_tutorial.html
						major axis 
						direction     target                              sc     tc    ma 
						----------    ---------------------------------   ---    ---   --- 
						 +rx          GL_TEXTURE_CUBE_MAP_POSITIVE_X_EXT   -rz    -ry   rx 
						 -rx          GL_TEXTURE_CUBE_MAP_NEGATIVE_X_EXT   +rz    -ry   rx 
						 +ry          GL_TEXTURE_CUBE_MAP_POSITIVE_Y_EXT   +rx    +rz   ry 
						 -ry          GL_TEXTURE_CUBE_MAP_NEGATIVE_Y_EXT   +rx    -rz   ry 
						 +rz          GL_TEXTURE_CUBE_MAP_POSITIVE_Z_EXT   +rx    -ry   rz 
						 -rz          GL_TEXTURE_CUBE_MAP_NEGATIVE_Z_EXT   -rx    -ry   rz
						Using the sc, tc, and ma determined by the major axis direction as specified in the table above, an updated (s,t) is calculated as follows
						s   =   ( sc/|ma| + 1 ) / 2 
						t   =   ( tc/|ma| + 1 ) / 2
					*/
					
					initSingleFace(TEXTURE_CUBE_MAP_POSITIVE_X, mixin(_genCubeXform(`-z`, `-y`, `x=1`)));
					initSingleFace(TEXTURE_CUBE_MAP_NEGATIVE_X, mixin(_genCubeXform(`+z`, `-y`, `x=-1`)));
					initSingleFace(TEXTURE_CUBE_MAP_POSITIVE_Y, mixin(_genCubeXform(`+x`, `+z`, `y=1`)));
					initSingleFace(TEXTURE_CUBE_MAP_NEGATIVE_Y, mixin(_genCubeXform(`+x`, `-z`, `y=-1`)));
					initSingleFace(TEXTURE_CUBE_MAP_POSITIVE_Z, mixin(_genCubeXform(`+x`, `-y`, `z=1`)));
					initSingleFace(TEXTURE_CUBE_MAP_NEGATIVE_Z, mixin(_genCubeXform(`-x`, `-y`, `z=-1`)));
				} else {
					initSingleFace(n.target);
				}

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

				if (needsMipmap(req.minFilter) && colorGen !is null) {
					gl.GenerateMipmap(n.target);
				}
			})
		);
	}


	// HACK
	void updateTexture(Texture h, vec2i origin, vec2i size, ubyte* data) {
		final tex = _getTexture(h._resHandle);
		assert (tex !is null);

		_bindTexture(tex.target, tex.handle);

		const int level = 0;

		gl.TexSubImage2D(
			tex.target,
			level,
			origin.x,
			origin.y,
			size.x,
			size.y,
			RGBA,
			UNSIGNED_BYTE,
			data
		);
	}

	// HACK
	void updateTexture(Texture h, vec2i origin, vec2i size, float* data) {
		final tex = _getTexture(h._resHandle);
		assert (tex !is null);

		_bindTexture(tex.target, tex.handle);

		const int level = 0;

		gl.TexSubImage2D(
			tex.target,
			level,
			origin.x,
			origin.y,
			size.x,
			size.y,
			RGBA,
			FLOAT,
			data
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


	bool getInfo(TextureHandle handle, TextureRequest* info) {
		if (auto tex = _getTexture(handle)) {
			*info = tex.request;
			return true;
		} else {
			log.error("getInfo called on an invalid texture handle");
			return false;
		}
	}
	
	
	// Framebuffer ----


	private {
		Framebuffer toResourceHandle(_framebuffers.ResourceReturn resource) {
			Framebuffer res = void;
			res._resHandle = resource.handle;
			res._resMngr = cast(void*)cast(IFramebufferMngr)this;
			res._refMngr = cast(void*)this;
			final rcnt = &resCountFramebuffer;
			res._resCountAdjust = rcnt.funcptr;
			
			return res;
		}
		
		
		bool resCountFramebuffer(FramebufferHandle h, int cnt) {
			if (auto resData = _framebuffers.find(h, cnt > 0)) {
				final res = resData.res;
				bool goodBefore = res.refCount > 0;
				res.refCount += cnt;
				if (res.refCount > 0) {
					return true;
				} else if (goodBefore) {
					_framebuffers.free(resData);
				}
			}
			
			return false;
		}
	}


	vec2i getFramebufferSize(FramebufferHandle h) {
		if (auto resData = _framebuffers.find(h)) {
			final res = resData.res;
			assert (res !is null);
			return res.cfg.size;
		} else {
			return vec2i.zero;
		}
	}
	
	FramebufferConfig getFramebufferConfig(FramebufferHandle h) {
		if (auto resData = _framebuffers.find(h)) {
			final res = resData.res;
			assert (res !is null);
			return res.cfg;
		} else {
			return FramebufferConfig.init;
		}
	}
	
	
	FramebufferSettings* getFramebufferSettings(FramebufferHandle h) {
		if (auto resData = _framebuffers.find(h)) {
			final res = resData.res;
			assert (res !is null);
			return &res.settings;
		} else {
			return null;
		}
	}
	
	
	void framebuffer(Framebuffer fb) {
		if (fb.valid() && fb.acquire()) {
			final resData = _framebuffers.find(fb._resHandle);
			assert (resData !is null);
			final res = resData.res;
			assert (res !is null);
			
			if (_currentFramebuffer.valid()) {
				_currentFramebuffer.dispose();
			}
			
			_currentFramebuffer = fb;

			state.viewport.width = fb.size.x;
			state.viewport.height = fb.size.y;
		}
	}
	
	Framebuffer framebuffer() {
		return _currentFramebuffer;
	}
	
	
	Framebuffer mainFramebuffer() {
		return _mainFramebuffer;
	}
	
	
	Framebuffer createFramebuffer(FramebufferConfig cfg) {
		return toResourceHandle(
			_framebuffers.alloc((FramebufferImpl* n) {
				log.info("Creating a framebuffer.");
				
				GLuint id;
				gl.GenFramebuffers(1, &id);
				log.trace("glGenFramebuffers -> {}", id);
				*n = FramebufferImpl(id);
				n.cfg.size = cfg.size;
				adaptFramebufferToConfig(n, cfg);
			})
		);
	}
	
	
	private void bindCurrentFramebuffer() {
		if (_currentFramebuffer.valid()) {
			if (auto resData = _framebuffers.find(_currentFramebuffer._resHandle)) {
				final res = resData.res;
				assert (res !is null);
				gl.BindFramebuffer(FRAMEBUFFER, res.handle);
			} else {
				error("The main framebuffer has been erroneously disposed.");
			}
		} else {
			error("The current framebuffer is invalid.");
		}
	}
	

	private void adaptFramebufferToConfig(FramebufferImpl* fbo, FramebufferConfig cfg) {
		alias FramebufferConfig.Attachment				Attachment;
		alias FramebufferImpl.Attachments.Attachment	FBOAttachment;
		
		gl.BindFramebuffer(FRAMEBUFFER, fbo.handle);
		scope (exit) bindCurrentFramebuffer();
		
		bool formatCompatible(RenderBuffer fbRB, RenderBuffer cfgRB) {
			return fbRB.internalFormat == cfgRB.internalFormat;
		}
		
		void detach(ref FBOAttachment fboAttachment, ref Attachment fbAttachment) {
			//assert (!fboAttachment.isTexture);
			assert (Attachment.Type.RenderBuffer == fbAttachment.type);
			gl.FramebufferRenderbuffer(FRAMEBUFFER, fboAttachment.glAttachment, RENDERBUFFER, 0);
			disposeRenderBuffer(fbAttachment.rb, fboAttachment.rb);
		}
		
		void attach(ref FBOAttachment fboAttachment, ref Attachment fbAttachment) {
			if (Attachment.Type.Texture == fbAttachment.type) {
				auto tex = fbAttachment.tex;
				if (tex.acquire()) {
					fboAttachment.tex = tex;
					//fboAttachment.isTexture = true;
					
					final texImpl = _getTexture(tex._resHandle);
					assert (texImpl !is null);					
					
					gl.FramebufferTexture2D(
						FRAMEBUFFER, fboAttachment.glAttachment,
						texImpl.target, texImpl.handle, 0
					);
				} else {
					fbAttachment.present = false;
					assert (false, "shit happened");
				}
			} else {
				fbAttachment.rb.size = cfg.size;
				fboAttachment.rb = acquireRenderBuffer(fbAttachment.rb);
				//fboAttachment.isTexture = false;
				
				gl.FramebufferRenderbuffer(
					FRAMEBUFFER, fboAttachment.glAttachment,
					RENDERBUFFER, fboAttachment.rb
				);
			}
		}
		
		void adaptAttachment(ref FBOAttachment fboAttachment, ref Attachment fbAttachment, ref Attachment cfgAttachment) {
			if (cfgAttachment.present) {
				if (fbAttachment.present) {
					assert (Attachment.Type.RenderBuffer == fbAttachment.type);
					if (!formatCompatible(fbAttachment.rb, cfgAttachment.rb)) {
						detach(fboAttachment, fbAttachment);
						fbAttachment = cfgAttachment;
						attach(fboAttachment, fbAttachment);
					}
				} else {
					fbAttachment = cfgAttachment;
					attach(fboAttachment, fbAttachment);
				}
			} else {
				if (fbAttachment.present) {
					assert (Attachment.Type.RenderBuffer == fbAttachment.type);
					detach(fboAttachment, fbAttachment);
				}
				
				fbAttachment = cfgAttachment;
			}
		}
		
		adaptAttachment(fbo.attachments.depth, fbo.cfg.depth, cfg.depth);
		foreach (i, ref a; fbo.cfg.color) {
			adaptAttachment(fbo.attachments.color[i], a, cfg.color[i]);
		}

		setupDrawReadBuffers(fbo);
		
		validateFBO(fbo);
	}
	
	
	private void setupDrawReadBuffers(FramebufferImpl* fbo) {
		if (fbo.isMainFB) {
			gl.DrawBuffer(BACK);
			gl.ReadBuffer(BACK);
		} else {
			GLenum[(*fbo).cfg.color.length] drawBuffers;
			uword numDrawBuffers = 0;

			foreach (i, ref a; fbo.cfg.color) {
				if (a.present) {
					drawBuffers[numDrawBuffers++]
						= fbo.attachments.color[i].glAttachment;
				}
			}
			
			if (numDrawBuffers > 0) {
				if (numDrawBuffers > 1) {
					gl.DrawBuffers(numDrawBuffers, drawBuffers.ptr);
					gl.ReadBuffer(drawBuffers[0]);
				} else {
					gl.DrawBuffer(drawBuffers[0]);
					gl.ReadBuffer(drawBuffers[0]);
				}
			} else {
				gl.DrawBuffer(NONE);
				gl.ReadBuffer(NONE);
			}
		}
	}


	private GLuint acquireRenderBuffer(RenderBuffer rb) {
		assert (rb.size.x > 0 && rb.size.y > 0);
		
		if (auto unused = rb in _unusedRenderBuffers) {
			if ((*unused).length > 0) {
				GLuint idx = (*unused)[$-1];
				(*unused) = (*unused)[0..$-1];
				return idx;
			}
		}
		
		return createRenderBuffer(rb);
	}


	private GLuint createRenderBuffer(RenderBuffer rb) {
		GLuint id;
		gl.GenRenderbuffers(1, &id);
		log.trace("glGenRenderbuffers -> {}", id);
		gl.BindRenderbuffer(RENDERBUFFER, id);
		gl.RenderbufferStorage(
			RENDERBUFFER,
			enumToGL(rb.internalFormat),
			rb.size.x,
			rb.size.y
		);
		return id;
	}


	private void disposeRenderBuffer(RenderBuffer rb, GLuint id) {
		gl.DeleteRenderbuffers(1, &id);
		log.trace("glDeleteRenderbuffers({})", id);
	}
	
	
	// assumes that the FBO is currently bound
	private void validateFBO(FramebufferImpl* fbo) {
		auto status = gl.CheckFramebufferStatus(FRAMEBUFFER);
		switch (status) {
			case FRAMEBUFFER_COMPLETE:
				break;
				
			default:
				throw new Exception("glCheckFramebufferStatus failed");
		}
	}

	
	// ----
	
	
	// implements IRenderer
	void minimizeStateChanges() {
		foreach (ref e; _effects) {
			e.sortInstances();
		}
	}
	
	
	// implements IRenderer
	void render(RenderList* renderList, RenderCallbacks rcb) {
		//log.trace("render at {}", __LINE__);
		renderList.computeMatrices();
		//log.trace("render at {}", __LINE__);
		bindCurrentFramebuffer();
		//log.trace("render at {}", __LINE__);
		setupRenderStates(_nextState);
		//log.trace("render at {}", __LINE__);

		foreach (eidx, ref renderBin; renderList.bins) {
			if (eidx >= _effects.length) {
				error(
					"Invalid render list. Make sure to allocate it using"
					" Renderer.createRenderList before rendering each frame."
					" Also make sure not to create new effects in the middle"
					" of the rendering process"
				);
			}
			
		//log.trace("render at {}", __LINE__);
			render(_effects[eidx].effect, &renderBin.objects, &rcb);
		//log.trace("render at {}", __LINE__);
		}
	}


	// implements IRenderer
	void resetState() {
		_nextState = RenderState.init;
		final view = &_nextState.viewport;
		view.x = view.y = 0;
		view.width = _window.width;
		view.height = _window.height;
		setupRenderStates(_nextState);
	}
	
	
	void setupRenderStates(RenderState s) {
		//log.trace("render at {}", __LINE__);

		if (s.depth.enabled) {
			gl.Enable(DEPTH_TEST);
			gl.DepthMask(s.depth.writeMask);

			GLenum func;
			switch (s.depth.func) {
				alias RenderState.Depth.Func DF;
				case DF.Less: func = LESS; break;
				case DF.Lequal: func = LEQUAL; break;
				case DF.Greater: func = GREATER; break;
				case DF.Gequal: func = GEQUAL; break;
				case DF.Equal: func = EQUAL; break;
				default: assert (false);
			}

			gl.DepthFunc(func);
		} else {
			gl.Disable(DEPTH_TEST);
		}

		if (_caps.isNV) {
			if (s.depthBounds.enabled) {
				gl.DepthBoundsEXT(s.depthBounds.minz, s.depthBounds.maxz);
				gl.Enable(DEPTH_BOUNDS_TEST_EXT);
			} else {
				gl.Disable(DEPTH_BOUNDS_TEST_EXT);
			}
		}
		
		//log.trace("render at {}", __LINE__);

		if (s.blend.enabled) {
			gl.Enable(BLEND);
			gl.BlendFunc(enumToGL(s.blend.src), enumToGL(s.blend.dst));
		} else {
			gl.Disable(BLEND);
		}
		
		//log.trace("render at {}", __LINE__);

		if (s.cullFace.enabled && (s.cullFace.front || s.cullFace.back)) {
			gl.Enable(CULL_FACE);
			if (s.cullFace.front && s.cullFace.back) {
				gl.CullFace(FRONT_AND_BACK);
			} else if (s.cullFace.front) {
				gl.CullFace(FRONT);
			} else {
				gl.CullFace(BACK);
			}
		} else {
			gl.Disable(CULL_FACE);
		}

		//log.trace("render at {}", __LINE__);

		if (s.scissor.enabled) {
			final sc = &s.scissor;
			gl.Scissor(sc.x, sc.y, sc.width, sc.height);
			gl.Enable(SCISSOR_TEST);
		} else {
			gl.Disable(SCISSOR_TEST);
		}

		//log.trace("render at {}", __LINE__);

		if (s.sRGB) {
			gl.Enable(FRAMEBUFFER_SRGB_EXT);
		} else {
			gl.Disable(FRAMEBUFFER_SRGB_EXT);
		}

		//log.trace("render at {}", __LINE__);

		if (_caps.depthClamp) {
			if (s.depthClamp) {
				gl.Enable(DEPTH_CLAMP);
			} else {
				gl.Disable(DEPTH_CLAMP);
			}
		}

		//log.trace("render at {}", __LINE__);

		{
			final v = &s.viewport;
			gl.Viewport(v.x, v.y, v.width, v.height);
		}

		//log.trace("render at {}", __LINE__);

		gl.LineWidth(s.line.width);
		gl.PointSize(s.point.size);

		//log.trace("render at {}", __LINE__);
	}
	
	
	void render(
			Effect effect,
			typeof(RenderBin.objects)* objects,
			RenderCallbacks* rcb
	) {
		if (0 == objects.length) {
			return;
		}

		//log.trace("render at {}", __LINE__);
		
		void** prevUniformValues = null;
		
		final effectInstances = getEffectData(effect).instances.ptr;

		void setObjUniforms(
				void** base,
				RawUniformParamGroup* paramGroup,
				bool minimize,
				EffectInstanceImpl* efInst
		) {
		//log.trace("render at {}", __LINE__);
			defaultHandleCgError();
			
			final up = &paramGroup.params;
			final numUniforms = up.length;

			void** uniformValues;
			
			if (minimize) {
				uniformValues =
					efInst.getUniformPtrsDataPtr();
			}
		//log.trace("render at {}", __LINE__);
			
			scope (success) if (minimize) {
				prevUniformValues =
					efInst.getUniformPtrsDataPtr();
			}
		//log.trace("render at {}", __LINE__);
			
			for (int ui = 0; ui < numUniforms; ++ui) {
				if (base[ui] is null) {
					error("Object uniform parameter pointer is null for '{}'.", up.name[ui]);
				}
				
				//final unifDS = up.dataSlice[ui];
				
				/+if (minimize) {
					if (0 == memcmp(
						uniformValues + unifDS.offset,
						prevUniformValues + unifDS.offset,
						unifDS.length
					)) {
						continue;
					}
				}+/
				
		//log.trace("render at {}", __LINE__);
				if (typeid(Texture) is up.typeInfo[ui]) {
		//log.trace("render at {}", __LINE__);
					final tex = cast(Texture*)(base[ui]);
					if (tex.valid) {
						// log.trace("cgGLSetTextureParameter({})", tex.getApiHandle());
						final cgParam = cast(CGparameter)up.param[ui];
						
						final prev = cgGLGetTextureParameter(cgParam);
						final cur = tex.getApiHandle();
		//log.trace("render at {}", __LINE__);
						
						if (cur != prev) {
							cgGLSetTextureParameter(
								cgParam,
								cur
							);
							++_stats.numTextureChanges;
						}
		//log.trace("render at {}", __LINE__);
						
						cgGLEnableTextureParameter(cgParam);
						defaultHandleCgError();
		//log.trace("render at {}", __LINE__);
					}
		//log.trace("render at {}", __LINE__);
				} else switch (up.baseType[ui]) {
		//log.trace("render at {}", __LINE__);
					case ParamBaseType.Float: {
						auto func = cgSetParameter1fv;
		//log.trace("render at {}", __LINE__);
						switch (up.numFields[ui]) {
							case 1: break;
							case 2: {
								func = cgSetParameter2fv;
							} break;
							case 3: {
								func = cgSetParameter3fv;
							} break;
							case 4: {
								func = cgSetParameter4fv;
							} break;
							default: {
								func = cgSetMatrixParameterfc;
							}
						}
						
		//log.trace("render at {}", __LINE__);
						func(
							cast(CGparameter)up.param[ui],
							cast(float*)(base[ui])
						);
		//log.trace("render at {}", __LINE__);
						defaultHandleCgError();
		//log.trace("render at {}", __LINE__);
					} break;

					case ParamBaseType.Int: {
		//log.trace("render at {}", __LINE__);
						cgSetParameterValueic(
							cast(CGparameter)up.param[ui],
							up.numFields[ui],
							cast(int*)(base[ui])
						);
		//log.trace("render at {}", __LINE__);
						defaultHandleCgError();
		//log.trace("render at {}", __LINE__);
					} break;
					
					default: assert (false);
				}
			}
		}
		
		//log.trace("render at {}", __LINE__);
		
		void unsetObjUniforms(
				void** base,
				RawUniformParamGroup* paramGroup
		) {
		//log.trace("render at {}", __LINE__);
			final up = &paramGroup.params;
			final numUniforms = up.length;

		//log.trace("render at {}", __LINE__);
			for (int ui = 0; ui < numUniforms; ++ui) {
				//final unifDS = up.dataSlice[ui];
				
				if (typeid(Texture) is up.typeInfo[ui]) {
					final tex = cast(Texture*)(base[ui]);
					if (tex.valid) {
		//log.trace("render at {}", __LINE__);
						cgGLDisableTextureParameter(
							cast(CGparameter)up.param[ui]
						);
		//log.trace("render at {}", __LINE__);
					}
				}
			}
		}
		
		//log.trace("render at {}", __LINE__);
		
		void setObjVaryings(EffectInstanceImpl* obj) {
			defaultHandleCgError();

		//log.trace("render at {}", __LINE__);
			if (!obj._varyingParamsDirty) {
				return;
			} else {
				obj._varyingParamsDirty = false;
			}
		//log.trace("render at {}", __LINE__);
			
			final vp = &effect.varyingParams;
			final numVaryings = vp.length;
		//log.trace("render at {}", __LINE__);
			
			auto varyingData = obj.getVaryingParamDataPtr();
			final varyingParams = obj._proto.varyingParams.param;
			final varyingNames = obj._proto.varyingParams.name;

			for (uword idx = 0; idx < numVaryings; ++idx) {
				final data = varyingData + idx;
		//log.trace("render at {}", __LINE__);
				
				final buf = data.buffer;
				final attr = data.attrib;

				assert (buf !is null, varyingNames[idx] ~ " is null.");
				assert (attr !is null, varyingNames[idx] ~ " is null.");
				assert (buf.valid, varyingNames[idx] ~ " has an invalid buffer bound.");

		//log.trace("render at {}", __LINE__);
				GLenum glType = void;
				switch (attr.scalarType) {
					case attr.ScalarType.Float: {
						glType = FLOAT;
					} break;
					
					default: {
						error("Unhandled scalar type: {}", attr.scalarType);
					}
				}
		//log.trace("render at {}", __LINE__);
				
				final param
					= cast(CGparameter)varyingParams[idx];

		//log.trace("render at {}", __LINE__);
				buf.bind();
		//log.trace("render at {}", __LINE__);
				defaultHandleCgError(varyingNames[idx]);
		//log.trace("render at {}", __LINE__);

				cgGLEnableClientState(param);
		//log.trace("render at {}", __LINE__);
				defaultHandleCgError(varyingNames[idx]);
		//log.trace("render at {}", __LINE__);

				cgGLSetParameterPointer(
					param,
					attr.numFields(),
					glType,
					attr.stride,
					cast(void*)attr.offset
				);
		//log.trace("render at {}", __LINE__);
				defaultHandleCgError(varyingNames[idx]);
		//log.trace("render at {}", __LINE__);
			}
		//log.trace("render at {}", __LINE__);
		}

			
		//log.trace("render at {}", __LINE__);
		effect.bind();
		//log.trace("render at {}", __LINE__);
		scope (exit) effect.unbind();
		//log.trace("render at {}", __LINE__);
		
		setObjUniforms(
			effect.getUniformPtrsDataPtr(),
			effect.getUniformParamGroup(),
			false,
			effectInstances[objects.eiRenderOrdinal[0]]
		);
		//log.trace("render at {}", __LINE__);
		
		final instUnifParams = effect.objectInstanceUniformParams();
		final modelToWorldIndex	= instUnifParams.getUniformIndex("modelToWorld");
		final worldToModelIndex	= instUnifParams.getUniformIndex("worldToModel");
		final modelScaleIndex	= instUnifParams.getUniformIndex("modelScale");

		bool minimizeStateChanges = false;		// <-
		
		//log.trace("render at {}", __LINE__);
		for (uword objIdx = 0; objIdx < objects.length; ++objIdx) {
			final obj = &objects.renderable[objIdx];
			final efInst = effectInstances[objects.eiRenderOrdinal[objIdx]];
			
		//log.trace("render at {}", __LINE__);
			if (	0 == obj.indexData.numIndices
				&&	0 == (obj.flags & RenderableData.Flags.NoIndices)
			) {
				continue;
			} else if (!minimizeStateChanges) {
				prevUniformValues =
					efInst.getUniformPtrsDataPtr();
			}
			
		//log.trace("render at {}", __LINE__);
			setObjUniforms(
				efInst.getUniformPtrsDataPtr(),
				efInst.getUniformParamGroup(),
				minimizeStateChanges,			// <-
				efInst
			);
		//log.trace("render at {}", __LINE__);
			
			minimizeStateChanges = true;		// <-
		//log.trace("render at {}", __LINE__);
			
			efInst._vertexArray.bind();
			setObjVaryings(efInst);
		//log.trace("render at {}", __LINE__);

			if (0 == (obj.flags & RenderableData.Flags.NoIndices)) {
			//if (0 == obj.flags & obj.flags.IndexBufferBound) {
				if (!obj.indexData.indexBuffer.valid) {
					continue;
				}

		//log.trace("render at {}", __LINE__);
				//obj.flags |= obj.flags.IndexBufferBound;
				obj.indexData.indexBuffer.bind();
		//log.trace("render at {}", __LINE__);
			//}
			}
			
		//log.trace("render at {}", __LINE__);

			// model <-> world matrices are special and always set for every object

		//log.trace("render at {}", __LINE__);
			if (modelToWorldIndex != UniformParamIndex.init) {
				cgSetMatrixParameterfc(
					cast(CGparameter)instUnifParams.params.param[modelToWorldIndex],
					cast(float*)(objects.modelToWorld + objIdx)
				);
			}
		//log.trace("render at {}", __LINE__);
			
			if (worldToModelIndex != UniformParamIndex.init) {
				cgSetMatrixParameterfc(
					cast(CGparameter)instUnifParams.params.param[worldToModelIndex],
					cast(float*)(objects.worldToModel + objIdx)
				);
			}
		//log.trace("render at {}", __LINE__);

			if (modelScaleIndex != UniformParamIndex.init) {
				cgSetParameter3fv(
					cast(CGparameter)instUnifParams.params.param[modelScaleIndex],
					obj.scale.ptr
				);
			}
		//log.trace("render at {}", __LINE__);
			
			// ----

			if (rcb.beforeRenderObject !is null) {
				rcb.beforeRenderObject(effect, objIdx);
			}
		//log.trace("render at {}", __LINE__);

			// ----


			if ((obj.flags & RenderableData.Flags.NoIndices) != 0) {
		//log.trace("render at {}", __LINE__);
				if (1 == obj.numInstances) {
		//log.trace("render at {}", __LINE__);
					gl.DrawArrays(
						enumToGL(obj.indexData.topology),
						obj.indexData.indexOffset,
						obj.indexData.numIndices
					);
		//log.trace("render at {}", __LINE__);
				} else {
		//log.trace("render at {}", __LINE__);
					gl.DrawArraysInstanced(
						enumToGL(obj.indexData.topology),
						obj.indexData.indexOffset,
						obj.indexData.numIndices,
						obj.numInstances
					);
		//log.trace("render at {}", __LINE__);
				}
			} else {
				size_t offset = obj.indexData.indexOffset
					* (IndexType.U16 == obj.indexData.indexBuffer.indexType
					? 2
					: 4);
				
				if (1 == obj.numInstances) {
					if (	obj.indexData.minIndex != 0
						||	obj.indexData.maxIndex != typeof(obj.indexData.maxIndex).max)
					{
		//log.trace("render at {}", __LINE__);
						gl.DrawRangeElements(
							enumToGL(obj.indexData.topology),
							obj.indexData.minIndex,
							obj.indexData.maxIndex,
							obj.indexData.numIndices,
							enumToGL(obj.indexData.indexBuffer.indexType),
							cast(void*)offset
						);
		//log.trace("render at {}", __LINE__);
					} else {
		//log.trace("render at {}", __LINE__);
						gl.DrawElements(
							enumToGL(obj.indexData.topology),
							obj.indexData.numIndices,
							enumToGL(obj.indexData.indexBuffer.indexType),
							cast(void*)offset
						);
		//log.trace("render at {}", __LINE__);
					}
				} else if (obj.numInstances > 1) {
		//log.trace("render at {}", __LINE__);
					gl.DrawElementsInstanced(
						enumToGL(obj.indexData.topology),
						obj.indexData.numIndices,
						enumToGL(obj.indexData.indexBuffer.indexType),
						cast(void*)offset,
						obj.numInstances
					);
		//log.trace("render at {}", __LINE__);
				}
			}
		//log.trace("render at {}", __LINE__);
			
			// prevent state leaking
			unsetObjUniforms(
				efInst.getUniformPtrsDataPtr(),
				efInst.getUniformParamGroup()
			);
		//log.trace("render at {}", __LINE__);
		}
		//log.trace("render at {}", __LINE__);
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


private struct FramebufferImpl {
	struct Attachments {
		const int numColorBuffers = FramebufferConfig.color.length;
		
		struct Attachment {
			GLenum	glAttachment;
			//bool	isTexture;
			GLuint	rb;
			Texture	tex;
		}
		
		Attachment					depth;
		Attachment[numColorBuffers]	color;
	}


	ptrdiff_t			refCount;
	GLuint				handle;
	FramebufferConfig	cfg;
	FramebufferSettings	settings;
	Attachments			attachments;
	bool				isMainFB;



	static FramebufferImpl opCall(GLuint handle) {
		FramebufferImpl res;
		res.refCount = 1;
		res.handle = handle;
		res.initAttachmentIds();
		res.settings.clearColorValue[] = vec4.zero;
		res.settings.clearColorEnabled[] = true;
		return res;
	}

	private void initAttachmentIds() {
		attachments.depth.glAttachment = DEPTH_ATTACHMENT_EXT;
		foreach (i, ref c; attachments.color) {
			c.glAttachment = COLOR_ATTACHMENT0_EXT + i;
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
	Array!(EffectInstanceImpl*)	tmp;
	bool						instancesSorted = false;
	
	
	void addInstance(EffectInstanceImpl* inst) {
		instancesSorted = false;
		inst.renderOrdinal = instances.length;
		instances.pushBack(inst);
	}

	void disposeInstance(EffectInstanceImpl* inst) {
		instancesSorted = false;
		uword ord = inst.renderOrdinal;
		uword numInstances = instances.length;
		if (ord+1 != numInstances) {
			EffectInstanceImpl** other = instances[numInstances-1];
			(*other).renderOrdinal = ord;
			*(instances[ord]) = *other;
		}
		instances.popBack();
	}

	void dispose() {
		if (instances.length > 0) {
			error("Delete all EffectInstances before deleting the Effect.");
		}
		
		instances.dispose();
		tmp.dispose();
	}
	
	u32 countSortingKeyChanges(EffectInstanceImpl*[] instances) {
		final keys = effect.instanceSortingKeys;
		if (0 == keys.length) {
			return 0;
		}

		scope stackBuffer = new StackBuffer();
		auto vals = LocalArray!(size_t)(keys.length, stackBuffer);
		scope (success) vals.dispose();
		vals.data[] = 0;
		
		u32 num = 0;
		
		foreach (inst; instances) {
			void** ld = inst.getUniformPtrsDataPtr();
			foreach (ki, k; keys) {
				final v = *cast(size_t*)(ld[k.index] + k.offset);
				if (v != vals.data[ki]) {
					++num;
					vals.data[ki] = v;
				}
			}
		}
		
		return num;
	}
	
	void sortInstances() {
		final keys = effect.instanceSortingKeys;
		if (0 == keys.length) {
			return;
		}
		
		final beforeSorting = countSortingKeyChanges(instances.ptr[0..instances.length]);
		log.trace("State changes before sorting: {}", beforeSorting);
		
		scope (success) instancesSorted = true;
		scope stackBuffer = new StackBuffer();
		auto perm = LocalArray!(u32)(instances.length, stackBuffer);
		scope (success) perm.dispose();
		foreach (i, ref x; perm.data) {
			x = i;
		}
		
		tango.core.Array.sort(perm.data, (u32 a, u32 b) {
			void** ld1 = instances.ptr[a].getUniformPtrsDataPtr();
			void** ld2 = instances.ptr[b].getUniformPtrsDataPtr();
			foreach (k; keys) {
				final v1 = *cast(size_t*)(ld1[k.index] + k.offset);
				final v2 = *cast(size_t*)(ld2[k.index] + k.offset);
				if (v1 > v2) {
					return true;
				} else if (v1 < v2) {
					return false;
				}
			}
			return false;
		});
		
		log.trace("sortInstances.perm: {}", perm.data);
		
		tmp.resize(instances.length);
		
		foreach (i, x; perm.data) {
			tmp.ptr[i] = instances.ptr[x];
		}

		final afterSorting = countSortingKeyChanges(tmp.ptr[0..tmp.length]);
		log.trace("State changes after sorting: {}", afterSorting);

		if (afterSorting < beforeSorting) {
			foreach (i, x; perm.data) {
				instances.ptr[x].renderOrdinal = i;
			}
		
			final t = instances;
			instances = tmp;
			tmp = t;
			
			log.trace("Applied the new instance order.");
		} else {
			log.trace("Kept the old instance order.");
		}

		//assert (false);
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
		GLTextureMinFilter.LINEAR,
		GLTextureMinFilter.NEAREST,
		GLTextureMinFilter.NEAREST_MIPMAP_NEAREST,
		GLTextureMinFilter.NEAREST_MIPMAP_LINEAR,
		GLTextureMinFilter.LINEAR_MIPMAP_NEAREST,
		GLTextureMinFilter.LINEAR_MIPMAP_LINEAR
	];

	return map[e];
}


private GLenum enumToGL(TextureMagFilter e) {
	const GLenum[] map = [
		GLTextureMagFilter.LINEAR,
		GLTextureMagFilter.NEAREST
	];

	return map[e];
}


private GLenum enumToGL(TextureWrap e) {
	const GLenum[] map = [
		0,
		GLTextureWrapMode.CLAMP,
		CLAMP_TO_EDGE,
		CLAMP_TO_BORDER
	];

	return map[e];
}


private GLenum enumToGL(RenderState.Blend.Factor e) {
	alias RenderState.Blend.Factor F;
	switch (e) {
		case F.Src0Color: return SRC_COLOR;
		case F.Src1Color: return ARB_blend_func_extended.SRC1_COLOR;
		case F.Src0Alpha: return SRC_ALPHA;
		case F.Src1Alpha: return ARB_blend_func_extended.SRC1_ALPHA;
		case F.DstColor: return DST_COLOR;
		case F.DstAlpha: return DST_ALPHA;
		case F.OneMinusSrc0Color: return ONE_MINUS_SRC_COLOR;
		case F.OneMinusSrc1Color: return ARB_blend_func_extended.ONE_MINUS_SRC1_COLOR;
		case F.OneMinusSrc0Alpha: return ONE_MINUS_SRC_ALPHA;
		case F.OneMinusSrc1Alpha: return ARB_blend_func_extended.ONE_MINUS_SRC1_ALPHA;
		case F.OneMinusDstColor: return ONE_MINUS_DST_COLOR;
		case F.OneMinusDstAlpha: return ONE_MINUS_DST_ALPHA;
		case F.Zero: return ZERO;
		case F.One: return ONE;
		default: assert (false);
	}
}
