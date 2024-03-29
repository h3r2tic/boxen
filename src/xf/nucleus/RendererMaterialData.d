module xf.nucleus.RendererMaterialData;

private {
	import xf.Common;
	import
		xf.nucleus.Defs,
		xf.nucleus.Param,
		xf.nucleus.Material,
		xf.nucleus.MaterialDef,
		xf.nucleus.SamplerDef,
		xf.nucleus.util.SamplerLoading,
		xf.nucleus.asset.CompiledTextureAsset;
	import
		xf.loader.Common,
		xf.loader.img.ImgLoader,
		xf.img.Image;
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
		cstring	name;		// stringz
		void*	ptr;
	}

	void dispose() {
		_mem.dispose();
		info = null;
	}
	
	Info[]				info;
	ParamValueType[]	types;
	ScratchFIFO			_mem;
}



void createMaterialData(RendererBackend backend, Material matDef, MaterialData* mat) {
	mat._mem.initialize();
	final mem = DgScratchAllocator(&mat._mem.pushBack);

	final ass = matDef.asset;
	assert (ass !is null);

	mat.info = mem.allocArray!(MaterialData.Info)(ass.params.length);
	mat.types = mem.allocArray!(ParamValueType)(ass.params.length);

	for (uword i = 0; i < ass.params.length; ++i) {
		switch (ass.params.valueType[i]) {
			case ParamValueType.ObjectRef: {
				Object objVal = cast(Object)ass.params.value[i];
				if (auto sampler = cast(SamplerDef)objVal) {
					mat.info[i].ptr = mem._new!(Texture)();
					Texture* tex = cast(Texture*)mat.info[i].ptr;
					loadMaterialSamplerParam(backend, sampler, tex);
				} else if (auto sampler = cast(CompiledTextureAsset)objVal) {
					mat.info[i].ptr = mem._new!(Texture)();
					Texture* tex = cast(Texture*)mat.info[i].ptr;
					loadMaterialSamplerParam(backend, sampler, tex);
				} else {
					error(
						"Don't know what to do with"
						" a {} material param ('{}').",
						objVal.classinfo.name,
						ass.params.name[i]
					);
				}
			} break;

			case ParamValueType.String:
			case ParamValueType.Ident: {
				error(
					"Don't know what to do with"
					" string/ident material params ('{}').",
					ass.params.name[i]
				);
			} break;

			default: {
				/+log.trace("Handling '{}'.", ass.params.name[i]);
				log.trace("Type: '{}'.", cast(int)ass.params.valueType[i]);
				log.trace("Value: '{}'.", ass.params.value[i]);+/

				void* value = ass.params.value[i];
				ParamValueType valueType = ass.params.valueType[i];

				uword valueSize;
				
				if (value) {
					switch (valueType) {
						case ParamValueType.Float:	valueSize = 4; break;
						case ParamValueType.Float2: valueSize = 8; break;
						case ParamValueType.Float3: valueSize = 12; break;
						case ParamValueType.Float4: valueSize = 16; break;
						default: assert (false);
					}
				}

				// WTF, this segfaults at total bullshit :<
				/+uword valueSize = paramValueSize(
					ass.params.valueType[i],
					ass.params.value[i]
				);+/

				//log.trace("Memcpy w/ size {}.", valueSize);
				
				// TODO: figure out whether that alignment is needed at all
				memcpy(
					mat.info[i].ptr = mem.alignedAllocRaw(valueSize, uword.sizeof),
					ass.params.value[i],
					valueSize
				);

				//log.trace("Memcpied.");
			} break;
		}

		mat.info[i].name = mem.dupStringz(cast(cstring)ass.params.name[i]);
		mat.types[i] = ass.params.valueType[i];
	}
}


void updateMaterialData(RendererBackend backend, Material matDef, MaterialData* mat) {
	final ass = matDef.asset;
	
	for (uword i = 0; i < ass.params.length; ++i) {
		assert (mat.info[i].name == ass.params.name[i]);
		assert (mat.types[i] == ass.params.valueType[i]);
		
		switch (ass.params.valueType[i]) {
			case ParamValueType.ObjectRef: {
				// TODO
			} break;

			case ParamValueType.String:
			case ParamValueType.Ident: {
				error(
					"Don't know what to do with"
					" string/ident material params ('{}').",
					ass.params.name[i]
				);
			} break;

			default: {
				uword valueSize = paramValueSize(ass.params.valueType[i], ass.params.value);
				
				// TODO: figure out whether that alignment is needed at all
				memcpy(
					mat.info[i].ptr,
					ass.params.value[i],
					valueSize
				);
			} break;
		}
	}
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
