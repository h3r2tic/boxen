module xf.boxen.Rendering;

private {
	import xf.gfx.Mesh;
	import xf.game.Defs;
	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.CoordSys;
	import xf.mem.MultiArray;
}



mixin(multiArray(`meshes`, `
	Mesh*		mesh
	CoordSys	offset
	objId		offsetFrom
	vec3		scale
`));


void addMesh(Mesh* m, CoordSys offset, objId offsetFrom, vec3 scale = vec3.one) {
	final idx = meshes.growBy(1);
	meshes.mesh[idx] = m;
	meshes.offset[idx] = offset;
	meshes.offsetFrom[idx] = offsetFrom;
	meshes.scale[idx] = scale;
}
