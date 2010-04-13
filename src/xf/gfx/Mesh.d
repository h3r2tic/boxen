module xf.gfx.Mesh;

private {
	import xf.Common;
	import
		xf.omg.core.LinearAlgebra,
		xf.omg.core.CoordSys;
	import
		xf.gfx.Effect,
		xf.gfx.IndexBuffer,
		xf.gfx.IndexData,
		xf.gfx.RenderList;
}



interface IMeshMngr {
	Mesh[] createMeshes(int num);
	void destroyMeshes(ref Mesh[] meshes);
}



struct Mesh {
	CoordSys		coordSys = CoordSys.identity;
	EffectInstance	effectInstance;
	IndexData		indexData;
	

	Effect effect() {
		return effectInstance.getEffect;
	}
	
	
	IndexBuffer indexBuffer(IndexBuffer buf) {
		if (buf.valid && buf.acquire) {
			if (indexData.indexBuffer.valid) {
				indexData.indexBuffer.dispose();
			}

			indexData.indexBuffer = buf;
		} else {
			if (indexData.indexBuffer.valid) {
				indexData.indexBuffer.dispose();
			}
		}

		return indexData.indexBuffer;
	}
	
	
	IndexBuffer indexBuffer() {
		return indexData.indexBuffer;
	}
	
	
	void toRenderableData(RenderableData* rd) {
		rd.coordSys = coordSys;
		rd.scale = vec3.one;
		rd.indexData = indexData;
		rd.numInstances = 1;
	}
}
