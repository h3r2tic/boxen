module xf.nucleus.structure.PointCloud;

private {
	import xf.Common;

	import xf.nucleus.IStructureData;
	import xf.nucleus.KernelParamInterface;

	import xf.gfx.IRenderer : IRenderer;
	import xf.gfx.Buffer;
	import xf.gfx.VertexBuffer;
	import xf.gfx.IndexBuffer;
	import xf.gfx.IndexData;
	import xf.gfx.Log;

	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.Misc;

	static import xf.utils.Memory;

	import tango.math.random.Kiss;
}



// TODO: better mem
class PointCloud : IStructureData {
	this (word numPts, vec3 extent, IRenderer renderer) {
		Kiss rand;

		float frand() {
			return (1.0 / uint.max) * rand.toInt;
		}
		vec3 vrand0() {
			float phi	= frand() * 2 * pi;
			float u		= (frand() - .5f) * 2.f;
			float u2	= u*u;
			float rt	= sqrt(1.f - u2);
			
			return vec3(rt * cos(phi), u, rt * sin(phi));
		}
		vec3 volume_vrand() {
			return vrand0() * (cbrt(frand()));
		}


		vec3[] pts;
		xf.utils.Memory.alloc(pts, numPts);
		scope (exit) xf.utils.Memory.free(pts);

		foreach (ref p; pts) {
			p = volume_vrand() * extent;
		}
		
		vertexBuffer = renderer.createVertexBuffer(
			BufferUsage.StaticDraw,
			pts
		);

		posAttrib = VertexAttrib(
			0,
			vec3.sizeof,
			VertexAttrib.Type.Vec3
		);

		indexData.numIndices = numPts;
		indexData.topology = MeshTopology.Points;
		indexData.useIndexBuffer = false;
	}

	cstring structureTypeName() {
		return "PointCloud";
	}

	void setKernelObjectData(KernelParamInterface kpi) {
		kpi.setIndexData(&indexData);
		
		final param = kpi.getVaryingParam("position");
		if (param !is null) {
			param.buffer = &vertexBuffer;
			param.attrib = &posAttrib;
		} else {
			gfxError("No param named 'position' in the kernel.");
		}
	}

	// TODO: hardcode the available data and expose meta-info

	private {
		VertexBuffer	vertexBuffer;
		VertexAttrib	posAttrib;
		IndexData		indexData;
	}
}
