module xf.nucleus.IStructureData;

private {
	import xf.Common;
	import xf.nucleus.KernelParam;
	import xf.nucleus.KernelParamInterface;
}



interface IStructureData {
	//int		iterKernelDataInfo(int delegate(ref KernelParamInfo));
	cstring structureTypeName();
	void	setKernelObjectData(KernelParamInterface);
	//void	setKernelStaticData(KernelParamInterface);
}
