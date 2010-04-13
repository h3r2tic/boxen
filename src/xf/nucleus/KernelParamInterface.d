module xf.nucleus.KernelParamInterface;

private {
	import xf.Common;
	import xf.gfx.Effect : VaryingParamData;
	import xf.gfx.IndexData;
}



struct KernelParamInterface {
	VaryingParamData* delegate (cstring name)
			getVaryingParam;
			
	void delegate (IndexData*)
			setIndexData;
}
