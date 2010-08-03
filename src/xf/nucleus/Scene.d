module xf.nucleus.Scene;

private {
	import xf.Common;

	import xf.nucleus.Nucleus;
	import xf.nucleus.Renderable;

	import xf.nucleus.asset.CompiledSceneAsset;
	import xf.nucleus.asset.CompiledMeshAsset;

	import xf.nucleus.structure.MeshStructure;
	import xf.nucleus.structure.KernelMapping;

	import xf.omg.core.CoordSys;

	import xf.mem.ScratchAllocator;
	import xf.mem.MainHeap;
}



void loadScene(
	CompiledSceneAsset asset,
	CoordSys coordSys,
) {
	final allocator = DgScratchAllocator(&mainHeap.allocRaw);

	cstring material = "TestMaterialImpl";
	cstring surface = "TestSurface3";
	
	foreach (i, compiledMesh; asset.meshes) {
		final ms = allocator._new!(MeshStructure)(compiledMesh, rendererBackend);

		final rid = createRenderable();	
		renderables.structureKernel[rid] = defaultStructureKernel(ms.structureTypeName);
		renderables.structureData[rid] = ms;

		renderables.material[rid] = getMaterialIdByName(material);
		renderables.surface[rid] = getSurfaceIdByName(surface);
		
		renderables.transform[rid] = asset.meshCS[i] in coordSys;
		renderables.localHalfSize[rid] = compiledMesh.halfSize;
	}
}
