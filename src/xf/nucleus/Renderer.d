module xf.nucleus.Renderer;

private {
	import xf.Common;
	
	import
		xf.nucleus.Defs,
		xf.nucleus.Param,
		xf.nucleus.Renderable,
		xf.nucleus.Light,
		xf.nucleus.RenderList,
		xf.nucleus.SurfaceDef,
		xf.nucleus.MaterialDef,
		xf.nucleus.SamplerDef,
		xf.nucleus.kdef.model.IKDefRegistry,
		xf.nucleus.kdef.model.KDefInvalidation;

	// TODO: refactor into a shared texture loader
	interface Img {
	import
		xf.img.Image,
		xf.img.FreeImageLoader,
		xf.img.CachedLoader,
		xf.img.Loader;
	}
		
	import
		xf.gfx.Texture,
		xf.gfx.IRenderer : RendererBackend = IRenderer;
	
	import xf.utils.BitSet;
	
	import
		xf.mem.MainHeap,
		xf.mem.FreeList,
		xf.mem.Array,
		/+xf.mem.ChunkQueue,
		xf.mem.ScratchAllocator,+/
		MemUtils = xf.utils.Memory;
		
	import xf.omg.util.ViewSettings;
	import tango.core.Variant;
}



abstract class Renderer
:	IRenderableObserver,
	ILightObserver,
	IKDefInvalidationObserver
{
	this(RendererBackend backend) {
		registerRenderableObserver(this);
		_backend = backend;
		_renderLists.initialize();
		_imgLoader = new Img.CachedLoader(new Img.FreeImageLoader);
		//_materialMem.initialize();
	}


	// temp HACK until something like OldCfg is revived proper.
	void setParam(cstring name, Variant value) {
		error("The {} does not support a param named '{}'.", this.classinfo.name, name);
	}

	
	abstract void render(ViewSettings, RenderList*);


	// RenderList ----
	
	NondestructiveFreeList!(RenderList)	_renderLists;
	
	// implements IRenderer
	RenderList* createRenderList() {
		final reused = !_renderLists.isEmpty();
		final res = _renderLists.alloc();
		if (!reused) {
			*res = RenderList.init;
		}
		res.clear();
		return res;
	}
	
	
	// implements IRenderer
	void disposeRenderList(RenderList* rl) {
		_renderLists.free(rl);
	}

	// ----
	

	
	// Implement IRenderableObserver
		void onRenderableCreated(RenderableId id) {
			// HACK
			_renderableValid.alloc(id+1);
		}
		
		void onRenderableDisposed(RenderableId id) {
			_renderableValid.clear(id);
		}
		
		void onRenderableInvalidated(RenderableId id) {
			_renderableValid.clear(id);
		}
	// ----


	// Implement ILightObserver
	void onLightCreated(LightId) {
	}
	
	void onLightDisposed(LightId) {
	}
	
	void onLightInvalidated(LightId) {
	}
	// ----


	// TODO: updateSurface
	void registerSurface(SurfaceDef def) {}
	
	// TODO: updateMaterial
	//abstract void registerMaterial(MaterialDef def);

	static assert (isReferenceType!(SurfaceDef));
	static assert (isReferenceType!(MaterialDef));


	protected {
		struct MaterialData {
			struct Info {
				cstring	name;		// not owned here
				word	offset;
			}
			
			Info[]		info;
			void*		data;
			cstring		kernelName;
			//KernelImpl	materialKernel;
		}

		Array!(MaterialData)	_materials;
		//ScratchFIFO				_materialMem;
	}


	public {
		Img.Loader	_imgLoader;
	}


	// TODO: mem
	/+override +/void registerMaterial(MaterialDef def) {
		if (def.id >= _materials.length) {
			_materials.growBy(def.id - _materials.length + 1);
		}
		
		auto mat = _materials[def.id];
		static assert (isReferenceType!(typeof(mat)));
		
		MemUtils.alloc(mat.info, def.params.length);

		//assert (def.reflKernel !is null);
		mat.kernelName = /+DgScratchAllocator(&_materialMem.pushBack)
			.dupString(+/def.materialKernel.name;//);

		uword sizeReq = 0;
		
		foreach (i, p; def.params) {
			uword psize = p.valueSize;

			switch (p.valueType) {
				case ParamValueType.ObjectRef: {
					Object objVal;
					p.getValue(&objVal);
					if (auto sampler = cast(SamplerDef)objVal) {
						psize = Texture.sizeof;
					} else {
						error(
							"Forward renderer: Don't know what to do with"
							" a {} material param ('{}').",
							objVal.classinfo.name,
							p.name
						);
					}
				} break;

				case ParamValueType.String:
				case ParamValueType.Ident: {
					error(
						"Forward renderer: Don't know what to do with"
						" string/ident material params ('{}').",
						p.name
					);
				} break;

				default: break;
			}

			assert (psize != 0);
			
			// TODO: get clear ownership rules here
			mat.info[i].name = cast(cstring)p.name;
			mat.info[i].offset = sizeReq;
			sizeReq += psize;
			sizeReq += (uword.sizeof - 1);
			sizeReq &= ~(uword.sizeof - 1);
		}

		mat.data = mainHeap.allocRaw(sizeReq);
		memset(mat.data, 0, sizeReq);

		foreach (i, p; def.params) {
			void* dst = mat.data + mat.info[i].offset;
			assert (dst < mat.data + sizeReq);
			
			switch (p.valueType) {
				case ParamValueType.ObjectRef: {
					Object objVal;
					p.getValue(&objVal);
					if (auto sampler = cast(SamplerDef)objVal) {
						// TODO: proper handling of sampler objects and textures,
						// separately, using the new GL 3.3 extension
						Texture* tex = cast(Texture*)dst;
						loadMaterialSamplerParam(sampler, tex);
					} else {
						error(
							"Forward renderer: Don't know what to do with"
							" a {} material param ('{}').",
							objVal.classinfo.name,
							p.name
						);
					}
				} break;

				case ParamValueType.String:
				case ParamValueType.Ident: {
					error(
						"Forward renderer: Don't know what to do with"
						" string/ident material params ('{}').",
						p.name
					);
				} break;

				default: {
					memcpy(dst, p.value, p.valueSize);
				} break;
			}
		}
	}


	protected void loadMaterialSamplerParam(SamplerDef sampler, Texture* tex) {
		if (auto val = sampler.params.get("texture")) {
			cstring filePath;
			val.getValue(&filePath);

			Img.Image img = _imgLoader.load(filePath);
			if (!img.valid) {
				// TODO: fallback
				error("Could not load texture: '{}'", filePath);
			}

			*tex = _backend.createTexture(
				img
			);
		} else {
			assert (false, "TODO: use a fallback texture");
		}
	}


	protected {
		DynamicBitSet		_renderableValid;
		RendererBackend		_backend;
	}
}



template MRenderer(char[] name) {
	private import Nucleus = xf.nucleus.Nucleus;
	
	static this() {
		Nucleus.registerRenderer!(typeof(this))(name);
	}
}
