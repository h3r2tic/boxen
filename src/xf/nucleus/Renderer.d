module xf.nucleus.Renderer;

private {
	import xf.nucleus.Defs;
	import xf.nucleus.Renderable;
	import xf.nucleus.RenderList;
	import xf.gfx.IRenderer : RendererBackend = IRenderer;
	import xf.utils.BitSet;
	import xf.mem.FreeList;
}



abstract class Renderer : IRenderableObserver {
	this(RendererBackend backend) {
		registerRenderableObserver(this);
		_backend = backend;
	}

	
	abstract void render(RenderList* rlist);


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
		void onRenderableCreated(RenderableId) {
		}
		
		void onRenderableDestroyed(RenderableId id) {
			_renderableValid.clear(id);
		}
		
		void onRenderableInvalidated(RenderableId id) {
			_renderableValid.clear(id);
		}
	// ----


	protected {
		DynamicBitSet		_renderableValid;
		RendererBackend		_backend;
	}
}



template MRenderer(char[] name) {
	private import Nucleus = xf.nucleus.Nucleus;
	
	static this() {
		Nucleus.registerRenderer!(ForwardRenderer)("Forward");
	}
}
