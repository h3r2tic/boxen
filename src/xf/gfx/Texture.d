module xf.gfx.Texture;

public {
	import xf.gfx.TextureInternalFormat;
}

private {
	import xf.Common;
	import xf.gfx.Resource;
	import xf.omg.core.LinearAlgebra;
	import xf.img.Image;
	import xf.mem.ScratchAllocator;
}


typedef ResourceHandle TextureHandle;


enum TextureType {
	Texture1D = 0,
	Texture2D,
	Texture3D,
	TextureCube,
	TextureRectangle
}


enum TextureMinFilter {
	Linear = 0,
	Nearest,
	NearestMipmapNearest,
	NearestMipmapLinear,
	LinearMipmapNearest,
	LinearMipmapLinear
}


bool needsMipmap(TextureMinFilter filter) {
	return filter != TextureMinFilter.Linear && filter != TextureMinFilter.Nearest;
}


enum TextureMagFilter {
	Linear = 0,
	Nearest
}


enum TextureWrap {
	NoWrap = 0,
	Clamp,
	ClampToEdge,
	ClampToBorder
}


enum CubeMapFace {
	PositiveX = 0,
	NegativeX,
	PositiveY,
	NegativeY,
	PositiveZ,
	NegativeZ
}


struct TextureRequest {
	TextureType				type			= TextureType.Texture2D;
	TextureInternalFormat	internalFormat	= TextureInternalFormat.SRGB8_ALPHA8;
	TextureMinFilter		minFilter		= TextureMinFilter.LinearMipmapLinear;
	TextureMagFilter		magFilter		= TextureMagFilter.Linear;
	TextureWrap				wrapS			= TextureWrap.NoWrap;
	TextureWrap				wrapT			= TextureWrap.NoWrap;
	TextureWrap				wrapR			= TextureWrap.NoWrap;
	int						border			= 0;
	vec4					borderColor		= {r: 0, g: 0, b: 0, a: 1};
}


struct TextureCacheKey {
	// does not duplicate the string from the source
	static TextureCacheKey path(cstring s) {
		TextureCacheKey key;
		key.sourcePath = s;
		key.computeHash();
		return key;
	}

	hash_t toHash() {
		return hash;
	}

	bool opEquals(TextureCacheKey other) {
		return this.hash == other.hash && this.sourcePath == other.sourcePath;
	}

	void computeHash() {
		hash = typeid(cstring).getHash(&sourcePath);
	}

	TextureCacheKey dup(DgScratchAllocator mem) {
		TextureCacheKey res;
		res.hash = this.hash;
		res.sourcePath = mem.dupString(this.sourcePath);
		return res;
	}
	
	cstring	sourcePath;
	hash_t	hash;
}


interface ITextureMngr {
//	Texture createTexture(Image img, TextureRequest req = TextureRequest.init);
	Texture createTexture(Image img, TextureCacheKey key, TextureRequest req = TextureRequest.init);
	Texture createTexture(vec2i size, TextureRequest req, vec4 delegate(vec3) = null);
	void	updateTexture(Texture, vec2i origin, vec2i size, ubyte* data);
	void	updateTexture(Texture, vec2i origin, vec2i size, float* data);
	vec3i	getSize(TextureHandle handle);
	size_t	getApiHandle(TextureHandle handle);
	bool	getInfo(TextureHandle handle, TextureRequest*);
}


struct Texture {
	alias TextureHandle Handle;
	mixin MResource;


	vec3i getSize() {
		assert (_resHandle !is Handle.init);
		assert (_resMngr !is null);
		return (cast(ITextureMngr)_resMngr).getSize(_resHandle);
	}

	size_t getApiHandle() {
		assert (_resHandle !is Handle.init);
		assert (_resMngr !is null);
		return (cast(ITextureMngr)_resMngr).getApiHandle(_resHandle);
	}

	bool getInfo(TextureRequest* info) {
		assert (_resHandle !is Handle.init);
		assert (_resMngr !is null);
		return (cast(ITextureMngr)_resMngr).getInfo(_resHandle, info);
	}
}
