module xf.img.CachedLoader;

private {
	import
		xf.Common,
		xf.img.Image,
		xf.img.Loader,
		xf.img.Log : log = imgLog, error = imgError;
		
	import tango.io.vfs.model.Vfs;
}



class CachedLoader : Loader {
	this (Loader cached) {
		assert (cached !is null);
		this.cached = cached;
	}
	
	
	override Image load(cstring filename, ImageRequest* req = null) {
		CacheKey key = CacheKey(filename, req is null ? ImageRequest.init : *req);
		
		{
			Image* c = key in cache;
			if (c !is null) {
				assert (c.valid);
				log.trace("Retrieved {} from cache.", filename);
				return *c;
			}
		}
		
		Image im = cached.load(filename, req);
		if (im.valid) {
			cache[CacheKey(key.source.dup, key.req)] = im;
			log.trace("{} cached.", filename);
		} else {
			log.warn("Cannot load image: '{}'." , filename);
		}
		
		return im;
	}
	
	
	override void useVfs(VfsFolder vfs) {
		cached.useVfs(vfs);
	}
	
	
	protected {
		Loader			cached;
		Image[CacheKey]	cache;
	}
}


private struct CacheKey {
	cstring			source;
	ImageRequest	req;
	
	hash_t toHash() {
		hash_t hash = 0;
		foreach (char c; source) {
			hash = (hash * 9) + c;
		}
		return hash + typeid(typeof(req)).getHash(&req);
	}
	
	int opCmp(CacheKey* rhs) {
		if (auto val = typeid(typeof(req)).compare(&req, &rhs.req)) {
			return val;
		}
		
		return typeid(cstring).compare(
			cast(void*)&source,
			cast(void*)&rhs.source
		);
	}

	bool opEquals(CacheKey* other) {
		return source == other.source && req == other.req;
	}
}
