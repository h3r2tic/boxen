module xf.img.Loader;

private {
	import
		xf.Common,
		xf.img.Image;
		
	import tango.io.vfs.model.Vfs;
}



abstract class Loader {
	abstract void	useVfs(VfsFolder vfs);
	abstract Image	load(cstring filename, ImageRequest* req = null);
}
