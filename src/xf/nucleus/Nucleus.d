module xf.nucleus.Nucleus;

private {
	import xf.Common;
	import xf.core.Registry;

	import xf.nucleus.kdef.model.IKDefRegistry;
	import xf.nucleus.Log;

	import xf.gfx.IRenderer : RendererBackend = IRenderer;

	import tango.io.vfs.FileFolder;
	import tango.core.Variant;
}


public {
	import xf.nucleus.Defs;
	import xf.nucleus.Renderer;
	import xf.nucleus.Renderable;
	import xf.nucleus.Light;

	RendererBackend	rendererBackend;
	Renderer		vsmRenderer;
	IKDefRegistry	kdefRegistry;
}

private {
	FileFolder			vfs;

	SurfaceId[cstring]	surfaces;
	cstring[]			surfaceNames;
	SurfaceId			nextSurfaceId;

	MaterialId[cstring]	materials;
	cstring[]			materialNames;
	MaterialId			nextMaterialId;
}


MaterialId getMaterialIdByName(cstring name) {
	return materials[name];
}


SurfaceId getSurfaceIdByName(cstring name) {
	return surfaces[name];
}


void initializeNucleus(RendererBackend bk, cstring[] kdefPaths ...) {
	rendererBackend = bk;

	vfs = new FileFolder(".");

	kdefRegistry = create!(IKDefRegistry)();
	kdefRegistry.setVFS(vfs);
	foreach (p; kdefPaths) {
		kdefRegistry.registerFolder(p);
	}
	kdefRegistry.reload();
	kdefRegistry.dumpInfo();

	// ----

	foreach (surfName, surf; &kdefRegistry.surfaces) {
		surf.id = nextSurfaceId++;
		surf.reflKernel = kdefRegistry.getKernel(surf.reflKernelName);
		surfaces[surfName.dup] = surf.id;
		assert (surf.id == surfaceNames.length);
		surfaceNames ~= surfName;
	}

	foreach (matName, mat; &kdefRegistry.materials) {
		mat.id = nextMaterialId++;
		mat.materialKernel = kdefRegistry.getKernel(mat.materialKernelName);
		materials[matName.dup] = mat.id;
		assert (mat.id == materialNames.length);
		materialNames ~= matName;
	}

	// ----

	vsmRenderer = createRenderer("Depth");
	vsmRenderer.setParam("outKernel", Variant("VarianceDepthRendererOut"));
}


Renderer createRenderer(cstring name) {
	if (!(name in _rendererFactories)) {
		nucleusError("Unknown renderer: '{}'.", name);
	}
	
	final res = _rendererFactories[name]();
	kdefRegistry.registerObserver(res);
	registerLightObserver(res);

	foreach (surfName, surf; &kdefRegistry.surfaces) {
		res.registerSurface(surf);
	}

	foreach (matName, mat; &kdefRegistry.materials) {
		res.registerMaterial(mat);
	}
	return res;
}


void registerRenderer(T)(cstring name) {
	_rendererFactories[name] = function Renderer() {
		return new T(.rendererBackend, kdefRegistry);
	};
}

// TODO: registration


private {
	Renderer function()[cstring]	_rendererFactories;
}
