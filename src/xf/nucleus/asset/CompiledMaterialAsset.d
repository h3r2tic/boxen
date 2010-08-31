module xf.nucleus.asset.CompiledMaterialAsset;

private {
	import xf.Common;
	import xf.nucleus.Param;
	import xf.omg.core.LinearAlgebra;
	import xf.mem.MultiArray;
}


class CompiledMaterialAsset {
	struct Params {
		uword			length;
		cstring*		name;
		ParamValueType*	valueType;
		void**			value;
	}

	cstring	name;
	cstring	kernelName;
	Params	params;
}


struct MaterialAssetCompilationOptions {
	cstring imgBaseDir;
}
