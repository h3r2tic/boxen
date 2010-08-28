module xf.nucleus.RendererMaterialData;

private {
	import xf.Common;
	import
		xf.nucleus.Defs,
		xf.nucleus.Param,
		xf.nucleus.MaterialDef,
		xf.nucleus.SamplerDef;
	import
		xf.loader.Common,
		xf.loader.img.ImgLoader;
	import
		xf.gfx.Texture,
		xf.gfx.IRenderer : RendererBackend = IRenderer;
	import
		xf.mem.ChunkQueue,
		xf.mem.ScratchAllocator;
}



// all mem allocated off the scratch fifo
struct MaterialData {
	struct Info {
		// TODO: store the type to be safe in value updates
		cstring	name;		// stringz
		void*	ptr;
	}

	void dispose() {
		_mem.dispose();
		info = null;
	}
	
	Info[]		info;
	ScratchFIFO	_mem;
}



void createMaterialData(RendererBackend backend, ParamList params, MaterialData* mat) {
	mat._mem.initialize();
	final mem = DgScratchAllocator(&mat._mem.pushBack);

	mat.info = mem.allocArray!(MaterialData.Info)(params.length);
	
	foreach (i, p; params) {
		switch (p.valueType) {
			case ParamValueType.ObjectRef: {
				Object objVal;
				p.getValue(&objVal);
				if (auto sampler = cast(SamplerDef)objVal) {
					mat.info[i].ptr = mem._new!(Texture)();
					Texture* tex = cast(Texture*)mat.info[i].ptr;
					loadMaterialSamplerParam(backend, sampler, tex);
				} else {
					error(
						"Don't know what to do with"
						" a {} material param ('{}').",
						objVal.classinfo.name,
						p.name
					);
				}
			} break;

			case ParamValueType.String:
			case ParamValueType.Ident: {
				error(
					"Don't know what to do with"
					" string/ident material params ('{}').",
					p.name
				);
			} break;

			default: {
				// TODO: figure out whether that alignment is needed at all
				memcpy(
					mat.info[i].ptr = mem.alignedAllocRaw(p.valueSize, uword.sizeof),
					p.value,
					p.valueSize
				);
			} break;
		}

		mat.info[i].name = mem.dupStringz(cast(cstring)p.name);
	}
}


void updateMaterialData(RendererBackend backend, ParamList params, MaterialData* mat) {
	foreach (i, p; params) {
		assert (mat.info[i].name == cast(cstring)p.name);
		
		switch (p.valueType) {
			case ParamValueType.ObjectRef: {
				// TODO
			} break;

			case ParamValueType.String:
			case ParamValueType.Ident: {
				error(
					"Don't know what to do with"
					" string/ident material params ('{}').",
					p.name
				);
			} break;

			default: {
				// TODO: figure out whether that alignment is needed at all
				memcpy(
					mat.info[i].ptr,
					p.value,
					p.valueSize
				);
			} break;
		}
	}
}


private void loadMaterialSamplerParam(
	RendererBackend backend,
	SamplerDef sampler,
	Texture* tex
) {
	if (auto val = sampler.params.get("texture")) {
		cstring filePath;
		val.getValue(&filePath);

		final img = imgLoader.load(getResourcePath(filePath));
		if (!img.valid) {
			// TODO: fallback
			error("Could not load texture: '{}'", filePath);
		}

		*tex = backend.createTexture(
			img
		);
	} else {
		assert (false, "TODO: use a fallback texture");
	}
}
