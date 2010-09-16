module xf.nucleus.structure.KernelMapping;

private {
	import xf.Common;
}



cstring defaultStructureKernel(cstring structureTypeName) {
	switch (structureTypeName) {
		case "Mesh": return "DefaultMeshStructure";
		case "PointCloud": return "DefaultPointCloudStructure";
		default: assert (false, structureTypeName);
	}
}
