module xf.gfx.RenderList;

private {
	import xf.Common;
	import
		xf.omg.core.LinearAlgebra,
		xf.omg.core.CoordSys;
	import
		xf.mem.Array,
		xf.mem.MultiArray,
		xf.mem.StackBuffer,
		xf.utils.LocalArray;
	import
		xf.gfx.Effect,
		xf.gfx.IndexBuffer;
	static import tango.core.Array;
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


struct RenderableData {
	CoordSys		coordSys;
	IndexBuffer		indexBuffer;
	uword			numInstances = 1;
	uword			numIndices	= 0;
	word			indexOffset	= 0;
	uword			minIndex	= 0;
	uword			maxIndex	= uword.max;
	MeshTopology	topology = MeshTopology.Triangles;
}


struct RenderBin {
	mixin(multiArray(`objects`, `
		u32				eiRenderOrdinal
		RenderableData	renderable
		mat34			modelToWorld
		mat34			worldToModel
	`));
	
	
	void sort() {
		if (0 == objects.length) {
			return;
		}
		
		scope stackBuffer = new StackBuffer();
		auto perm = LocalArray!(u32)(objects.length, stackBuffer);
		scope (success) perm.dispose();
		foreach (i, ref x; perm.data) {
			x = i;
		}
		
		tango.core.Array.sort(perm.data, (u32 a, u32 b) {
			final v1 = objects.eiRenderOrdinal[a];
			final v2 = objects.eiRenderOrdinal[b];
			return v2 > v1;
		});
		
		//log.trace("ord: {}", objects.eiRenderOrdinal[0..objects.length]);
		//log.trace("perm: {}", perm.data);
		
		auto rd2 = LocalArray!(RenderableData)(objects.length, stackBuffer);
		scope (success) rd2.dispose();
		
		auto o2 = LocalArray!(u32)(objects.length, stackBuffer);
		scope (success) o2.dispose();

		foreach (i, x; perm.data) {
			rd2.data[i] = objects.renderable[x];
			o2.data[i] = objects.eiRenderOrdinal[x];
		}
		objects.renderable[0..objects.length] = rd2.data[0..objects.length];
		objects.eiRenderOrdinal[0..objects.length] = o2.data[0..objects.length];
	}
	
	void computeMatrices() {
		uword end = objects.length;
		final obj = objects;
		for (uword i = 0; i < end; ++i) {
			CoordSys cs = obj.renderable[i].coordSys;
			obj.modelToWorld[i] = cs.toMatrix34;
			cs.invert();
			obj.worldToModel[i] = cs.toMatrix34;
		}
	}
	
	RenderableData* add(EffectInstance e) {
		final idx = objects.growBy(1);
		objects.eiRenderOrdinal[idx] = e.renderOrdinal;
		return &objects.renderable[idx];
	}
	
	void clear() {
		objects.resize(0);
	}
}


// TODO: should be allocated and disposed via the renderer
struct RenderList {
	Array!(RenderBin) bins;
	
	void computeMatrices() {
		foreach (ref b; bins) {
			b.computeMatrices();
		}
	}
	
	RenderBin* getBin(Effect e) {
		assert (e !is null);

		final ro = e.renderOrdinal;
		
		if (ro >= bins.length) {
			error(
				"Invalid effect ordinal. Make sure to allocate render lists using"
				" Renderer.createRenderList before rendering each frame."
				" Also make sure not to create new effects in the middle"
				" of the rendering process"
			);
		}

		return bins[ro];
	}
	
	void clear() {
		foreach (ref b; bins) {
			b.clear();
		}
	}
	
	void sort() {
		foreach (ref b; bins) {
			b.sort();
		}
	}
}
