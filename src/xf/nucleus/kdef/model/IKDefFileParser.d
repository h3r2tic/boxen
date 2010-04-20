module xf.nucleus.kdef.model.IKDefFileParser;

private {
	import xf.nucleus.kdef.Common;
	import tango.io.vfs.model.Vfs;
	alias char[] string;
}



interface IKDefFileParser {
	KDefModule parseFile(string sourcePath);
	void setVFS(VfsFolder);
}
