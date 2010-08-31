module xf.nucleus.asset.compiler.SceneCompiler;

private {
	import xf.Common;
	
	import xf.nucleus.asset.CompiledMeshAsset;
	import xf.nucleus.asset.CompiledMaterialAsset;
	import xf.nucleus.asset.CompiledSceneAsset;

	import xf.nucleus.asset.compiler.MeshCompiler;
	import xf.nucleus.asset.compiler.MaterialCompiler;

	import xf.loader.scene.model.Mesh : LoaderMesh = Mesh;
	import xf.loader.scene.hsf.Hsf;
	import xf.loader.Common;

	import xf.omg.core.CoordSys;

	import xf.mem.ScratchAllocator;

	import Path = tango.io.Path;
}



CompiledSceneAsset compileHSFSceneAsset(
	cstring path,
	DgScratchAllocator allocator,
	SceneAssetCompilationOptions opts = SceneAssetCompilationOptions.init
) {
	path = getResourcePath(path);
	
	scope loader = new HsfLoader;
	loader.load(path);

	return compileHSFSceneAsset(loader, allocator, opts);
}


CompiledSceneAsset compileHSFSceneAsset(
	HsfLoader loader,
	DgScratchAllocator allocator,
	SceneAssetCompilationOptions opts = SceneAssetCompilationOptions.init
) {
	final scene = loader.scene;
	assert (scene !is null);
	assert (loader.meshes.length > 0);
	
	assert (1 == scene.nodes.length);
	final root = scene.nodes[0];

	final result = allocator._new!(CompiledSceneAsset)();
	result.meshes = allocator.allocArrayNoInit!(CompiledMeshAsset)(loader.meshes.length);
	result.meshCS = allocator.allocArrayNoInit!(CoordSys)(loader.meshes.length);
	result.meshMaterials = allocator.allocArrayNoInit!(CompiledMaterialAsset)(loader.meshes.length);

	result.materials = allocator.allocArrayNoInit!(CompiledMaterialAsset)(loader.materials.length);

	foreach (i, ref m; loader.materials) {
		MaterialAssetCompilationOptions mopts;
		mopts.imgBaseDir = "mesh/";
		result.materials[i] = compileMaterialAsset(m, allocator, mopts);
	}

	foreach (i, ref m; loader.meshes) {
		MeshAssetCompilationOptions mopts;
		mopts.scale = opts.scale;

		CoordSys scaledCS = m.node.localCS;
		scaledCS.origin *= opts.scale;

		result.meshes[i] = compileMeshAsset(m, allocator, mopts);
		result.meshCS[i] = scaledCS in opts.coordSys;
		result.meshMaterials[i] =
			m.material
			? result.materials[m.material - loader.materials.ptr]
			: null;
	}

	return result;
}
