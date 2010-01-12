module xf.gfx.api.gl3.GLContextData;

private {
	import xf.gfx.api.gl3.Common;
	import xf.gfx.api.gl3.ExtensionGenConsts;
	import xf.mem.OSHeap;
}



struct GLContextData {
	void initialize() {
		size_t topLevelSizeReq = extensionFuncCounts.length * (void*[]).sizeof;
		size_t sizeReq = topLevelSizeReq;
		foreach (e; extensionFuncCounts) {
			sizeReq += e * (void*).sizeof;
		}
		
		void* raw = osHeap.allocRaw(sizeReq);
		(cast(ubyte*)raw)[0..sizeReq] = 0;
		
		void* rawEnd = raw + sizeReq;
		
		extFunctions = cast(void*[][])raw[0..topLevelSizeReq];
		raw += topLevelSizeReq;
		
		foreach (i, ref e; extFunctions) {
			auto n = extensionFuncCounts[i];
			e = cast(void*[])raw[0..n*(void*).sizeof];
			raw += n*(void*).sizeof;
		}
		
		assert (raw == rawEnd);
	}
	
	
	void*[][] extFunctions;
}


void setGLContextData(GL gl, GLContextData* data) {
	*cast(GLContextData**)&gl = data;
}


bool isGLContextDataSet(GL gl) {
	return cast(void*)&gl !is null;
}
