module xf.gfx.Mesh;

private {
	import xf.Common;
	import
		xf.omg.core.LinearAlgebra,
		xf.omg.core.CoordSys;
	import
		xf.gfx.GPUEffect,
		xf.gfx.IndexBuffer;
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


private struct MeshRenderData {
	mat34	modelToWorld = mat34.identity;
	mat34	worldToModel = mat34.identity;

	GPUEffectInstance*	effectInstance;
	IndexBuffer			indexBuffer;

	GPUEffect effect() {
		return effectInstance._proto;
	}
	
	uword	numInstances = 1;

	uword			numIndices	= 0;
	word			indexOffset	= 0;
	uword			minIndex	= 0;
	uword			maxIndex	= uword.max;
	
	MeshTopology	topology = MeshTopology.Triangles;
	
	enum Flags : u8 {
		IndexBufferBound = 0b1
	}
	
	Flags			flags;
}


struct Mesh {
	MeshRenderData* renderData;
	
	
	CoordSys modelToWorld() {
		return _modelToWorld;
	}
	
	void modelToWorld(CoordSys cs) {
		_modelToWorld = cs;
		_dirtyFlags |= DirtyFlags.WorldMatrices;
	}
	
	
	GPUEffectInstance*	effectInstance() {
		return renderData.effectInstance;
	}
	
	void effectInstance(GPUEffectInstance* inst) {
		renderData.effectInstance = inst;
	}
	
	
	GPUEffect effect() {
		return effectInstance._proto;
	}


	void numInstances(uword num) {
		renderData.numInstances = num;
	}
	uword getNumInstances() {
		return renderData.numInstances;
	}


	IndexBuffer indexBuffer(IndexBuffer buf) {
		IndexBuffer* _indexBuffer = &renderData.indexBuffer;
		
		if (buf.valid && buf.acquire) {
			if (_indexBuffer.valid) {
				_indexBuffer.dispose();
			}

			*_indexBuffer = buf;
		} else {
			if (_indexBuffer.valid) {
				_indexBuffer.dispose();
			}
		}

		renderData.flags &= ~MeshRenderData.Flags.IndexBufferBound;
		return *_indexBuffer;
	}

	
	void numIndices(uword num) {
		renderData.numIndices = num;
	}
	uword getNumIndices() {
		return renderData.numIndices;
	}
	
	
	void indexOffset(word num) {
		renderData.indexOffset = num;
	}
	
	void minIndex(uword num) {
		renderData.minIndex = num;
	}
	
	void maxIndex(uword num) {
		renderData.maxIndex = num;
	}
	
	void topology(MeshTopology t) {
		renderData.topology = t;
	}
	
	// flag querying	
	
	bool worldMatricesDirty() {
		return (_dirtyFlags & DirtyFlags.WorldMatrices) != 0;
	}
	
	// flag clearing
	
	void clearWorldMatricesDirtyFlag() {
		_dirtyFlags &= ~DirtyFlags.WorldMatrices;
	}
	
	// ----
	
	private {
		CoordSys _modelToWorld = CoordSys.identity;

		enum DirtyFlags {
			WorldMatrices	= 0b1
		}

		DirtyFlags	_dirtyFlags;
	}
}
