module xf.nucleus.IStructureData;

private {
	import xf.nucleus.KernelParam;
	import xf.nucleus.KernelParamInterface;
}



interface IStructureData {
	//int		iterKernelDataInfo(int delegate(ref KernelParamInfo));
	void	setKernelObjectData(KernelParamInterface);
	//void	setKernelStaticData(KernelParamInterface);
}
