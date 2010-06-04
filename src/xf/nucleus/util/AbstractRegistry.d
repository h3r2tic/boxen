module xf.nucleus.util.AbstractRegistry;

private {
	import tango.io.vfs.model.Vfs;
	import tango.text.convert.Utf;

	import tango.io.Stdout;
	import PathUtil = tango.io.Path;
}



class AbstractRegistry {
	alias void* delegate(size_t) Allocator;

	
	this(char[] fnmatch) {
		_fnmatch = fnmatch;
	}	
	
	
	void setVFS(VfsFolder host) {
		_vfs = host;
	}
	
	
	void registerFolder(char[] path, Allocator allocator) {
		auto folder = _vfs.folder(path).open;
		scope(exit) folder.close;
		
		foreach (entry; folder.tree.catalog(_fnmatch)) {
			registerFile(entry, allocator);
		}
	}
	
	
	synchronized void registerFile(VfsFile file, Allocator allocator) {
		processFile(PathUtil.normalize(file.toString), allocator);
	}
	
	
	abstract void processFile(char[] path, Allocator allocator) {
	}
	
	
	protected {
		char[]		_fnmatch;
		VfsFolder	_vfs;
	}
}
