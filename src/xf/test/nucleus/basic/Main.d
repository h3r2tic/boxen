module Main;

private {
	import xf.Common;
	import xf.core.Registry;
	
	import Nucleus = xf.nucleus.Nucleus;
	import xf.nucleus.Defs;
	import xf.nucleus.Renderer;
	import xf.nucleus.Renderable;
	import xf.nucleus.IStructureData;
	import xf.nucleus.Kernel;
	import xf.nucleus.CompiledMeshAsset;
	import xf.nucleus.KernelParamInterface;

	import xf.gfx.IRenderer : IRenderer;
	import xf.gfx.Buffer;
	import xf.gfx.VertexBuffer;
	import xf.gfx.IndexBuffer;
	import xf.gfx.IndexData;

	import xf.vsd.VSD;

	import xf.loader.scene.model.Mesh : LoaderMesh = Mesh;

	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.CoordSys;

	static import xf.utils.Memory;
}




// TODO: better mem
class MeshStructure : IStructureData {
	this (CompiledMeshAsset ma, IRenderer renderer) {
		auto vb = renderer.createVertexBuffer(
			BufferUsage.StaticDraw,
			ma.vertexData
		);

		xf.utils.Memory.alloc(vertexAttribs, ma.vertexAttribs.length);
		xf.utils.Memory.alloc(vertexAttribNames, ma.vertexAttribs.length);

		foreach (i, ref va; vertexAttribs) {
			va = ma.vertexAttribs[i].attrib;
		}

		size_t totalNameLen = 0;
		foreach (a; ma.vertexAttribs) {
			totalNameLen += a.name.length;
		}

		char[] nameBuf;
		xf.utils.Memory.alloc(nameBuf, totalNameLen);

		foreach (i, a; ma.vertexAttribs) {
			vertexAttribNames[i] = nameBuf[0..a.name.length];
			vertexAttribNames[i][] = a.name;
			nameBuf = nameBuf[a.name.length..$];
		}
		
		assert (0 == nameBuf.length);

		indexData.indexBuffer = renderer.createIndexBuffer(
			BufferUsage.StaticDraw,
			ma.indices
		);
		indexData.numIndices	= ma.numIndices;
		indexData.indexOffset	= ma.indexOffset;
		indexData.minIndex		= ma.minIndex;
		indexData.maxIndex		= ma.maxIndex;
	}

	cstring structureTypeName() {
		return "Mesh";
	}

	void applyToKernelParams(KernelParamInterface kdi) {
		kdi.setIndexData(&indexData);
		
		foreach (i, ref attr; vertexAttribs) {
			final name = vertexAttribNames[i];
			final param = kdi.getVaryingParam(name);
			param.buffer = &vertexBuffer;
			param.attrib = &attr;
		}
	}

	// TODO: hardcode the available data and expose meta-info

	private {
		VertexBuffer	vertexBuffer;

		// allocated with xf.utils.Memory
		VertexAttrib[]	vertexAttribs;
		cstring[]		vertexAttribNames;

		IndexData		indexData;
	}
}



Kernel defaultMeshStructureKernel;
static this() {
	defaultMeshStructureKernel.name = "DefaultMeshStructure";
}


Kernel* defaultStructureKernel(cstring structureTypeName) {
	switch (structureTypeName) {
		case "Mesh": return &defaultMeshStructureKernel;
		default: assert (false, structureTypeName);
	}
}



void doStuff() {
	final rendererBackend = create!(IRenderer)();
	final nr = Nucleus.createRenderer("Forward", rendererBackend);


	// TODO: configure the VSD spatial subdivision
	final vsd = VSDRoot();

	// Connect renderable creation to VSD object creation
	registerRenderableObserver(new class IRenderableObserver {
		void onRenderableCreated(RenderableId id) {
			vsd.createObject(id);
		}
		
		void onRenderableDisposed(RenderableId id) {
			vsd.disposeObject(id);
		}
		
		void onRenderableInvalidated(RenderableId id) {
			vsd.invalidateObject(id);
		}
	});


	// ----

	// This should be a part of the content pipeline
	LoaderMesh m;// = loadSomeMesh();
	// ----

	final compiledMesh = compileMeshAsset(m);
	final ms = new MeshStructure(compiledMesh, rendererBackend);

	final rid = createRenderable();	
	renderables.structureKernel[rid] = defaultStructureKernel(ms.structureTypeName);
	renderables.structureData[rid] = ms;
	renderables.surfaceKernel[rid] = null;	// TODO
	renderables.surfaceData[rid] = null;
	renderables.transform[rid] = CoordSys.identity;

	while (true) {
		// move some objects

		// The transforms array for the VSD must be updated as it may have been
		// resized and VSD now holds the old reference
		vsd.transforms = renderables.transform[0..renderables.length];
		
		// update vsd.localHalfSizes
		// update vsd.enabledFlags
		// update vsd.invalidationFlags
		vsd.enableObject(rid);
		vsd.invalidateObject(rid);
		vsd.update();

		final rlist = nr.createRenderList();
		scope (exit) nr.disposeRenderList(rlist);

		final viewSettings = ViewSettings();		// TODO

		vsd.findVisible(viewSettings, (VisibleObject[] olist) {
			foreach (o; olist) {
				final bin = rlist.add();
				static assert (RenderableId.sizeof == typeof(o.id).sizeof);
				rlist.list.renderableId[bin] = cast(RenderableId)o.id;
				rlist.list.coordSys[bin] = renderables.transform[o.id];
			}
		});

		rendererBackend.resetStats();
		rendererBackend.framebuffer.settings.clearColorValue[0] = vec4.one * 0.1f;
		rendererBackend.clearBuffers();

		nr.render(rlist);
	}
}


void main() {
}
