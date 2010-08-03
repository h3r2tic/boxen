module xf.nucleus.asset.compiler.MeshCompiler;

private {
	import xf.Common;
	import xf.nucleus.asset.CompiledMeshAsset;
	import xf.gfx.VertexBuffer : VertexAttrib;
	import xf.loader.scene.model.Mesh : LoaderMesh = Mesh;
	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.CoordSys;
	import xf.omg.core.Misc;
	import xf.mem.ScratchAllocator;
}


// TODO: rename LoaderMesh to MeshAsset (?)
// TODO: put this in the asset conditioning pipeline
CompiledMeshAsset compileMeshAsset(
	LoaderMesh assetMesh,
	DgScratchAllocator allocator,
	MeshAssetCompilationOptions opts = MeshAssetCompilationOptions.init
) {
	struct Vertex {
		vec3 pos;
		vec3 norm;
		vec3 tangent;
		vec3 bitangent;
		vec2 tc;
	}

	final cmesh = allocator._new!(CompiledMeshAsset)();

	final vertices = allocator.allocArrayNoInit
		!(Vertex)(assetMesh.positions.length);
	
	cmesh.vertexAttribs = allocator.allocArrayNoInit
		!(CompiledMeshVertexAttrib)(Vertex.tupleof.length);

	with (cmesh.vertexAttribs[0]) {
		name = "position";
		attrib = VertexAttrib(
			Vertex.init.pos.offsetof,
			Vertex.sizeof,
			VertexAttrib.Type.Vec3
		);
	}

	with (cmesh.vertexAttribs[1]) {
		name = "normal";
		attrib = VertexAttrib(
			Vertex.init.norm.offsetof,
			Vertex.sizeof,
			VertexAttrib.Type.Vec3
		);
	}

	with (cmesh.vertexAttribs[2]) {
		name = "tangent";
		attrib = VertexAttrib(
			Vertex.init.tangent.offsetof,
			Vertex.sizeof,
			VertexAttrib.Type.Vec3
		);
	}

	with (cmesh.vertexAttribs[3]) {
		name = "bitangent";
		attrib = VertexAttrib(
			Vertex.init.bitangent.offsetof,
			Vertex.sizeof,
			VertexAttrib.Type.Vec3
		);
	}

	with (cmesh.vertexAttribs[4]) {
		name = "texCoord";
		attrib = VertexAttrib(
			Vertex.init.tc.offsetof,
			Vertex.sizeof,
			VertexAttrib.Type.Vec2
		);
	}

	final node = assetMesh.node;
	
	foreach (i, ref v; vertices) {
		v.pos	= assetMesh.positions[i];
		v.pos	*= opts.scale;
		assert (v.pos.ok);

		cmesh.halfSize.x = max(cmesh.halfSize.x, abs(v.pos.x));
		cmesh.halfSize.y = max(cmesh.halfSize.y, abs(v.pos.y));
		cmesh.halfSize.z = max(cmesh.halfSize.z, abs(v.pos.z));
		
		v.norm	= assetMesh.normals[i];
		
		if (assetMesh.tangents.length) {
			final tangent = assetMesh.tangents[i];
			if (tangent.x <>= 0 && tangent.y <>= 0 && tangent.z <>= 0) {
				v.tangent = vec3.from(tangent);
			} else {
				v.tangent = vec3.unitX;
			}
		} else {
			v.tangent = vec3.unitX;
		}

		if (assetMesh.bitangents.length) {
			final bitangent = assetMesh.bitangents[i];
			if (bitangent.x <>= 0 && bitangent.y <>= 0 && bitangent.z <>= 0) {
				v.bitangent = vec3.from(bitangent);
			} else {
				v.bitangent = vec3.unitZ;
			}
		} else {
			v.bitangent = vec3.unitZ;
		}

		const int ch = 0;
		
		if (assetMesh.numTexCoordSets > ch) {
			v.tc = vec2.from(assetMesh.texCoords(ch).coords[i]);
		} else {
			v.tc = vec2.zero;
		}
	}

	cmesh.vertexData = cast(void[])vertices;

	cmesh.numIndices = assetMesh.indices.length;
	// assert (indices.length > 0 && indices.length % 3 == 0);
	
	uword minIdx = uword.max;
	uword maxIdx = uword.min;
	
	foreach (i; assetMesh.indices) {
		if (i < minIdx) minIdx = i;
		if (i > maxIdx) maxIdx = i;
	}

	cmesh.minIndex = minIdx;
	cmesh.maxIndex = maxIdx;

	cmesh.indices = allocator.allocArrayNoInit!(u32)(assetMesh.indices.length);
	cmesh.indices[] = assetMesh.indices;

	return cmesh;
}
