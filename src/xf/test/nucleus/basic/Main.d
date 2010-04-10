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

	import xf.gfx.IRenderer : IRenderer;

	import xf.vsd.VSD;

	import xf.loader.scene.model.Mesh : LoaderMesh = Mesh;

	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.CoordSys;
}









class MeshStructure : IStructureData {
	this (IRenderer) {
		// TODO
	}

	cstring structureTypeName() {
		return "Mesh";
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


// TODO: make LoaderMesh implement IMeshAsset
// with such a setup, any IMeshAsset will be a potential input into a MeshStructure
// thus forming a bridge between loading mesh data from files and bindindg them to
// shaders
// Similarly, other content pipeline entities can be .*Asset, similarly to
// XNA's .*Content


MeshStructure createMeshStructure(LoaderMesh loaderMesh, IRenderer r) {
	assert (false, "TODO");
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

	final ms = createMeshStructure(m, rendererBackend);

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
