module xf.nucleus.IStructureData;

private {
	import xf.nucleus.KernelParam;
	import xf.nucleus.KernelDataInterface;
}



interface IStructureData {
	int		iterKernelDataInfo(int delegate(ref KernelParamInfo));
	void	setKernelObjectData(KernelDataInterface);
	void	setKernelStaticData(KernelDataInterface);
}
