module xf.gfx.TextureCache;

private {
	import
		xf.Common,
		xf.gfx.Texture,
		xf.img.Image,
		xf.mem.ChunkQueue,
		xf.mem.ScratchAllocator;

	import
		tango.util.container.Container,
		tango.util.container.HashMap;
}


// TODO: mem (the HashMap instance uses the GC due to Tango's class-based containers)
struct TextureCache {
	private {
		alias HashMap!(
			TextureCacheKey,
			TextureHandle,
			Container.hash,
			Container.reap,
			Container.Malloc
		) Map;
		
		Map			map;
		ScratchFIFO	keyMem;
	}

	void initialize() {
		map = new Map;
		keyMem.initialize();
	}

	TextureHandle* find(TextureCacheKey key) {
		if (auto v = key in map) {
			return v;
		} else {
			return null;
		}
	}

	void remove(TextureCacheKey key) {
		map.removeKey(key);
	}

	TextureCacheKey add(TextureCacheKey key, TextureHandle h) {
		key = key.dup(DgScratchAllocator(&keyMem.pushBack));
		map[key] = h;
		return key;
	}
}
