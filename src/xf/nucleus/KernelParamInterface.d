module xf.nucleus.KernelParamInterface;

private {
	import xf.Common;
	import xf.gfx.Effect : VaryingParamData;
	import xf.gfx.IndexData;
}



struct KernelParamInterface {
	VaryingParamData* getVaryingParam(cstring name) {
		assert (false, "TODO");
	}


	void setIndexData(IndexData*) {
		assert (false, "TODO");
	}
}
