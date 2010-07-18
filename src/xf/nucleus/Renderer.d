module xf.nucleus.Renderer;

private {
	import xf.Common;
	import xf.nucleus.Defs;
	import xf.nucleus.Renderable;
	import xf.nucleus.RenderList;
	import xf.nucleus.SurfaceDef;
	import xf.nucleus.MaterialDef;
	import xf.nucleus.kdef.model.IKDefRegistry;
	import xf.nucleus.kdef.model.KDefInvalidation;
	import xf.gfx.IRenderer : RendererBackend = IRenderer;
	import xf.utils.BitSet;
	import xf.mem.FreeList;
	import xf.omg.util.ViewSettings;
}



abstract class Renderer : IRenderableObserver, IKDefInvalidationObserver {
	this(RendererBackend backend) {
		registerRenderableObserver(this);
		_backend = backend;
		_renderLists.initialize();
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


	// TODO: updateSurface
	abstract void registerSurface(SurfaceDef def);
	
	// TODO: updateMaterial
	abstract void registerMaterial(MaterialDef def);

	static assert (isReferenceType!(SurfaceDef));
	static assert (isReferenceType!(MaterialDef));


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
