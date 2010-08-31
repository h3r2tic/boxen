module xf.nucleus.asset.compiler.TextureCompiler;

private {
	import xf.Common;
	import xf.nucleus.asset.CompiledTextureAsset;
	import xf.loader.scene.model.Material : LoaderMap = Map;
	import xf.mem.ScratchAllocator;
}


// TODO: put this in the asset conditioning pipeline
CompiledTextureAsset compileTextureAsset(
	LoaderMap* map,
	DgScratchAllocator allocator,
	TextureAssetCompilationOptions opts = TextureAssetCompilationOptions.init
) {
	final ctex = allocator._new!(CompiledTextureAsset)();

	// TODO: proper path joining
	ctex.bitmapPath = allocator.dupString(opts.imgBaseDir ~ map.bitmapPath);

	return ctex;
}


// TODO: put this in the asset conditioning pipeline
CompiledTextureAsset compileTextureAsset(
	cstring bitmapPath,
	DgScratchAllocator allocator,
	TextureAssetCompilationOptions opts = TextureAssetCompilationOptions.init
) {
	final ctex = allocator._new!(CompiledTextureAsset)();

	// TODO: proper path joining
	ctex.bitmapPath = allocator.dupString(opts.imgBaseDir ~ bitmapPath);

	return ctex;
}
