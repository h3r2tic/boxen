module xf.nucleus.util.AbstractRegistry;

private {
	import tango.io.vfs.model.Vfs;
	import tango.text.convert.Utf;
	
	import tango.io.Stdout;
	import Path = tango.io.Path;
}



class AbstractRegistry {
	this(char[] fnmatch) {
		_fnmatch = fnmatch;
	}	
	
	
	void setVFS(VfsFolder host) {
		_vfs = host;
	}
	
	
	synchronized void registerFolder(char[] path) {
		_reg ~= Reg(Reg.Type.Folder, path.dup);
	}
	
	
	synchronized void registerFile(VfsFile file) {
		auto fpath = Path.normalize(file.toString).dup;
		_reg ~= Reg(Reg.Type.File, fpath.dup);
	}



	synchronized int iterAllFiles(int delegate(ref char[] path) sink) {
		foreach (r; _reg) {
			switch (r.type) {
				case Reg.Type.Folder: {
					auto folder = _vfs.folder(r.path).open;
					scope(exit) folder.close;
					
					foreach (entry; folder.tree.catalog(_fnmatch)) {
						auto arg = Path.normalize(entry.toString);
						if (int res = sink(arg)) {
							return res;
						}
					}
				} break;
				
				case Reg.Type.File: {
					if (int res = sink(r.path)) {
						return res;
					}
				} break;

				default: assert (false);
			}
		}

		return 0;
	}


	synchronized void processRegistrations() {
		foreach (path; &iterAllFiles) {
			path = path.dup;
			_allFiles ~= LeafFile(path, Path.modified(path).ticks);
			processFile(path);
		}
	}
	
	
	abstract void processFile(char[] path) {
	}
	
	
	protected {
		char[]		_fnmatch;
		VfsFolder	_vfs;

		struct Reg {
			enum Type {
				Folder,
				File
			}

			Type	type;
			char[]	path;

			bool opEquals(ref Reg other) {
				return type == other.type && path == other.path;
			}
		}

		struct LeafFile {
			char[]	path;
			long	timeModified;

			bool opEquals(ref LeafFile other) {
				return other.timeModified == timeModified && other.path == path;
			}
		}

		Reg[]		_reg;
		LeafFile[]	_allFiles;
	}
}
