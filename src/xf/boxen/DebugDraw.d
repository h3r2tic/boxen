module xf.boxen.DebugDraw;

private {
	import Primitives = xf.gfx.misc.Primitives;
	import
		xf.gfx.IRenderer,
		xf.gfx.VertexBuffer,
		xf.gfx.IndexBuffer,
		xf.gfx.Mesh,
		xf.gfx.Window,
		xf.gfx.Effect;
	import EffectHelper = xf.gfx.EffectHelper;
	import
		xf.omg.core.LinearAlgebra;
	import
		xf.utils.Memory;
}



enum Prim {
	Box = 0,
	Cylinder = 1
}


// TODO: needs to be released somewhere
Mesh* create(Prim pt) {
	final efInst = renderer.instantiateEffect(effect);
	EffectHelper.allocateDefaultUniformStorage(efInst);
	EffectHelper.allocateDefaultVaryingStorage(efInst);

	with (*efInst.getVaryingParamData("VertexProgram.input.position")) {
		*buffer = vb[pt];
		*attrib = VertexAttrib(
			Vertex.init.p.offsetof,
			Vertex.sizeof,
			VertexAttrib.Type.Vec3
		);
	}
	
	with (*efInst.getVaryingParamData("VertexProgram.input.normal")) {
		*buffer = vb[pt];
		*attrib = VertexAttrib(
			Vertex.init.n.offsetof,
			Vertex.sizeof,
			VertexAttrib.Type.Vec3
		);
	}

	final m = renderer.createMeshes(1).ptr;
	
	m.numIndices = numIndices[pt];
	m.minIndex = minIndex[pt];
	m.maxIndex = maxIndex[pt];
	m.effectInstance = efInst;
	m.indexBuffer = ib[pt];

	return m;
}


void setWorldToView(mat4 m) {
	effect.setUniform("worldToView",
		m
	);
}


void initialize(IRenderer r, Window window) {
	renderer = r;

	effect = renderer.createEffect(
		"basic",
		EffectSource.filePath("basic.cgfx")
	);
	effect.compile();
	EffectHelper.allocateDefaultUniformStorage(effect);
	
	mat4 viewToClip = mat4.perspective(
		60.0f,		// fov
		cast(float)window.width / window.height,	// aspect
		0.5f,		// near
		1000.0f		// far
	);

	effect.setUniform("viewToClip", viewToClip);

	initializeMesh(
		Prim.Box,
		Primitives.Cube.positions,
		Primitives.Cube.normals,
		Primitives.Cube.indices
	);

	initializeMesh(
		Prim.Cylinder,
		Primitives.Cylinder.positions,
		Primitives.Cylinder.normals,
		Primitives.Cylinder.indices
	);
}


private {
	Effect			effect;
	VertexBuffer[2]	vb;
	IndexBuffer[2]	ib;
	size_t[2]		numIndices;
	uint[2]			maxIndex;
	uint[2]			minIndex;
	IRenderer		renderer;


	struct Vertex {
		vec3 p;
		vec3 n;
	}

	void initializeMesh(
			Prim pt,
			vec3[] positions,
			vec3[] normals,
			uint[] indices
	) {
		Vertex[] vertices;
		vertices.alloc(positions.length);
		foreach (i, p; positions) {
			vertices[i].p = p;
			vertices[i].n = normals[i];
		}

		vb[pt] = renderer.createVertexBuffer(
			BufferUsage.StaticDraw,
			cast(void[])vertices
		);
		
		vertices.free();
		
		ib[pt] = renderer.createIndexBuffer(
			BufferUsage.StaticDraw,
			indices
		);

		numIndices[pt] = indices.length;
		assert (indices.length > 0 && indices.length % 3 == 0);
		
		uword minIdx = uword.max;
		uword maxIdx = uword.min;
		
		foreach (i; indices) {
			if (i < minIdx) minIdx = i;
			if (i > maxIdx) maxIdx = i;
		}

		maxIndex[pt] = maxIdx;
		minIndex[pt] = minIdx;
	}
}
