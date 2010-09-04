module xf.nucleus.asset.CompiledTextureAsset;

private {
	import xf.Common;
	import xf.nucleus.Param;
	import xf.img.Image;
	import xf.utils.Optional;
}


class CompiledTextureAsset {
	cstring	bitmapPath;
	
	Optional!(Image.ColorSpace)
			colorSpace;
	// TODO
}


struct TextureAssetCompilationOptions {
	cstring imgBaseDir;
}
