module xf.nucleus.kdef.model.IKDefFileParser;

private {
	import xf.nucleus.kdef.Common;
	import tango.io.vfs.model.Vfs;
	import xf.mem.ScratchAllocator;
	alias char[] string;
}



interface IKDefFileParser {
	KDefModule parseFile(string sourcePath, DgScratchAllocator);
	void setVFS(VfsFolder);
}
