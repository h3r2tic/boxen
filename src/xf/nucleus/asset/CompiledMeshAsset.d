module xf.nucleus.asset.CompiledMeshAsset;

private {
	import xf.Common;
	import xf.gfx.VertexBuffer : VertexAttrib;
	import xf.omg.core.LinearAlgebra;
}



struct CompiledMeshVertexAttrib {
	cstring			name;
	VertexAttrib	attrib;
}


class CompiledMeshAsset {
	// allocated using the allocator passed to MeshCompiler
	void[]						vertexData;
	CompiledMeshVertexAttrib[]	vertexAttribs;
	u32[]						indices;
	// ----
	
	uword	numIndices	= 0;
	word	indexOffset	= 0;
	uword	minIndex	= 0;
	uword	maxIndex	= uword.max;

	vec3	halfSize	= vec3.zero;
}


struct MeshAssetCompilationOptions {
	float	scale = 1.0;
}
