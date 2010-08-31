module xf.nucleus.Scene;

private {
	import xf.Common;

	import xf.nucleus.Nucleus;
	import xf.nucleus.Renderable;
	import xf.nucleus.RenderList;

	import xf.nucleus.asset.CompiledSceneAsset;
	import xf.nucleus.asset.CompiledMeshAsset;

	import xf.nucleus.structure.MeshStructure;
	import xf.nucleus.structure.KernelMapping;

	import xf.vsd.VSD;

	import xf.omg.core.CoordSys;
	import xf.omg.util.ViewSettings;

	import xf.mem.ScratchAllocator;
	import xf.mem.MainHeap;
}



void loadScene(
	CompiledSceneAsset asset,
	VSDRoot* vsd,
	CoordSys coordSys,
	void delegate(uword, RenderableId) assetRenderableMapWatcher = null
) {
	final allocator = DgScratchAllocator(&mainHeap.allocRaw);

	cstring surface = "TestSurface4";

	// TODO: load materials

	foreach (mat; asset.materials) {
		loadMaterial(mat);
	}
	
	foreach (uword i, compiledMesh; asset.meshes) {
		final ms = allocator._new!(MeshStructure)(compiledMesh, rendererBackend);
		assert (ms !is null);

		final rid = createRenderable();

		vsd.createObject(rid);

		renderables.structureKernel[rid] = defaultStructureKernel(ms.structureTypeName);
		renderables.structureData[rid] = ms;

		final matName =	asset.meshMaterials[i]
			? asset.meshMaterials[i].name
			: "ErrorMaterial";

		renderables.material[rid] = getMaterialIdByName(
			matName
		);
		renderables.surface[rid] = getSurfaceIdByName(surface);
		
		renderables.transform[rid] = asset.meshCS[i] in coordSys;
		renderables.localHalfSize[rid] = compiledMesh.halfSize;

		if (assetRenderableMapWatcher) {
			assetRenderableMapWatcher(i, rid);
		}
	}
}



void buildRenderList(VSDRoot* vsd, ViewSettings viewSettings, RenderList* rlist) {
	vsd.findVisible(viewSettings, (VisibleObject[] olist) {
		foreach (o; olist) {
			final bin = rlist.add();
			static assert (RenderableId.sizeof == typeof(o.id).sizeof);
			rlist.list.renderableId[bin] = cast(RenderableId)o.id;
			rlist.list.coordSys[bin] = renderables.transform[o.id];
		}
	});
}
