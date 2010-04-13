module xf.gfx.IndexData;

private {
	import xf.Common;
	import xf.gfx.IndexBuffer;
}



struct IndexData {
	IndexBuffer	indexBuffer;
	uword		numIndices	= 0;
	word		indexOffset	= 0;
	uword		minIndex	= 0;
	uword		maxIndex	= uword.max;
}
