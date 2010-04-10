module xf.nucleus.ISurfaceData;

private {
	import xf.nucleus.KernelParam;
	import xf.nucleus.KernelDataInterface;
}



interface ISurfaceData {
	int		iterKernelDataInfo(int delegate(ref KernelParamInfo));
	void	setKernelObjectData(KernelDataInterface);
	void	setKernelStaticData(KernelDataInterface);
}
