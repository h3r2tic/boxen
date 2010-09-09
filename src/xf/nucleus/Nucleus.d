module xf.nucleus.Nucleus;

private {
	import xf.Common;
	import xf.core.Registry;

	import
		xf.nucleus.Param,
		xf.nucleus.Material,
		xf.nucleus.kdef.model.IKDefRegistry,
		xf.nucleus.Log,
		xf.nucleus.asset.CompiledMaterialAsset;

	import xf.gfx.IRenderer : RendererBackend = IRenderer;

	import
		xf.mem.ScratchAllocator,
		xf.mem.MainHeap;

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
	Renderer		smRenderer;
	IKDefRegistry	kdefRegistry;

	Material[]		allMaterials;
	Material[]		assetMaterials;
}

private {
	FileFolder			vfs;

	SurfaceId[cstring]	surfaces;
	cstring[]			surfaceNames;
	SurfaceId			nextSurfaceId;

	Material[cstring]	materials;
	cstring[]			materialNames;
	MaterialId			nextMaterialId;

	Renderer[]			renderers;
}


MaterialId getMaterialIdByName(cstring name) {
	if (auto m = name in materials) {
		return (*m).id;
	} else {
		error("getMaterialIdByName: unknown material: '{}'", name);
		return MaterialId.init;
	}
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

	smRenderer = createRenderer("Depth");
	smRenderer.setParam("outKernel", Variant("DepthRendererOut"));
}


void nucleusHotSwap() {
	if (kdefRegistry.invalidated) {
		kdefRegistry.reload();
		reloadSurfMats();
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

	foreach (mat; allMaterials) {
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


void registerMaterial(Material mat) {
	assert (mat !is null);
	assert (!mat.materialKernel.isValid);
	assert (mat.asset !is null);

	assert (nextMaterialId == materialNames.length);
	
	mat.id = nextMaterialId++;
	mat.materialKernel = kdefRegistry.getKernel(mat.asset.kernelName);
	assert (mat.materialKernel.isValid);
	assert (mat.materialKernel.id.isValid);
	assert (kdefRegistry.getKernel(mat.materialKernel.id).name == mat.asset.kernelName);

	cstring name = mat.asset.name.dup;
	materials[name] = mat;

	materialNames ~= name;
	allMaterials ~= mat;

	foreach (r; renderers) {
		r.registerMaterial(mat);
	}
}


Material loadMaterial(CompiledMaterialAsset asset) {
	if (auto m = asset.name in materials) {
		return *m;
	} else {
		assert (asset !is null);
		final mat = new Material;
		mat.asset = asset;
		registerMaterial(mat);
		assetMaterials ~= mat;
		return mat;
	}
}


private void reloadSurfMats() {
	nextSurfaceId = nextSurfaceId.init;
	nextMaterialId = nextMaterialId.init;

	surfaces = null;
	surfaceNames = null;

	materials = null;
	materialNames = null;

	allMaterials.length = 0;

	foreach (surfName, surf; &kdefRegistry.surfaces) {
		surf.id = nextSurfaceId++;
		surf.reflKernel = kdefRegistry.getKernel(surf.reflKernelName);
		assert (surf.reflKernel.isValid);
		assert (surf.reflKernel.id.isValid);
		assert (kdefRegistry.getKernel(surf.reflKernel.id).name == surf.reflKernelName);
		surfaces[surfName.dup] = surf.id;
		assert (surf.id == surfaceNames.length);
		surfaceNames ~= surfName;

		foreach (r; renderers) {
			r.registerSurface(surf);
		}
	}

	final allocator = DgScratchAllocator(&mainHeap.allocRaw);

	foreach (matName, matDef; &kdefRegistry.materials) {
		final mat = new Material;

		// BUG(?): aliases mem from the kdef

		uword numParams = matDef.params.length;

		final cmat = allocator._new!(CompiledMaterialAsset)();

		cmat.params.length		= numParams;
		cmat.params.name		= allocator.allocArray!(cstring)(numParams).ptr;
		cmat.params.valueType	= allocator.allocArray!(ParamValueType)(numParams).ptr;
		cmat.params.value		= allocator.allocArray!(void*)(numParams).ptr;

		cmat.name = allocator.dupString(matName);
		cmat.kernelName = allocator.dupString(matDef.materialKernelName);

		foreach (i, ref p; matDef.params) {
			cmat.params.name[i] = p.name;
			cmat.params.valueType[i] = p.valueType;
			cmat.params.value[i] = p.value;
		}

		mat.asset = cmat;

		registerMaterial(mat);
	}

	foreach (mat; assetMaterials) {
		cstring name = mat.asset.name.dup;
		materials[name] = mat;

		materialNames ~= name;
		allMaterials ~= mat;

		foreach (r; renderers) {
			r.registerMaterial(mat);
		}
	}
}


// TODO: registration


private {
	Renderer function()[cstring]	_rendererFactories;
}
