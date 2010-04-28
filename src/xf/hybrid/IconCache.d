module xf.hybrid.IconCache;

private {
	import xf.hybrid.BoxPacker;
	import xf.hybrid.Math;
	import xf.utils.Memory;
	import xf.hybrid.Texture;
}



///
class IconCache {
	/// get some texture space of the requested size. return the offsets and a Texture object.
	Texture get(vec2i size, out vec2i bl, out vec2i tr, out vec2 blCoords, out vec2 trCoords, vec2i pad = vec2i.zero) {
		auto block = packer.getBlock(size + pad * 2);
		if (block.page >= textures.length) {
			assert (texMngr !is null);
			textures ~= texMngr.createTexture(
					vec2i(texSize.x,	texSize.y),
					vec4.zero
			);
		}
		
		bl = block.origin + pad;
		tr = block.origin + block.size - pad;
		
		blCoords = vec2(cast(float)bl.x / texSize.x, cast(float)bl.y / texSize.y);
		trCoords = vec2(cast(float)tr.x / texSize.x, cast(float)tr.y / texSize.y);

		// we'll shift the coords a bit so bilinear filtering doesn't kill us.
		/+blCoords += texelSize*0.0078125;
		trCoords += texelSize*0.0078125;+/
		
		return textures[block.page];
	}
	
	
	///
	final vec2 texelSize() {
		return vec2(1.f / texSize.x, 1.f / texSize.y);
	}
	
	
	this() {
		packer = new BoxPacker;
		packer.pageSize = texSize;
	}
	
	
	///
	void updateTexture(Texture tex, vec2i origin, vec2i size, ubyte* data) {
		if (0 == size.x || 0 == size.y) {
			return;
		}

		return texMngr.updateTexture(tex, origin, size, data);
	}
	
	
	
	TextureMngr	texMngr;
	
	BoxPacker		packer;
	Texture[]		textures;
	
	vec2i			texSize = {x: 512, y: 512};
}
