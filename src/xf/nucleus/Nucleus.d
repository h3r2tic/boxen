module xf.nucleus.Nucleus;

private {
	import xf.Common;
	import xf.core.Registry;

	import xf.nucleus.kdef.model.IKDefRegistry;
	import xf.nucleus.Log;

	import xf.gfx.IRenderer : RendererBackend = IRenderer;

	import tango.io.vfs.FileFolder;
	import tango.core.Variant;

	import tango.text.convert.Format;
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

	Renderer[]			renderers;
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

	foreach (ki; &kdefRegistry.kernelImpls) {
		assert (ki.id == kdefRegistry.getKernel(ki.id).id);
		assert (
			ki.name == kdefRegistry.getKernel(ki.id).name,
			Format("POOP! '{}' vs '{}' id={}", ki.name, kdefRegistry.getKernel(ki.id).name, ki.id.value)
		);
	}

	reloadSurfMats();

	vsmRenderer = createRenderer("Depth");
	vsmRenderer.setParam("outKernel", Variant("VarianceDepthRendererOut"));
}


void nucleusHotSwap() {
	if (kdefRegistry.invalidated) {
		kdefRegistry.reload();
		
		reloadSurfMats();

		foreach (r; renderers) {
			foreach (surfName, surf; &kdefRegistry.surfaces) {
				r.registerSurface(surf);
			}

			foreach (matName, mat; &kdefRegistry.materials) {
				r.registerMaterial(mat);
			}
		}
	}
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

	renderers ~= res;

	return res;
}


void registerRenderer(T)(cstring name) {
	_rendererFactories[name] = function Renderer() {
		return new T(.rendererBackend, kdefRegistry);
	};
}


private void reloadSurfMats() {
	nextSurfaceId = nextSurfaceId.init;
	nextMaterialId = nextMaterialId.init;

	surfaces = null;
	surfaceNames = null;

	materials = null;
	materialNames = null;

	foreach (surfName, surf; &kdefRegistry.surfaces) {
		surf.id = nextSurfaceId++;
		surf.reflKernel = kdefRegistry.getKernel(surf.reflKernelName);
		assert (surf.reflKernel.isValid);
		assert (surf.reflKernel.id.isValid);
		assert (kdefRegistry.getKernel(surf.reflKernel.id).name == surf.reflKernelName);
		surfaces[surfName.dup] = surf.id;
		assert (surf.id == surfaceNames.length);
		surfaceNames ~= surfName;
	}

	foreach (matName, mat; &kdefRegistry.materials) {
		mat.id = nextMaterialId++;
		mat.materialKernel = kdefRegistry.getKernel(mat.materialKernelName);
		assert (mat.materialKernel.isValid);
		assert (mat.materialKernel.id.isValid);
		assert (kdefRegistry.getKernel(mat.materialKernel.id).name == mat.materialKernelName);
		materials[matName.dup] = mat.id;
		assert (mat.id == materialNames.length);
		materialNames ~= matName;
	}
}


// TODO: registration


private {
	Renderer function()[cstring]	_rendererFactories;
}
