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
		xf.mem.MainHeap,
		MemUtils = xf.utils.Memory;
}



struct MaterialData {
	struct Info {
		cstring	name;		// not owned here
		word	offset;
	}
	
	Info[]	info;
	void*	data;
}



void createMaterialData(RendererBackend backend, ParamList params, MaterialData* mat) {
	MemUtils.alloc(mat.info, params.length);

	uword sizeReq = 0;
	
	foreach (i, p; params) {
		uword psize = p.valueSize;

		switch (p.valueType) {
			case ParamValueType.ObjectRef: {
				Object objVal;
				p.getValue(&objVal);
				if (auto sampler = cast(SamplerDef)objVal) {
					psize = Texture.sizeof;
				} else {
					error(
						"Forward renderer: Don't know what to do with"
						" a {} material param ('{}').",
						objVal.classinfo.name,
						p.name
					);
				}
			} break;

			case ParamValueType.String:
			case ParamValueType.Ident: {
				error(
					"Forward renderer: Don't know what to do with"
					" string/ident material params ('{}').",
					p.name
				);
			} break;

			default: break;
		}

		assert (psize != 0);
		
		// TODO: get clear ownership rules here
		mat.info[i].name = cast(cstring)p.name;
		mat.info[i].offset = sizeReq;
		sizeReq += psize;
		sizeReq += (uword.sizeof - 1);
		sizeReq &= ~(uword.sizeof - 1);
	}

	mat.data = mainHeap.allocRaw(sizeReq);
	memset(mat.data, 0, sizeReq);

	foreach (i, p; params) {
		void* dst = mat.data + mat.info[i].offset;
		assert (dst < mat.data + sizeReq);
		
		switch (p.valueType) {
			case ParamValueType.ObjectRef: {
				Object objVal;
				p.getValue(&objVal);
				if (auto sampler = cast(SamplerDef)objVal) {
					// TODO: proper handling of sampler objects and textures,
					// separately, using the new GL 3.3 extension
					Texture* tex = cast(Texture*)dst;
					loadMaterialSamplerParam(backend, sampler, tex);
				} else {
					error(
						"Renderer: Don't know what to do with"
						" a {} material param ('{}').",
						objVal.classinfo.name,
						p.name
					);
				}
			} break;

			case ParamValueType.String:
			case ParamValueType.Ident: {
				error(
					"Renderer: Don't know what to do with"
					" string/ident material params ('{}').",
					p.name
				);
			} break;

			default: {
				memcpy(dst, p.value, p.valueSize);
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
