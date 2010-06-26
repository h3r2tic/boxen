module xf.nucleus.renderer.ForwardRenderer;

private {
	import xf.Common;
	import xf.nucleus.Defs;
	import xf.nucleus.Param;
	import xf.nucleus.Function;
	import xf.nucleus.Renderable;
	import xf.nucleus.Light;
	import xf.nucleus.Renderer;
	import xf.nucleus.RenderList;
	import xf.nucleus.KernelImpl;
	import xf.nucleus.KernelParamInterface;
	import xf.nucleus.KernelCompiler;
	import xf.nucleus.kdef.Common;
	import xf.nucleus.kdef.model.IKDefRegistry;
	import xf.nucleus.kdef.KDefGraphBuilder;
	import xf.nucleus.graph.GraphOps;
	import xf.nucleus.graph.KernelGraph;
	import xf.nucleus.graph.KernelGraphOps;
	import xf.nucleus.graph.GraphMisc;
	import xf.nucleus.Log : log = nucleusLog, error = nucleusError;

	import xf.gfx.EffectHelper;		// TODO: get rid of this
	
	import Nucleus = xf.nucleus.Nucleus;
	
	import xf.gfx.Effect;
	import xf.gfx.IRenderer : RendererBackend = IRenderer;
	import xf.gfx.IndexData;
	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.CoordSys;
	import xf.omg.util.ViewSettings;
	import xf.mem.StackBuffer;
	
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
			info.nodes = stack.allocArrayNoInit!(GraphNodeId)(kernel.graph.numNodes);
			
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
		super(backend);
	}


	private Effect buildEffectForRenderable(RenderableId rid, Light[] affectingLights) {
		scope stack = new StackBuffer;

		final structureKernel		= _kdefRegistry.getKernel(renderables.structureKernel[rid]);
		final pigmentKernel			= _kdefRegistry.getKernel(renderables.pigmentKernel[rid]);
		final illumKernel			= _kdefRegistry.getKernel("BlinnPhong");//renderables.illuminationKernel[rid];

		alias KernelGraph.NodeType NT;

		// ---- Build the Structure kernel graph

		SubgraphInfo structureInfo;
		SubgraphInfo pigmentInfo;
		
		auto kg = createKernelGraph();

		{
			GraphBuilder builder;
			builder.sourceKernelType = SourceKernelType.Structure;
			builder.build(kg, structureKernel, &structureInfo, stack);
		}

		assert (structureInfo.output.valid);

		// Compute all flow and conversions within the Structure graph,
		// skipping conversions to the Output node

		File.set("graph.dot", toGraphviz(kg));

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
						cstring dstParam,
						GraphNodeId* srcNid,
						Param** srcParam
					) {
						if (dstParam != "position" && dstParam != "normal") {
							error(
								"Expected position or normal input from a"
								" light kernel. Got: '{}'", dstParam
							);
						}
						
						return getOutputParamIndirect(
							kg,
							structureInfo.output,
							dstParam,
							srcNid,
							srcParam
						);
					},

					OutputNodeConversion.Skip
				);
			}

			// Connect the illumination graph to light and structure output

			foreach (lightI, ref illumGraph; illumGraphs) {
				scope stack2 = new StackBuffer;
				auto illumNodesTopo = stack2.allocArray!(GraphNodeId)(illumGraph.nodes.length);
				findTopologicalOrder(kg.backend_readOnly, illumGraph.nodes, illumNodesTopo);

				fuseGraph(
					kg,
					illumGraph.input,
					&_kdefRegistry.converters,
					illumNodesTopo,
					
					// _findSrcParam
					delegate bool(
						cstring dstParam,
						GraphNodeId* srcNid,
						Param** srcParam
					) {
						switch (dstParam) {
							case "position":
							case "normal":
								return getOutputParamIndirect(
									kg,
									structureInfo.output,
									dstParam,
									srcNid,
									srcParam
								);

							default:
								return getOutputParamIndirect(
									kg,
									lightGraphs[lightI].output,
									dstParam,
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

			fuseGraph(
				kg,
				pigmentInfo.input,
				&_kdefRegistry.converters,
				pigmentNodesTopo,
				
				// _findSrcParam
				delegate bool(
					cstring dstParam,
					GraphNodeId* srcNid,
					Param** srcParam
				) {
					switch (dstParam) {
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
								dstParam,
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

		verifyDataFlowNames(kg);

		File.set("graph.dot", toGraphviz(kg));

		// ----

		CodegenSetup cgSetup;
		cgSetup.inputNode = structureInfo.input;
		cgSetup.outputNode = pigmentInfo.output;

		return compileKernelGraph(
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
					`
				);
			}
		);
	}


	private void compileEffectsForRenderables(RenderableId[] rids) {
		foreach (idx, rid; rids) {
			if (!this._renderableValid.isSet(rid)) {
				// --- Find the lights affecting this renderable
				
				// HACK
				Light[] affectingLights = .lights;

				// compile the kernels, create an EffectInstance
				// TODO: cache Effects and only create new EffectInstances
				final effect = buildEffectForRenderable(rid, affectingLights);

				// ----

				effect.compile();
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
				}

				// ----
				
				EffectInstance efInst = _backend.instantiateEffect(effect);
				allocateDefaultUniformStorage(efInst);
				allocateDefaultVaryingStorage(efInst);

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
	}
}
