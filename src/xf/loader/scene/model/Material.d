module xf.loader.scene.model.Material;

private {
	import xf.Common;
	import xf.omg.core.LinearAlgebra;
}



struct Map {
	bool	enabled;
	float	amount;
	cstring	bitmapPath;
	vec2	uvTile = vec2.one;
	vec2	uvOffset = vec2.zero;
}


struct Material {
	cstring		name;
	Map[]		maps;
	Material*[]	subMaterials;
	cstring		reflectanceModel;
	
	Map* getMap(uword id) {
		if (id < maps.length && maps[id].enabled) {
			return &maps[id];
		} else {
			return null;
		}
	}
	
	vec4	diffuseTint		= vec4.one;
	vec4	specularTint	= vec4.one;
	
	float	shininess = 0.1f;
	float	shininessStrength = 0.0f;
	float	ior = 1.0f;
	float	opacity = 1.0f;
}
