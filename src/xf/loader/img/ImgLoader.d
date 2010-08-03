module xf.loader.img.ImgLoader;

private {
	interface Img {
	import
		xf.img.Image,
		xf.img.FreeImageLoader,
		xf.img.CachedLoader,
		xf.img.Loader;
	}
}


Img.Loader imgLoader;


static this() {
	imgLoader = new Img.CachedLoader(new Img.FreeImageLoader);
}
