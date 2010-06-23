module xf.nucleus.IPigmentData;

private {
	import xf.nucleus.KernelParam;
	import xf.nucleus.KernelParamInterface;
}



interface IPigmentData {
	int		iterKernelDataInfo(int delegate(ref KernelParamInfo));
	void	setKernelObjectData(KernelParamInterface);
	void	setKernelStaticData(KernelParamInterface);
}
