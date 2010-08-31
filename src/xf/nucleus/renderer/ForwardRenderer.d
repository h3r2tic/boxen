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
		xf.nucleus.Material,
		xf.nucleus.SamplerDef,
		xf.nucleus.kdef.Common,
		xf.nucleus.kdef.model.IKDefRegistry,
		xf.nucleus.kdef.model.KDefInvalidation,
		xf.nucleus.kdef.KDefGraphBuilder,
		xf.nucleus.graph.GraphOps,
		xf.nucleus.graph.KernelGraph,
		xf.nucleus.graph.KernelGraphOps,
		xf.nucleus.graph.GraphMisc,
		xf.nucleus.util.EffectInfo;

	import xf.vsd.VSD;
		
	import xf.nucleus.Log : log = nucleusLog, error = nucleusError;

	static import xf.nucleus.codegen.Rename;

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
		xf.mem.ChunkQueue,
		xf.mem.ScratchAllocator,
		xf.mem.SmallTempArray,
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



class ForwardRenderer : Renderer {
	mixin MRenderer!("Forward");

	
	this (RendererBackend backend, IKDefRegistry kdefRegistry) {
		_kdefRegistry = kdefRegistry;
		_effectCache = new typeof(_effectCache);
		super(backend);
	}

	private {
		// all mem allocated off the scratch fifo
		struct SurfaceData {
			struct Info {
				cstring	name;		// stringz
				void*	ptr;
			}
			
			Info[]			info;
			KernelImplId	kernelId;
			ScratchFIFO		_mem;
			//KernelImpl	reflKernel;

			void dispose() {
				_mem.dispose();
				info = null;
				kernelId = KernelImplId.invalid;
			}
		}
		
		SurfaceData[256]	_surfaces;
	}


	// TODO: mem
	// TODO: textures
	override void registerSurface(SurfaceDef def) {
		auto surf = &_surfaces[def.id];

		surf._mem.initialize();
		final mem = DgScratchAllocator(&surf._mem.pushBack);

		surf.info = mem.allocArray!(SurfaceData.Info)(def.params.length);

		//assert (def.reflKernel !is null);
		assert (def.reflKernel.id.isValid);
		surf.kernelId = def.reflKernel.id;

		uword sizeReq = 0;
		
		foreach (i, p; def.params) {
			surf.info[i].name = mem.dupStringz(cast(cstring)p.name);
			// TODO: figure out whether that alignment is needed at all
			memcpy(
				surf.info[i].ptr = mem.alignedAllocRaw(p.valueSize, uword.sizeof),
				p.value,
				p.valueSize
			);
		}
	}


	protected void unregisterSurfaces() {
		foreach (ref surf; _surfaces) {
			surf.dispose();
		}
	}


	// implements IKDefInvalidationObserver
	void onKDefInvalidated(KDefInvalidationInfo info) {
		unregisterMaterials();
		unregisterSurfaces();
		_renderableValid.clearAll();
		
		scope stack = new StackBuffer;
		mixin MSmallTempArray!(Effect) toDispose;
		
		if (info.anyConverters) {
			foreach (eck, ref einfo; _effectCache) {
				if (einfo.isValid) {
					toDispose.pushBack(einfo.effect, &stack.allocRaw);
					einfo.dispose();
				}
			}
		} else {
			foreach (eck, ref einfo; _effectCache) {
				if (einfo.isValid) {
					if (
							!_kdefRegistry.getKernel(eck.materialKernel).isValid
						||	!_kdefRegistry.getKernel(eck.structureKernel).isValid
						||	!_kdefRegistry.getKernel(eck.reflKernel).isValid
					) {
						toDispose.pushBack(einfo.effect, &stack.allocRaw);
						einfo.dispose();
					} else {
						foreach (lk; eck.lightKernels) {
							if (!_kdefRegistry.getKernel(lk).isValid) {
								toDispose.pushBack(einfo.effect, &stack.allocRaw);
								einfo.dispose();
								break;
							}
						}
					}
				}
			}
		}

		foreach (ref ei; _renderableEI) {
			if (ei.isValid) {
				auto eiEf = ei.getEffect;
				foreach (e; toDispose.items) {
					if (e is eiEf) {
						ei.dispose();
						break;
					}
				}
			}
		}

		foreach (ef; toDispose.items) {
			_backend.disposeEffect(ef);
		}
	}


	// TODO: mem, indices instead of names (?)
	struct EffectCacheKey {
		KernelImplId	materialKernel;
		KernelImplId	reflKernel;
		KernelImplId	structureKernel;
		KernelImplId[]	lightKernels;
		hash_t			hash;

		hash_t toHash() {
			return hash;
		}

		bool opEquals(ref EffectCacheKey other) {
			return
					materialKernel == other.materialKernel
				&&	reflKernel == other.reflKernel
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

		key.materialKernel = *_materialKernels[materialId];
		key.reflKernel = surface.kernelId;
		key.structureKernel = _kdefRegistry.getKernel(renderables.structureKernel[rid]).id;

		key.lightKernels.length = affectingLights.length;

		foreach (lightI, light; affectingLights) {
			key.lightKernels[lightI] = _kdefRegistry.getKernel(light.kernelName).id;
		}

		key.lightKernels.sort;

		hash_t hash = 0;
		hash += key.materialKernel.value;
		hash *= 7;
		hash += key.reflKernel.value;
		hash *= 7;
		hash += key.structureKernel.value;

		foreach (ref lightKernel; key.lightKernels) {
			hash *= 7;
			hash += lightKernel.value;
		}

		key.hash = hash;

		return key;
	}


	private EffectInfo buildEffectForRenderable(RenderableId rid, Light[] affectingLights) {
		scope stack = new StackBuffer;

		EffectInfo effectInfo;

		SurfaceId surfaceId = renderables.surface[rid];
		auto surface = &_surfaces[surfaceId];

		MaterialId materialId = renderables.material[rid];
		auto material = _materials[materialId];

		final structureKernel	= _kdefRegistry.getKernel(renderables.structureKernel[rid]);
		final materialKernel	= _kdefRegistry.getKernel(*_materialKernels[materialId]);
		final reflKernel		= _kdefRegistry.getKernel(surface.kernelId);

		log.info(
			"buildEffectForRenderable for structure {}, mat {}, refl {}",
			structureKernel.name,
			materialKernel.name,
			reflKernel.name
		);

		assert (structureKernel.isValid);
		assert (materialKernel.isValid);
		assert (reflKernel.isValid);

		alias KernelGraph.NodeType NT;

		// ---- Build the Structure kernel graph

		BuilderSubgraphInfo structureInfo;
		BuilderSubgraphInfo materialInfo;
		
		auto kg = createKernelGraph();
		scope (exit) {
			//assureNotCyclic(kg);
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

		ConvCtx convCtx;
		convCtx.semanticConverters = &_kdefRegistry.converters;
		convCtx.getKernel = &_kdefRegistry.getKernel;

		convertGraphDataFlowExceptOutput(
			kg,
			convCtx
		);

		void buildMaterialGraph() {
			GraphBuilder builder;
			builder.sourceKernelType = SourceKernelType.Material;
			builder.build(kg, materialKernel, &materialInfo, stack);

			assert (materialInfo.input.valid);
		}


		buildMaterialGraph();

		final materialNodesTopo = stack.allocArray!(GraphNodeId)(materialInfo.nodes.length);
		findTopologicalOrder(kg.backend_readOnly, materialInfo.nodes, materialNodesTopo);

		//File.set("graph.dot", toGraphviz(kg));

		fuseGraph(
			kg,
			materialInfo.input,
			convCtx,
			materialNodesTopo,
			
			// _findSrcParam
			delegate bool(
				Param* dstParam,
				GraphNodeId* srcNid,
				Param** srcParam
			) {
				return getOutputParamIndirect(
					kg,
					structureInfo.output,
					dstParam.name,
					srcNid,
					srcParam
				);
			},

			OutputNodeConversion.Perform
		);


		bool removeNodeIfTypeMatches(GraphNodeId id, NT type) {
			if (type == kg.getNode(id).type) {
				kg.removeNode(id);
				return true;
			} else {
				return false;
			}
		}

		if (affectingLights.length > 0) {
			// ---- Build the graphs for lights and reflectance

			auto lightGraphs = stack.allocArray!(BuilderSubgraphInfo)(affectingLights.length);
			auto reflGraphs = stack.allocArray!(BuilderSubgraphInfo)(affectingLights.length);

			foreach (lightI, light; affectingLights) {
				final lightGraph = &lightGraphs[lightI];
				final reflGraph = &reflGraphs[lightI];

				// Build light kernel graphs

				final lightKernel = _kdefRegistry.getKernel(light.kernelName);

				{
					GraphBuilder builder;
					builder.sourceKernelType = SourceKernelType.Light;
					builder.sourceLightIndex = lightI;
					builder.build(kg, lightKernel, lightGraph, stack);
				}

				// Build reflectance kernel graphs

				{
					GraphBuilder builder;
					builder.sourceKernelType = SourceKernelType.Reflectance;
					builder.spawnDataNodes = 0 == lightI;
					builder.dataNodeSource = reflGraphs[0].nodes;
					builder.build(kg, reflKernel, reflGraph, stack);
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
					convCtx,
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

			// Connect the reflectance graph to light and structure output

			uword numReflDataNodes = 0;
			foreach (n; reflGraphs[0].nodes) {
				if (NT.Data == kg.getNode(n).type) {
					++numReflDataNodes;
				}
			}

			foreach (lightI, ref reflGraph; reflGraphs) {
				scope stack2 = new StackBuffer;

				/*
				 * We collect only the non-data nodes here for fusion, as
				 * Data nodes are shared between reflectance kernel nodes.
				 * Having them in the list would make findTopologicalOrder
				 * traverse outward from them and find the connected non-shared
				 * nodes of other refl graph instances. The Data nodes are not
				 * used in fusion anyway - it's mostly concerned about Input
				 * and Output nodes, plus whatever might be connected to them.
				 */
				uword numReflNoData = reflGraph.nodes.length - numReflDataNodes;
				auto reflNoData = stack2.allocArray!(GraphNodeId)(numReflNoData); {
					uword i = 0;
					foreach (n; reflGraph.nodes) {
						if (NT.Data != kg.getNode(n).type) {
							reflNoData[i++] = n;
						}
					}
				}
				
				auto reflNodesTopo = stack2.allocArray!(GraphNodeId)(numReflNoData);
				findTopologicalOrder(kg.backend_readOnly, reflNoData, reflNodesTopo);

				fuseGraph(
					kg,
					reflGraph.input,
					convCtx,
					reflNodesTopo,
					
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
									materialInfo.output,
									"out_normal",
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


			// ---- Sum the diffuse and specular reflectance
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
					foreach (ref ig; reflGraphs) {
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
								" of an refl kernel. Should have been found earlier."
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
					foreach (ref ig; reflGraphs) {
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
								" of an refl kernel. Should have been found earlier."
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
			foreach (ref ig; reflGraphs) {
				removeNodeIfTypeMatches(ig.output, NT.Output);
			}

			// ---

			verifyDataFlowNames(kg);

			// --- Conversions

			convertGraphDataFlowExceptOutput(
				kg,
				convCtx
			);

			if (!structureInfo.singleNode) {
				removeNodeIfTypeMatches(structureInfo.output, NT.Output);
			}

			Function mulFunc; {
				final mulKernel = _kdefRegistry.getKernel("Mul");
				assert (KernelImpl.Type.Kernel == mulKernel.type);
				assert (mulKernel.kernel.isConcrete);
				mulFunc = cast(Function)mulKernel.kernel.func;
			}

			auto mulDiffuseNid = kg.addFuncNode(mulFunc);
			auto mulSpecularNid = kg.addFuncNode(mulFunc);
			auto sumTotalLight = kg.addFuncNode(addFunc);

			kg.flow.addDataFlow(specularSumNid, specularSumPName, mulSpecularNid, "a");
			kg.flow.addDataFlow(mulDiffuseNid, "c", sumTotalLight, "a");

			kg.flow.addDataFlow(diffuseSumNid, diffuseSumPName, mulDiffuseNid, "a");
			{
				GraphNodeId nid;
				Param* par;
				if (getOutputParamIndirect(
					kg,
					materialInfo.output,
					"out_albedo",
					&nid,
					&par
				)) {
					kg.flow.addDataFlow(nid, par.name, mulDiffuseNid, "b");
				} else {
					error("Incoming flow to 'out_albedo' of the Material kernel not found.");
				}
			}

			kg.flow.addDataFlow(mulSpecularNid, "c", sumTotalLight, "b");
			{
				GraphNodeId nid;
				Param* par;
				if (getOutputParamIndirect(
					kg,
					materialInfo.output,
					"out_specular",
					&nid,
					&par
				)) {
					kg.flow.addDataFlow(nid, par.name, mulSpecularNid, "b");
				} else {
					error("Incoming flow to 'out_specular' of the Material kernel not found.");
				}
			}

			auto outRadianceNid = kg.addNode(NT.Output);
			final outRadiance = kg.getNode(outRadianceNid).output.params
				.add(ParamDirection.In, "out_radiance");
			outRadiance.hasPlainSemantic = true;
			outRadiance.type = "float4";
			outRadiance.semantic.addTrait("use", "color");

			kg.flow.addDataFlow(sumTotalLight, "c", outRadianceNid, outRadiance.name);

			convertGraphDataFlowExceptOutput(
				kg,
				convCtx,
				(int delegate(ref GraphNodeId) sink) {
					if (int r = sink(materialInfo.output)) return r;
					if (int r = sink(mulDiffuseNid)) return r;
					if (int r = sink(mulSpecularNid)) return r;
					if (int r = sink(sumTotalLight)) return r;
					if (int r = sink(outRadianceNid)) return r;
					return 0;
				}
			);

			removeNodeIfTypeMatches(materialInfo.output, NT.Output);

			// For codegen below
			materialInfo.output = outRadianceNid;
		} else {
			assert (false); 	// TODO
			
			// No affecting lights
			// TODO: zero the diffuse and specular contribs
			// ... or don't draw the object

			/+buildMaterialGraph();

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

				materialInfo.input,
				convCtx,
				OutputNodeConversion.Perform
			);+/
		}

		//assureNotCyclic(kg);

		kg.flow.removeAllAutoFlow();

		verifyDataFlowNames(kg);

		// ----

		CodegenSetup cgSetup;
		cgSetup.inputNode = structureInfo.input;
		cgSetup.outputNode = materialInfo.output;

		final ctx = CodegenContext(&stack.allocRaw);

		final effect = effectInfo.effect = compileKernelGraph(
			null,
			kg,
			cgSetup,
			&ctx,
			_backend,
			(CodeSink fmt) {
				fmt(
`
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

		//assureNotCyclic(kg);

		// ----

		effect.compile();

		// HACK
		allocateDefaultUniformStorage(effect);

		//assureNotCyclic(kg);

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

		//assureNotCyclic(kg);

		return effectInfo;
	}


	private void compileEffectsForRenderables(RenderableId[] rids) {
		foreach (idx, rid; rids) {
			if (!this._renderableValid.isSet(rid) || !_renderableEI[rid].valid) {
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

				{
					EffectInfo* info = cacheKey in _effectCache;
					
					if (info !is null && info.effect !is null) {
						effectInfo = *info;
					} else {
						effectInfo = buildEffectForRenderable(rid, affectingLights);
						if (info !is null) {
							// Must have been disposed earlier in whatever caused
							// the compilation of the effect anew
							assert (info.effect is null);
							*info = effectInfo;
						} else {
							_effectCache[cacheKey] = effectInfo;
						}
					}
				}

				Effect effect = effectInfo.effect;

				// ----

				EffectInstance efInst = _backend.instantiateEffect(effect);

				// HACK
				// all structure params should come from the asset
				// all reflectance params - from the surface
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
				 * The proper solution will be to inspect all refl and material
				 * kernels, match them to mats/surfs and create the default param
				 * values directly inside mats/surfs. This could also be done on
				 * the level of Nucled, so that mats/surfs always define all values,
				 * even if they're not set in the GUI
				 */
				setEffectInstanceUniformDefaults(&effectInfo, efInst);

				// ----

				auto surface = &_surfaces[renderables.surface[rid]];
				foreach (ref info; surface.info) {
					char[256] fqn;
					sprintf(fqn.ptr, "reflectance__%.*s", info.name);
					auto name = fromStringz(fqn.ptr);
					void** ptr = getInstUniformPtrPtr(name);
					if (ptr) {
						*ptr = info.ptr;
					}
				}
				
				auto material = _materials[renderables.material[rid]];
				foreach (ref info; material.info) {
					char[256] fqn;
					sprintf(fqn.ptr, "material__%.*s", info.name);
					auto name = fromStringz(fqn.ptr);
					void** ptr = getInstUniformPtrPtr(name);
					if (ptr) {
						*ptr = info.ptr;
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

				if (_renderableEI[rid].valid) {
					_renderableEI[rid].dispose();
				}
				
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

	
	override void render(ViewSettings vs, VSDRoot* vsd, RenderList* rlist) {
		// HACK
		foreach (l; .lights) {
			l.prepareRenderData(vsd);
		}

		this.viewToClip = vs.computeProjectionMatrix();
		this.worldToView = vs.computeViewMatrix();
		this.eyePosition = vec3.from(vs.eyeCS.origin);

		final rids = rlist.list.renderableId[0..rlist.list.length];
		compileEffectsForRenderables(rids);

		final blist = _backend.createRenderList();
		scope (exit) _backend.disposeRenderList(blist);

		foreach (l; .lights) {
			l.calcInfluenceRadius();
		}

		foreach (idx, rid; rids) {
			final ei = _renderableEI[rid];
			final bin = blist.getBin(ei.getEffect);
			final item = bin.add(ei);
			
			item.coordSys		= rlist.list.coordSys[idx];
			item.indexData		= *_renderableIndexData[rid];
		}

		_backend.render(blist);
	}


	private {
		// HACK
		EffectInstance[]	_renderableEI;
		IndexData*[]		_renderableIndexData;

		IKDefRegistry		_kdefRegistry;

		mat4	worldToView;
		mat4	viewToClip;
		vec3	eyePosition;
	}
}
