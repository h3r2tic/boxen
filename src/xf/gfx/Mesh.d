module xf.gfx.Mesh;

private {
	import xf.Common;
	import
		xf.omg.core.LinearAlgebra,
		xf.omg.core.CoordSys;
	import
		xf.gfx.Effect,
		xf.gfx.IndexBuffer,
		xf.gfx.RenderList;
}



interface IMeshMngr {
	Mesh[] createMeshes(int num);
	void destroyMeshes(ref Mesh[] meshes);
}



struct Mesh {
	CoordSys		coordSys = CoordSys.identity;
	EffectInstance	effectInstance;
	private IndexBuffer
					_indexBuffer;

	uword			numIndices	= 0;
	word			indexOffset	= 0;
	uword			minIndex	= 0;
	uword			maxIndex	= uword.max;
	
	MeshTopology	topology = MeshTopology.Triangles;
	

	Effect effect() {
		return effectInstance.getEffect;
	}
	
	
	IndexBuffer indexBuffer(IndexBuffer buf) {
		if (buf.valid && buf.acquire) {
			if (_indexBuffer.valid) {
				_indexBuffer.dispose();
			}

			_indexBuffer = buf;
		} else {
			if (_indexBuffer.valid) {
				_indexBuffer.dispose();
			}
		}

		return _indexBuffer;
	}
	
	
	IndexBuffer indexBuffer() {
		return _indexBuffer;
	}
	
	
	void toRenderableData(RenderableData* rd) {
		rd.coordSys = coordSys;
		rd.indexBuffer = indexBuffer;
		rd.numInstances = 1;
		rd.numIndices	= numIndices;
		rd.indexOffset	= indexOffset;
		rd.minIndex	= minIndex;
		rd.maxIndex	= maxIndex;
		rd.topology = topology;
	}
}
