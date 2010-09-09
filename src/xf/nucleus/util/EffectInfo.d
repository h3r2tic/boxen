module xf.nucleus.util.EffectInfo;

private {
	import
		xf.Common,
		xf.nucleus.SamplerDef,
		xf.gfx.Texture,
//		xf.nucleus.Param,
		xf.utils.FormatTmp,
		xf.mem.MainHeap,
		xf.mem.ScratchAllocator,
		xf.mem.ChunkQueue,
		xf.gfx.IRenderer : RendererBackend = IRenderer;

	import xf.nucleus.Log : error = nucleusError, log = nucleusLog;

	import
		xf.loader.Common,
		xf.loader.img.ImgLoader,
		xf.img.Image;

	import
		xf.nucleus.Param,
		xf.nucleus.graph.KernelGraph;

	static import
		xf.nucleus.codegen.Rename;

	import
		xf.gfx.Effect;
}



// TODO: mem
struct EffectInfo {
	struct UniformDefaults {
		char[]	name;		// zero-terminated
		void[]	value;
	}

	UniformDefaults[]	uniformDefaults;
	Effect				effect;
	ScratchFIFO			_mem;


	// NOTE: doesn't actually dispose the effect, only the info
	void dispose() {
		//mainHeap.freeRaw(uniformDefaults.ptr);
		_mem.dispose();
		uniformDefaults = null;
		effect = null;
	}

	bool isValid() {
		return effect !is null;
	}
}


void findEffectInfo(RendererBackend backend, KernelGraph kg, EffectInfo* effectInfo) {
	assert (effectInfo !is null);

	effectInfo._mem.initialize();
	final mem = DgScratchAllocator(&effectInfo._mem.pushBack);

	void iterDataParams(void delegate(cstring name, Param* param) sink) {
		foreach (nid; kg.iterNodes) {
			final node = kg.getNode(nid);
			if (KernelGraph.NodeType.Data != node.type) {
				continue;
			}
			final pnode = node.data();

			foreach (ref p; pnode.params) {
				if (p.value) {
					formatTmp((Fmt fmt) {
						xf.nucleus.codegen.Rename.renameDataNodeParam(
							fmt,
							pnode,
							p.name
						);
					},
					(cstring s) {
						sink(s, &p);
					});
				}
			}
		}
	}

	uword numParams = 0;
	//uword sizeReq = 0;

	iterDataParams((cstring name, Param* p) {
		/+sizeReq += name.length+1;	// stringz
		sizeReq += p.valueSize;
		sizeReq += EffectInfo.UniformDefaults.sizeof;+/
		++numParams;
	});

	effectInfo.uniformDefaults = mem.allocArray!(EffectInfo.UniformDefaults)(numParams);

	numParams = 0;
	iterDataParams((cstring name, Param* p) {
		final ud = &effectInfo.uniformDefaults[numParams];
		assert (p.valueType != ParamValueType.String, "TODO");
		ud.name = mem.dupStringz(name);

		switch (p.valueType) {
			case ParamValueType.ObjectRef: {
				Object objVal;
				p.getValue(&objVal);
				if (auto sampler = cast(SamplerDef)objVal) {
					final tex = mem._new!(Texture)();
					//Texture* tex = cast(Texture*)mat.info[i].ptr;
					loadMaterialSamplerParam(backend, sampler, tex);
					ud.value = cast(void[])(tex[0..1]);
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
				ud.value = mem.dupArray(p.value[0..p.valueSize]);
				/+memcpy(
					mat.info[i].ptr = mem.alignedAllocRaw(p.valueSize, uword.sizeof),
					p.value,
					p.valueSize
				);+/
			} break;
		}

		//ud.value = mem.dupArray(param.value[0..param.valueSize]);
		++numParams;
	});
	
	/+final pool = PoolScratchAllocator(mainHeap.allocRaw(sizeReq)[0..sizeReq]);

	// free effectInfo.uniformDefaults.ptr to free the whole thing (I accidentally)
	effectInfo.uniformDefaults = pool.allocArray
		!(EffectInfo.UniformDefaults)(numParams);

	numParams = 0;
	iterDataParams((cstring name, Param* param) {
		final ud = &effectInfo.uniformDefaults[numParams];
		assert (param.valueType != ParamValueType.String, "TODO");
		ud.name = pool.dupStringz(name);
		ud.value = pool.dupArray(param.value[0..param.valueSize]);
		++numParams;
	});

	assert (pool.isFull());+/
}


void setEffectInstanceUniformDefaults(EffectInfo* effectInfo, EffectInstance efInst) {
	foreach (ud; effectInfo.uniformDefaults) {
		if (void** ptr = efInst.getUniformPtrPtr(ud.name)) {
			assert (*ptr, ud.name);
			memcpy(*ptr, ud.value.ptr, ud.value.length);
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

		auto img = imgLoader.load(getResourcePath(filePath));
		if (!img.valid) {
			log.warn("Could not load texture: '{}'", filePath);
			img = imgLoader.load(getResourcePath("img/testgrid.png"));
			if (!img.valid) {
				error("Could not fallback texture.");
			}
		}

		TextureRequest req;
		foreach (p; sampler.params) {
			if ("minFilter" == p.name) {
				cstring val;
				p.getValueIdent(&val);
				switch (val) {
					case "linear": req.minFilter = TextureMinFilter.Linear; break;
					case "nearest": req.minFilter = TextureMinFilter.Nearest; break;
					case "mipmapLinear": req.minFilter = TextureMinFilter.LinearMipmapLinear; break;
					default: log.error("Unrecognized texture min filter: '{}'", val);
				}
			}

			if ("magFilter" == p.name) {
				cstring val;
				p.getValueIdent(&val);
				switch (val) {
					case "linear": req.magFilter = TextureMagFilter.Linear; break;
					case "nearest": req.magFilter = TextureMagFilter.Nearest; break;
					default: log.error("Unrecognized texture mag filter: '{}'", val);
				}
			}
		}

		*tex = backend.createTexture(
			img,
			TextureCacheKey.path(filePath),
			req
		);
	} else {
		assert (false, "TODO: use a fallback texture");
	}
}
