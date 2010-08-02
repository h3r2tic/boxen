module xf.nucleus.structure.KernelMapping;

private {
	import xf.Common;
}



cstring defaultStructureKernel(cstring structureTypeName) {
	switch (structureTypeName) {
		case "Mesh": return "DefaultMeshStructure";
		default: assert (false, structureTypeName);
	}
}
