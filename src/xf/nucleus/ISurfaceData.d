module xf.nucleus.ISurfaceData;

private {
	import xf.nucleus.KernelParam;
	import xf.nucleus.KernelParamInterface;
}



interface ISurfaceData {
	int		iterKernelDataInfo(int delegate(ref KernelParamInfo));
	void	setKernelObjectData(KernelParamInterface);
	void	setKernelStaticData(KernelParamInterface);
}
