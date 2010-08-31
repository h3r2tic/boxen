module xf.nucleus.asset.CompiledSceneAsset;

private {
	import xf.Common;
	import xf.nucleus.asset.CompiledMeshAsset;
	import xf.nucleus.asset.CompiledMaterialAsset;
	import xf.omg.core.CoordSys;
}



struct SceneAssetCompilationOptions {
	float		scale = 1.0;
	CoordSys	coordSys = CoordSys.identity;
}


class CompiledSceneAsset {
	CompiledMeshAsset[]		meshes;
	CoordSys[]				meshCS;
	CompiledMaterialAsset[]	meshMaterials;
	
	CompiledMaterialAsset[]	materials;
}
