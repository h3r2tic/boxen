module xf.nucleus.renderer.ForwardRenderer;

private {
	import
		xf.Common,
		xf.nucleus.Defs,
		xf.nucleus.Value,
		xf.nucleus.Param,
		xf.nucleus.Function,
		xf.nucleus.Renderable,
		xf.nucleus.Light,
		xf.nucleus.Renderer,
		xf.nucleus.RenderList,
		xf.nucleus.KernelImpl,
		xf.nucleus.KernelParamInterface,
		xf.nucleus.KernelCompiler,
		xf.nucleus.SurfaceDef,
		xf.nucleus.MaterialDef,
		xf.nucleus.SamplerDef,
		xf.nucleus.kdef.Common,
		xf.nucleus.kdef.model.IKDefRegistry,
		xf.nucleus.kdef.KDefGraphBuilder,
		xf.nucleus.kernel.KernelDef,
		xf.nucleus.graph.GraphOps,
		xf.nucleus.graph.KernelGraph,
		xf.nucleus.graph.KernelGraphOps,
		xf.nucleus.graph.GraphMisc;
		
	import xf.nucleus.Log : log = nucleusLog, error = nucleusError;

	static import xf.nucleus.codegen.Rename;

	// TODO: refactor into a shared texture loader
	interface Img {
	import
		xf.img.Image,
		xf.img.FreeImageLoader,
		xf.img.CachedLoader,
		xf.img.Loader;
	}

	import xf.gfx.EffectHelper;		// TODO: get rid of this
	
	import Nucleus = xf.nucleus.Nucleus;
	
	import
		xf.gfx.Effect,
		xf.gfx.IndexData,
		xf.gfx.Texture,
		xf.omg.core.LinearAlgebra,
		xf.omg.core.CoordSys,
		xf.omg.util.ViewSettings,
		xf.mem.StackBuffer,
		xf.mem.MainHeap,
		xf.mem.ScratchAlloc,
		xf.gfx.IRenderer : RendererBackend = IRenderer;

	import xf.mem.Array;
	import MemUtils = xf.utils.Memory;
	import xf.utils.FormatTmp;

	import tango.util.container.HashMap;

	import tango.stdc.stdio : sprintf;

	// TMP
	static import xf.utils.Memory;
	import tango.io.device.File;
}



private struct SubgraphInfo {
	GraphNodeId[]	nodes;
	GraphNodeId		input;
	GraphNodeId		output;

	bool singleNode() {
		return 1 == nodes.length;
	}
}


struct GraphBuilder {
	SourceKernelType	sourceKernelType;
	uword				sourceLightIndex;
	bool				spawnDataNodes = true;
	GraphNodeId[]		dataNodeSource;


	void build(
			KernelGraph kg,
			KernelImpl kernel,
			SubgraphInfo* info,
			StackBufferUnsafe stack
	) {
		if (KernelImpl.Type.Kernel == kernel.type) {
			if (!kernel.kernel.isConcrete) {
				error("Trying to use an abstract function for a kernel in a graph");
			}
			
			info.nodes = stack.allocArrayNoInit!(GraphNodeId)(1);
			
			info.nodes[0] = info.input = info.output
				= kg.addFuncNode(cast(Function)kernel.kernel.func);
		} else {
			info.nodes = stack.allocArrayNoInit!(GraphNodeId)(
				numGraphFlattenedNodes(kernel.graph)
			);
			
			buildKernelGraph(
				kernel.graph,
				kg,
				(uint nidx, cstring, GraphDefNode def, GraphNodeId delegate() getNid) {
					if (!spawnDataNodes && "data" == def.type) {
						return info.nodes[nidx] = dataNodeSource[nidx];
					} else {
						final nid = getNid();
						final n = kg.getNode(nid);

						info.nodes[nidx] = nid;

						if (KernelGraph.NodeType.Input == n.type) {
							info.input = nid;
						}
						if (KernelGraph.NodeType.Output == n.type) {
							info.output = nid;
						}
						if (KernelGraph.NodeType.Data == n.type) {
							n.data.sourceKernelType = sourceKernelType;
							n.data.sourceLightIndex = sourceLightIndex;
						}
						
						return nid;
					}
				}
			);
		}
	}
}


class ForwardRenderer : Renderer {
	mixin MRenderer!("Foward");

	
	this (RendererBackend backend, IKDefRegistry kdefRegistry) {
		_kdefRegistry = kdefRegistry;
		_imgLoader = new Img.CachedLoader(new Img.FreeImageLoader);
		_effectCache = new typeof(_effectCache);
		super(backend);
	}

	private {
		struct SurfaceData {
			struct Info {
				cstring	name;
				word	offset;
			}
			
			Info[]		info;
			void*		data;
			KernelImpl	illumKernel;
		}
		
		struct MaterialData {
			struct Info {
				cstring	name;		// not owned here
				word	offset;
			}
			
			Info[]		info;
			void*		data;
			KernelImpl	pigmentKernel;
		}

		SurfaceData[256]		_surfaces;
		Array!(MaterialData)	_materials;

		Img.Loader	_imgLoader;
	}


	// TODO: mem
	// TODO: textures
	override void registerSurface(SurfaceDef def) {
		auto surf = &_surfaces[def.id];
		surf.info.length = def.params.length;

		//assert (def.illumKernel !is null);
		surf.illumKernel = def.illumKernel;

		uword sizeReq = 0;
		
		foreach (i, p; def.params) {
			surf.info[i].name = (cast(cstring)p.name).dup;
			surf.info[i].offset = sizeReq;
			sizeReq += p.valueSize;
			sizeReq += 3;
			sizeReq &= ~3;
		}

		surf.data = mainHeap.allocRaw(sizeReq);
		memset(surf.data, 0, sizeReq);

		foreach (i, p; def.params) {
			void* dst = surf.data + surf.info[i].offset;
			memcpy(dst, p.value, p.valueSize);
		}
	}


	// TODO: mem
	// TODO: textures
	override void registerMaterial(MaterialDef def) {
		if (def.id >= _materials.length) {
			_materials.growBy(def.id - _materials.length + 1);
		}
		
		auto mat = _materials[def.id];
		static assert (isReferenceType!(typeof(mat)));
		
		MemUtils.alloc(mat.info, def.params.length);

		//assert (def.illumKernel !is null);
		mat.pigmentKernel = def.pigmentKernel;

		uword sizeReq = 0;
		
		foreach (i, p; def.params) {
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

		foreach (i, p; def.params) {
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
						loadMaterialSamplerParam(sampler, tex);
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

				default: {
					memcpy(dst, p.value, p.valueSize);
				} break;
			}
		}
	}


	private void loadMaterialSamplerParam(SamplerDef sampler, Texture* tex) {
		if (auto val = sampler.params.get("texture")) {
			cstring filePath;
			val.getValue(&filePath);

			Img.Image img = _imgLoader.load(filePath);
			if (!img.valid) {
				// TODO: fallback
				error("Could not load texture: '{}'", filePath);
			}

			*tex = _backend.createTexture(
				img
			);
		} else {
			assert (false, "TODO: use a fallback texture");
		}
	}


	// TODO: mem
	struct EffectInfo {
		struct UniformDefaults {
			char[]	name;		// zero-terminated
			void[]	value;
		}

		UniformDefaults[]	uniformDefaults;
		Effect				effect;


		void dispose() {
			// TODO: dispose the effect
		}
	}


	// TODO: mem, indices instead of names (?)
	struct EffectCacheKey {
		cstring		pigmentKernel;
		cstring		illumKernel;
		cstring		structureKernel;
		cstring[]	lightKernels;
		hash_t		hash;

		hash_t toHash() {
			return hash;
		}

		bool opEquals(ref EffectCacheKey other) {
			return
					pigmentKernel == other.pigmentKernel
				&&	illumKernel == other.illumKernel
				&&	structureKernel == other.structureKernel
				&&	lightKernels == other.lightKernels;
		}
	}

	private {
		HashMap!(EffectCacheKey, EffectInfo) _effectCache;
	}


	private EffectCacheKey createEffectCacheKey(RenderableId rid, Light[] affectingLights) {
		EffectCacheKey key;

		SurfaceId surfaceId = renderables.surface[rid];
		auto surface = &_surfaces[surfaceId];

		MaterialId materialId = renderables.material[rid];
		auto material = _materials[materialId];

		key.pigmentKernel = material.pigmentKernel.name;
		key.illumKernel = surface.illumKernel.name;
		key.structureKernel = renderables.structureKernel[rid];

		key.lightKernels.length = affectingLights.length;

		foreach (lightI, light; affectingLights) {
			key.lightKernels[lightI] = light.kernelName;
		}

		key.lightKernels.sort;

		hash_t hash = 0;
		hash += typeid(cstring).getHash(&key.pigmentKernel);
		hash *= 7;
		hash += typeid(cstring).getHash(&key.illumKernel);
		hash *= 7;
		hash += typeid(cstring).getHash(&key.structureKernel);

		foreach (ref lightKernel; key.lightKernels) {
			hash *= 7;
			hash += typeid(cstring).getHash(&lightKernel);
		}

		key.hash = hash;

		return key;
	}


	private void findEffectInfo(KernelGraph kg, EffectInfo* effectInfo) {
		assert (effectInfo !is null);

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
		uword sizeReq = 0;

		iterDataParams((cstring name, Param* param) {
			sizeReq += name.length+1;	// stringz
			sizeReq += param.valueSize;
			sizeReq += EffectInfo.UniformDefaults.sizeof;
			++numParams;
		});

		final pool = PoolScratchAlloc(mainHeap.allocRaw(sizeReq)[0..sizeReq]);
		
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

		assert (pool.isFull());
	}


	private EffectInfo buildEffectForRenderable(RenderableId rid, Light[] affectingLights) {
		scope stack = new StackBuffer;

		EffectInfo effectInfo;

		SurfaceId surfaceId = renderables.surface[rid];
		auto surface = &_surfaces[surfaceId];

		MaterialId materialId = renderables.material[rid];
		auto material = _materials[materialId];

		final structureKernel		= _kdefRegistry.getKernel(renderables.structureKernel[rid]);
		final pigmentKernel			= material.pigmentKernel;
		final illumKernel			= surface.illumKernel;

		alias KernelGraph.NodeType NT;

		// ---- Build the Structure kernel graph

		SubgraphInfo structureInfo;
		SubgraphInfo pigmentInfo;
		
		auto kg = createKernelGraph();
		scope (exit) {
			disposeKernelGraph(kg);
		}

		{
			GraphBuilder builder;
			builder.sourceKernelType = SourceKernelType.Structure;
			builder.build(kg, structureKernel, &structureInfo, stack);
		}

		assert (structureInfo.output.valid);

		// Compute all flow and conversions within the Structure graph,
		// skipping conversions to the Output node

		/+File.set("graph.dot", toGraphviz(kg));
		scope (failure) {
			File.set("graph.dot", toGraphviz(kg));
		}+/

		convertGraphDataFlowExceptOutput(
			kg,
			&_kdefRegistry.converters
		);

		void buildPigmentGraph() {
			GraphBuilder builder;
			builder.sourceKernelType = SourceKernelType.Pigment;
			builder.build(kg, pigmentKernel, &pigmentInfo, stack);

			assert (pigmentInfo.input.valid);
		}

		bool removeNodeIfTypeMatches(GraphNodeId id, NT type) {
			if (type == kg.getNode(id).type) {
				kg.removeNode(id);
				return true;
			} else {
				return false;
			}
		}

		if (affectingLights.length > 0) {
			// ---- Build the graphs for lights and illumination

			auto lightGraphs = stack.allocArray!(SubgraphInfo)(affectingLights.length);
			auto illumGraphs = stack.allocArray!(SubgraphInfo)(affectingLights.length);

			foreach (lightI, light; affectingLights) {
				final lightGraph = &lightGraphs[lightI];
				final illumGraph = &illumGraphs[lightI];

				// Build light kernel graphs

				final lightKernel = _kdefRegistry.getKernel(light.kernelName);

				{
					GraphBuilder builder;
					builder.sourceKernelType = SourceKernelType.Light;
					builder.sourceLightIndex = lightI;
					builder.build(kg, lightKernel, lightGraph, stack);
				}

				// Build illumination kernel graphs

				{
					GraphBuilder builder;
					builder.sourceKernelType = SourceKernelType.Illumination;
					builder.spawnDataNodes = 0 == lightI;
					builder.dataNodeSource = illumGraphs[0].nodes;
					builder.build(kg, illumKernel, illumGraph, stack);
				}
			}
			

			// ---- Connect the subgraphs

			// Connect the light graph to structure output
			
			foreach (lightI, ref lightGraph; lightGraphs) {
				scope stack2 = new StackBuffer;
				auto lightNodesTopo = stack2.allocArray!(GraphNodeId)(lightGraph.nodes.length);
				findTopologicalOrder(kg.backend_readOnly, lightGraph.nodes, lightNodesTopo);

				fuseGraph(
					kg,
					lightGraph.input,
					&_kdefRegistry.converters,
					lightNodesTopo,
					
					// _findSrcParam
					delegate bool(
						Param* dstParam,
						GraphNodeId* srcNid,
						Param** srcParam
					) {
						if (dstParam.name != "position" && dstParam.name != "normal") {
							error(
								"Expected position or normal input from a"
								" light kernel. Got: '{}'", dstParam.name
							);
						}
						
						return getOutputParamIndirect(
							kg,
							structureInfo.output,
							dstParam.name,
							srcNid,
							srcParam
						);
					},

					OutputNodeConversion.Skip
				);
			}

			// Connect the illumination graph to light and structure output

			uword numIllumDataNodes = 0;
			foreach (n; illumGraphs[0].nodes) {
				if (NT.Data == kg.getNode(n).type) {
					++numIllumDataNodes;
				}
			}

			foreach (lightI, ref illumGraph; illumGraphs) {
				scope stack2 = new StackBuffer;

				/*
				 * We collect only the non-data nodes here for fusion, as
				 * Data nodes are shared between illumination kernel nodes.
				 * Having them in the list would make findTopologicalOrder
				 * traverse outward from them and find the connected non-shared
				 * nodes of other illum graph instances. The Data nodes are not
				 * used in fusion anyway - it's mostly concerned about Input
				 * and Output nodes, plus whatever might be connected to them.
				 */
				uword numIllumNoData = illumGraph.nodes.length - numIllumDataNodes;
				auto illumNoData = stack2.allocArray!(GraphNodeId)(numIllumNoData); {
					uword i = 0;
					foreach (n; illumGraph.nodes) {
						if (NT.Data != kg.getNode(n).type) {
							illumNoData[i++] = n;
						}
					}
				}
				
				auto illumNodesTopo = stack2.allocArray!(GraphNodeId)(numIllumNoData);
				findTopologicalOrder(kg.backend_readOnly, illumNoData, illumNodesTopo);

				fuseGraph(
					kg,
					illumGraph.input,
					&_kdefRegistry.converters,
					illumNodesTopo,
					
					// _findSrcParam
					delegate bool(
						Param* dstParam,
						GraphNodeId* srcNid,
						Param** srcParam
					) {
						switch (dstParam.name) {
							case "toEye":
								return getOutputParamIndirect(
									kg,
									structureInfo.output,
									"position",
									srcNid,
									srcParam
								);

							case "normal":
								return getOutputParamIndirect(
									kg,
									structureInfo.output,
									dstParam.name,
									srcNid,
									srcParam
								);

							default:
								return getOutputParamIndirect(
									kg,
									lightGraphs[lightI].output,
									dstParam.name,
									srcNid,
									srcParam
								);
						}
					},
					
					OutputNodeConversion.Skip
				);

				removeNodeIfTypeMatches(lightGraphs[lightI].output, NT.Output);
			}


			// ---- Sum the diffuse and specular illumination
			Function addFunc; {
				final addKernel = _kdefRegistry.getKernel("Add");
				assert (KernelImpl.Type.Kernel == addKernel.type);
				assert (addKernel.kernel.isConcrete);
				addFunc = cast(Function)addKernel.kernel.func;
			}

			GraphNodeId	diffuseSumNid;
			cstring		diffuseSumPName;
			
			reduceGraphData(
				kg,
				(void delegate(GraphNodeId	nid, cstring pname) sink) {
					foreach (ref ig; illumGraphs) {
						GraphNodeId srcNid;
						Param* srcParam;
						
						if (!getOutputParamIndirect(
							kg,
							ig.output,
							"diffuse",
							&srcNid,
							&srcParam
						)) {
							error(
								"Could not find input to the 'diffuse' output"
								" of an illum kernel. Should have been found earlier."
							);
						}

						sink(srcNid, srcParam.name);
					}
				},
				addFunc,
				&diffuseSumNid,
				&diffuseSumPName
			);

			GraphNodeId	specularSumNid;
			cstring		specularSumPName;
			
			reduceGraphData(
				kg,
				(void delegate(GraphNodeId	nid, cstring pname) sink) {
					foreach (ref ig; illumGraphs) {
						GraphNodeId srcNid;
						Param* srcParam;
						
						if (!getOutputParamIndirect(
							kg,
							ig.output,
							"specular",
							&srcNid,
							&srcParam
						)) {
							error(
								"Could not find input to the 'specular' output"
								" of an illum kernel. Should have been found earlier."
							);
						}

						sink(srcNid, srcParam.name);
					}
				},
				addFunc,
				&specularSumNid,
				&specularSumPName
			);

			// ---

			// Not needed anymore, the flow has been reduced and the source params
			// have been located.
			foreach (ref ig; illumGraphs) {
				removeNodeIfTypeMatches(ig.output, NT.Output);
			}

			// ---

			verifyDataFlowNames(kg);

			// --- Conversions

			convertGraphDataFlowExceptOutput(
				kg,
				&_kdefRegistry.converters
			);

			buildPigmentGraph();

			final pigmentNodesTopo = stack.allocArray!(GraphNodeId)(pigmentInfo.nodes.length);
			findTopologicalOrder(kg.backend_readOnly, pigmentInfo.nodes, pigmentNodesTopo);

			//File.set("graph.dot", toGraphviz(kg));

			fuseGraph(
				kg,
				pigmentInfo.input,
				&_kdefRegistry.converters,
				pigmentNodesTopo,
				
				// _findSrcParam
				delegate bool(
					Param* dstParam,
					GraphNodeId* srcNid,
					Param** srcParam
				) {
					switch (dstParam.name) {
						case "diffuse": {
							final param = kg.getNode(diffuseSumNid)
								.getOutputParam(diffuseSumPName);
							assert (param !is null);

							*srcNid = diffuseSumNid;
							*srcParam = param;
							return true;
						}
						case "specular": {
							final param = kg.getNode(specularSumNid)
								.getOutputParam(specularSumPName);
							assert (param !is null);

							*srcNid = specularSumNid;
							*srcParam = param;
							return true;
						}

						default:
							return getOutputParamIndirect(
								kg,
								structureInfo.output,
								dstParam.name,
								srcNid,
								srcParam
							);
					}
				},

				OutputNodeConversion.Perform
			);

			if (!structureInfo.singleNode) {
				removeNodeIfTypeMatches(structureInfo.output, NT.Output);
			}
		} else {
			// No affecting lights
			// TODO: zero the diffuse and specular contribs
			// ... or don't draw the object

			buildPigmentGraph();

			verifyDataFlowNames(kg);

			fuseGraph(
				kg,
				structureInfo.output,

				// graph1NodeIter
				(int delegate(ref GraphNodeId) sink) {
					foreach (nid; structureInfo.nodes) {
						if (int r = sink(nid)) {
							return r;
						}
					}
					return 0;
				},

				pigmentInfo.input,
				&_kdefRegistry.converters,
				OutputNodeConversion.Perform
			);
		}

		kg.flow.removeAllAutoFlow();

		verifyDataFlowNames(kg);

		// ----

		CodegenSetup cgSetup;
		cgSetup.inputNode = structureInfo.input;
		cgSetup.outputNode = pigmentInfo.output;

		final effect = effectInfo.effect = compileKernelGraph(
			null,
			kg,
			cgSetup,
			_backend,
			(CodeSink fmt) {
				fmt(`
					float3x4 modelToWorld;

					float4x4 worldToView <
						string scope = "effect";
					>;
					float4x4 viewToClip <
						string scope = "effect";
					>;
					float3 eyePosition <
						string scope = "effect";
					>;
					`
				);
			}
		);

		// ----

		effect.compile();

		// HACK
		allocateDefaultUniformStorage(effect);

		void** uniforms = effect.getUniformPtrsDataPtr();

		void** getUniformPtrPtr(cstring name) {
			if (uniforms) {
				final idx = effect.effectUniformParams.getUniformIndex(name);
				if (idx != -1) {
					return uniforms + idx;
				}
			}
			return null;
		}
		
		void setUniform(cstring name, void* ptr) {
			if (auto upp = getUniformPtrPtr(name)) {
				*upp = ptr;
			}
		}

		if (uniforms) {
			setUniform("worldToView", &worldToView);
			setUniform("viewToClip", &viewToClip);
			setUniform("eyePosition", &eyePosition);
		}

		// ----

		findEffectInfo(kg, &effectInfo);

		return effectInfo;
	}


	private void compileEffectsForRenderables(RenderableId[] rids) {
		foreach (idx, rid; rids) {
			if (!this._renderableValid.isSet(rid)) {
				// --- Find the lights affecting this renderable
				
				// HACK
				Light[] affectingLights = .lights;

				// compile the kernels, create an EffectInstance
				// TODO: cache Effects and only create new EffectInstances
				EffectInfo effectInfo;

				auto cacheKey = createEffectCacheKey(
					rid,
					affectingLights
				);

				if (auto info = cacheKey in _effectCache) {
					effectInfo = *info;
				} else {
					effectInfo = buildEffectForRenderable(rid, affectingLights);
					_effectCache[cacheKey] = effectInfo;
				}

				Effect effect = effectInfo.effect;

				// ----

				EffectInstance efInst = _backend.instantiateEffect(effect);

				// HACK
				// all structure params should come from the asset
				// all illumination params - from the surface
				// all light params - from light
				// all pigmeht params - from materials
				// hence there should be no need for 'default' storage
				allocateDefaultUniformStorage(efInst);

				void** instUniforms = efInst.getUniformPtrsDataPtr();

				void** getInstUniformPtrPtr(cstring name) {
					if (instUniforms) {
						final idx = efInst.getUniformParamGroup.getUniformIndex(name);
						if (idx != -1) {
							return instUniforms + idx;
						}
					}
					return null;
				}

				// ----

				/*
				 * HACK: Bah, now this is kind of tricky. On on hand, kernel graphs
				 * may come with defaults for Data node parameters, which need to be
				 * set for new effects. On the other hand, parameters are supposed
				 * to be owned by materials/surfaces but they don't need to specify
				 * them all. In such a case there doesn't seem to be a location
				 * for these parameters which materials/surfaces don't set.
				 *
				 * The proper solution will be to inspect all illum and pigment
				 * kernels, match them to mats/surfs and create the default param
				 * values directly inside mats/surfs. This could also be done on
				 * the level of Nucled, so that mats/surfs always define all values,
				 * even if they're not set in the GUI
				 */
				foreach (ud; effectInfo.uniformDefaults) {
					void** ptr = getInstUniformPtrPtr(ud.name);
					assert (ptr && *ptr, ud.name);
					memcpy(*ptr, ud.value.ptr, ud.value.length);
				}				

				// ----

				auto surface = &_surfaces[renderables.surface[rid]];
				foreach (ref info; surface.info) {
					char[256] fqn;
					sprintf(fqn.ptr, "illumination__%.*s", info.name);
					auto name = fromStringz(fqn.ptr);
					void** ptr = getInstUniformPtrPtr(name);
					if (ptr) {
						*ptr = surface.data + info.offset;
					}
				}
				
				auto material = _materials[renderables.material[rid]];
				foreach (ref info; material.info) {
					char[256] fqn;
					sprintf(fqn.ptr, "pigment__%.*s", info.name);
					auto name = fromStringz(fqn.ptr);
					void** ptr = getInstUniformPtrPtr(name);
					if (ptr) {
						*ptr = material.data + info.offset;
					}
				}

				// ----


				foreach (uint lightI, light; affectingLights) {
					light.setKernelData(
						KernelParamInterface(
						
							// getVaryingParam
							null,

							// getUniformParam
							(cstring name) {
								char[256] fqn;
								sprintf(fqn.ptr, "light%u__%.*s", lightI, name);

								if (auto p = getInstUniformPtrPtr(fromStringz(fqn.ptr))) {
									return p;
								} else {
									return cast(void**)null;
								}
							},

							// setIndexData
							null
					));
				}

				renderables.structureData[rid].setKernelObjectData(
					KernelParamInterface(
					
						// getVaryingParam
						(cstring name) {
							char[256] fqn;
							sprintf(fqn.ptr, "VertexProgram.structure__%.*s", name);

							size_t paramIdx = void;
							if (efInst.getEffect.hasVaryingParam(
									fromStringz(fqn.ptr),
									&paramIdx
							)) {
								return efInst.getVaryingParamDataPtr() + paramIdx;
							} else {
								return cast(VaryingParamData*)null;
							}
						},

						// getUniformParam
						(cstring name) {
							char[256] fqn;
							sprintf(fqn.ptr, "structure__%.*s", name);

							if (auto p = getInstUniformPtrPtr(fromStringz(fqn.ptr))) {
								return p;
							} else {
								return cast(void**)null;
							}
						},

						// setIndexData
						(IndexData* id) {
							log.info("_renderableIndexData[{}] = {};", rid, id);
							_renderableIndexData[rid] = id;
						}
				));

				_renderableEI[rid] = efInst;
				
				this._renderableValid.set(rid);
			}
		}
	}


	override void onRenderableCreated(RenderableId id) {
		super.onRenderableCreated(id);
		xf.utils.Memory.realloc(_renderableEI, id+1);
		xf.utils.Memory.realloc(_renderableIndexData, id+1);
	}

	
	override void render(ViewSettings vs, RenderList* rlist) {
		this.viewToClip = vs.computeProjectionMatrix();
		this.worldToView = vs.computeViewMatrix();
		this.eyePosition = vec3.from(vs.eyeCS.origin);

		final rids = rlist.list.renderableId[0..rlist.list.length];
		compileEffectsForRenderables(rids);

		final blist = _backend.createRenderList();
		scope (exit) _backend.disposeRenderList(blist);

		foreach (idx, rid; rids) {
			final ei = _renderableEI[rid];
			final bin = blist.getBin(ei.getEffect);
			final item = bin.add(ei);
			
			item.coordSys		= rlist.list.coordSys[idx];
			item.scale			= vec3.one;
			item.indexData		= *_renderableIndexData[rid];
			item.numInstances	= 1;
		}

		_backend.render(blist);
	}


	private {
		// HACK
		EffectInstance[]	_renderableEI;
		IndexData*[]		_renderableIndexData;
		Effect				_meshEffect;

		IKDefRegistry		_kdefRegistry;

		mat4	worldToView;
		mat4	viewToClip;
		vec3	eyePosition;
	}
}
