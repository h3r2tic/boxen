module xf.nucleus.Material;

private {
	import xf.nucleus.Defs;
	import xf.nucleus.KernelImpl;
	import xf.nucleus.asset.CompiledMaterialAsset;
}


class Material {
	CompiledMaterialAsset	asset;
	
	KernelImpl	materialKernel;
	MaterialId	id;
}
