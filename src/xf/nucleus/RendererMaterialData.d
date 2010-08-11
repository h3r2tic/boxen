module xf.nucleus.RendererMaterialData;

private {
	import xf.Common;
}



struct MaterialData {
	struct Info {
		cstring	name;		// not owned here
		word	offset;
	}
	
	Info[]		info;
	void*		data;
	cstring		kernelName;
	//KernelImpl	materialKernel;
}

