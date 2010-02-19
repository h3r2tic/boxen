module xf.gfx.Mesh;

private {
	import xf.Common;
	import
		xf.omg.core.LinearAlgebra,
		xf.omg.core.CoordSys;
	import
		xf.gfx.Effect,
		xf.gfx.IndexBuffer;
}



interface IMeshMngr {
	Mesh[] createMeshes(int num);
	void destroyMeshes(ref Mesh[] meshes);
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

	EffectInstance	effectInstance;
	IndexBuffer		indexBuffer;

	Effect effect() {
		return effectInstance.getEffect;
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
	
	
	EffectInstance effectInstance() {
		return renderData.effectInstance;
	}
	
	void effectInstance(EffectInstance inst) {
		if (renderData.effectInstance.valid) {
			renderData.effectInstance.dispose();
			renderData.effectInstance = EffectInstance.init;
		}
		if (inst.valid && inst.acquire) {
			renderData.effectInstance = inst;
		}
	}
	
	
	Effect effect() {
		return effectInstance.getEffect;
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
