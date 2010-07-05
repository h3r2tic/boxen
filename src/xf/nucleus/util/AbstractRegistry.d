module xf.nucleus.util.AbstractRegistry;

private {
	import tango.io.vfs.model.Vfs;
	import tango.text.convert.Utf;
	
	import tango.io.Stdout;
	import PathUtil = tango.io.Path;
}



class AbstractRegistry {
	this(char[] fnmatch) {
		_fnmatch = fnmatch;
	}	
	
	
	void setVFS(VfsFolder host) {
		_vfs = host;
	}
	
	
	void registerFolder(char[] path) {
		auto folder = _vfs.folder(path).open;
		scope(exit) folder.close;
		
		foreach (entry; folder.tree.catalog(_fnmatch)) {
			registerFile(entry);
		}
	}
	
	
	synchronized void registerFile(VfsFile file) {
		processFile(PathUtil.normalize(file.toString));
	}
	
	
	abstract void processFile(char[] path) {
	}
	
	
	protected {
		char[]		_fnmatch;
		VfsFolder	_vfs;
	}
}
