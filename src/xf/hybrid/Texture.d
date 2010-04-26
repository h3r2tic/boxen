module xf.hybrid.Texture;

private {
	import xf.hybrid.Math;
}



/**
	Base class for a texture. Everything should be defined by a concrete implementation
*/
class Texture {
}


/**
	A texture manager capable of creating and updating textures
*/
interface TextureMngr {
	/**
		Create a texture sized 'size' and initialized to the defColor
	*/
	Texture	createTexture(vec2i size, vec4 defColor);
	
	/**
		Update a texture starting from the origin, through size, using the data
	*/
	void		updateTexture(Texture tex, vec2i origin, vec2i size, ubyte* data);
}
