module xf.nucleus.Renderable;

private {
	import xf.Common;
	import xf.nucleus.Defs;
	import xf.nucleus.Kernel;
	import xf.nucleus.IStructureData;
	import xf.nucleus.ISurfaceData;
	import xf.omg.core.CoordSys;
	import xf.mem.MultiArray;
	import xf.mem.Array;
}


// Renderables as a 'Struct of Arrays'
mixin(multiArray(`renderables`, `
	Kernel*				structureKernel
	IStructureData		structureData
	Kernel*				surfaceKernel
	ISurfaceData		surfaceData
	CoordSys			transform
`));


interface IRenderableObserver {
	void onRenderableCreated(RenderableId);
	void onRenderableDisposed(RenderableId);
	void onRenderableInvalidated(RenderableId);
}


RenderableId createRenderable() {
	RenderableId res = void;
	
	if (_renderableIdPool.length > 0) {
		res = _renderableIdPool.popBack();
	} else {
		res = cast(RenderableId)renderables.length;
		renderables.growBy(1);
	}

	renderables.structureKernel[0] = null;
	renderables.structureData[0] = null;
	renderables.surfaceKernel[0] = null;
	renderables.surfaceData[0] = null;
	renderables.transform[0] = CoordSys.identity;

	foreach (o; _renderableObservers) {
		o.onRenderableCreated(res);
	}

	return res;
}


void disposeRenderable(RenderableId r) {
	foreach (o; _renderableObservers) {
		o.onRenderableDisposed(r);
	}

	_renderableIdPool.pushBack(r);
}


void invalidateRenderable(RenderableId id) {
	// TODO: make sure the id is correct
	
	foreach (o; _renderableObservers) {
		o.onRenderableInvalidated(id);
	}
}


void registerRenderableObserver(IRenderableObserver o) {
	_renderableObservers ~= o;
}


private {
	IRenderableObserver[] _renderableObservers;
	Array!(
		RenderableId,
		ArrayExpandPolicy.FixedAmount!(1024)
	)	_renderableIdPool;
}
