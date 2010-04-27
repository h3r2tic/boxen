module xf.gfx.Texture;

public {
	import xf.gfx.TextureInternalFormat;
}

private {
	import xf.gfx.Resource;
	import xf.omg.core.LinearAlgebra;
	import xf.img.Image;
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


interface ITextureMngr {
	Texture createTexture(Image img, TextureRequest req = TextureRequest.init);
	Texture createTexture(vec2i size, TextureRequest req, vec4 delegate(vec3) = null);
	void	updateTexture(Texture, vec2i origin, vec2i size, ubyte* data);
	vec3i	getSize(TextureHandle handle);
	size_t	getApiHandle(TextureHandle handle);
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
}
