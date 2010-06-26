module xf.nucleus.KernelParamInterface;

private {
	import xf.Common;
	import xf.gfx.Effect : VaryingParamData;
	import xf.gfx.IndexData;
	import xf.gfx.Log;
}



struct KernelParamInterface {
	VaryingParamData* delegate (cstring name)
			getVaryingParam;
			
	void** delegate (cstring name)
			getUniformParam;

	void delegate (IndexData*)
			setIndexData;


	// TODO: check type info
	void bindUniform(cstring name, void* ptr) {
		if (auto pp = getUniformParam(name)) {
			*pp = ptr;
		} else {
			gfxLog.warn("{} not found in an effect. Perhaps the scope is wrong?", name);
		}
	}
}
