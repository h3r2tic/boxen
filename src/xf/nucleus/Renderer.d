
module xf.nucleus.Renderer;

private {
	import xf.Common;
	
	import
		xf.nucleus.Defs,
		xf.nucleus.Param,
		xf.nucleus.Renderable,
		xf.nucleus.RendererMaterialData,
		xf.nucleus.Light,
		xf.nucleus.RenderList,
		xf.nucleus.SurfaceDef,
		xf.nucleus.MaterialDef,
		xf.nucleus.SamplerDef,
		xf.nucleus.kdef.model.IKDefRegistry,
		xf.nucleus.kdef.model.KDefInvalidation;
	import
		xf.vsd.VSD;
	import
		xf.gfx.IRenderer : RendererBackend = IRenderer;
	import
		xf.utils.BitSet;	
	import
		xf.mem.MainHeap,
		xf.mem.FreeList,
		xf.mem.Array;
	import
		xf.omg.util.ViewSettings;
	import
		tango.core.Variant;
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
		//_materialMem.initialize();
	}


	// temp HACK until something like OldCfg is revived proper.
	void setParam(cstring name, Variant value) {
		error("The {} does not support a param named '{}'.", this.classinfo.name, name);
	}

	
	abstract void render(ViewSettings, VSDRoot* vsd, RenderList*);


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
		Array!(MaterialData)	_materials;
		Array!(KernelImplId)	_materialKernels;	// aliased from the MaterialDef
		//ScratchFIFO				_materialMem;
	}


	// TODO: mem
	/+override +/void registerMaterial(MaterialDef def) {
		if (def.id >= _materials.length) {
			final gb = def.id - _materials.length + 1;
			_materials.growBy(gb);
			_materialKernels.growBy(gb);
		}
		
		auto mat = _materials[def.id];
		static assert (isReferenceType!(typeof(mat)));

		assert (def.materialKernel.id.isValid);
		_materialKernels[def.id] = def.materialKernel.id;
		createMaterialData(_backend, def.params, mat);
	}


	protected void unregisterMaterials() {
		foreach (ref m; _materials) {
			m.dispose();
		}

		_materials.resize(0);
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
