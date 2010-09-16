module xf.gfx.IndexData;

private {
	import xf.Common;
	import xf.gfx.IndexBuffer;
}



enum MeshTopology : u8 {
	Points,
	LineStrip,
	LineLoop,
	Lines,
	TriangleStrip,
	TriangleFan,
	Triangles,
	LinesAdjacency,
	LineStripAdjacency,
	TrianglesAdjacency,
	TriangleStripAdjacency
}


struct IndexData {
	IndexBuffer		indexBuffer;
	uword			numIndices	= 0;	// used even for renderable items flagged with NoIndices
	word			indexOffset	= 0;	// ditto
	uword			minIndex	= 0;
	uword			maxIndex	= uword.max;
	MeshTopology	topology	= MeshTopology.Triangles;	// ditto
	bool			useIndexBuffer	= true;
}
