module xf.loader.Common;

private {
	import xf.Common;
	import Path = tango.io.Path;
}


private cstring _mediaDir;



void setMediaDir(cstring path) {
	_mediaDir = Path.normalize(path);
}

cstring getResourcePath(cstring path) {
	assert (_mediaDir !is null, "Call setMediaDir() at program startup.");
	return Path.join(_mediaDir, Path.normalize(path));
}
