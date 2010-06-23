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
	import xf.nucleus.KernelParamInterface;
	import xf.nucleus.KernelCompiler;
	import xf.nucleus.kdef.Common;
	import xf.nucleus.kdef.model.IKDefRegistry;
	import xf.nucleus.kdef.KDefGraphBuilder;
	import xf.nucleus.graph.GraphOps;
	import xf.nucleus.graph.KernelGraph;
	import xf.nucleus.graph.KernelGraphOps;
	import xf.nucleus.graph.GraphMisc;
	import xf.nucleus.quark.QuarkDef;
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



class ForwardRenderer : Renderer {
	mixin MRenderer!("Foward");

	
	this (RendererBackend backend, IKDefRegistry kdefRegistry) {
		_kdefRegistry = kdefRegistry;
		super(backend);
	}


	private Function getFuncForKernel(cstring kname, cstring fname) {
		final kernel = _kdefRegistry.getKernel(kname);
		
		if (kernel is null) {
			error(
				"convertKernelNodesToFuncNodes requested a nonexistent"
				" kernel '{}'", kname
			);
		}

		if (kernel.bestImpl is null) {
			error(
				"The '{}' kernel requested by convertKernelNodesToFuncNodes"
				" has no implemenation.", kname
			);
		}

		final quark = cast(QuarkDef)kernel.bestImpl;
		
		return quark.getFunction(fname);
	}


	private Effect buildEffectForRenderable(RenderableId rid) {
		final structureKernelName	= renderables.structureKernel[rid];
		final pigmentKernelName		= renderables.pigmentKernel[rid];
		final illumKernelName		= "PhongBlinn";//renderables.illuminationKernel[rid];

		GraphDef[char[]] graphs;

		foreach (g; &_kdefRegistry.graphs) {
			graphs[g.label] = g;
		}

		// ---- Build the Structure kernel graph

		GraphNodeId structureOutput, pigmentInput;
		
		auto kg = createKernelGraph();
		buildKernelGraph(
			graphs[structureKernelName],
			kg,
			(uint, cstring, GraphDefNode, GraphNodeId delegate() getNid) {
				final nid = getNid();
				final n = kg.getNode(nid);
				if (KernelGraph.NodeType.Output == n.type) {
					structureOutput = nid;
				}
				if (KernelGraph.NodeType.Data == n.type) {
					n.data.sourceKernelType = SourceKernelType.Structure;
				}
				return nid;
			}
		);
		assert (structureOutput.valid);

		// Compute all flow and conversions within the Structure graph,
		// skipping conversions to the Output node

		convertGraphDataFlowExceptOutput(
			kg,
			&_kdefRegistry.converters,
			&_kdefRegistry.getKernel
		);

		void buildPigmentGraph(GraphNodeId[] nodes = null) {
			buildKernelGraph(
				graphs[pigmentKernelName],
				kg,
				(uint nidx, cstring, GraphDefNode, GraphNodeId delegate() getNid) {
					final nid = getNid();
					final n = kg.getNode(nid);
					if (KernelGraph.NodeType.Input == n.type) {
						pigmentInput = nid;
					}
					if (KernelGraph.NodeType.Data == n.type) {
						n.data.sourceKernelType = SourceKernelType.Pigment;
					}
					if (nodes) {
						nodes[nidx] = nid;
					}
					return nid;
				}
			);
			assert (pigmentInput.valid);

			convertKernelNodesToFuncNodes(
				kg,
				&getFuncForKernel,
				(cstring kname, cstring fname) {
					return kname != "Rasterize";
				}
			);
		}

		// --- Find the lights affecting this renderable
		
		// HACK
		Light[] affectingLights = .lights;

		if (affectingLights.length > 0) {
			scope stack = new StackBuffer;

			struct SubgraphInfo {
				GraphNodeId[]	nodes;
				GraphNodeId		input;
				GraphNodeId		output;
			}

			// ---- Build the graphs for lights and illumination

			auto lightGraphs = stack.allocArray!(SubgraphInfo)(affectingLights.length);
			auto illumGraphs = stack.allocArray!(SubgraphInfo)(affectingLights.length);

			foreach (lightI, light; affectingLights) {
				final lightGraph = &lightGraphs[lightI];
				final illumGraph = &illumGraphs[lightI];

				// Build light kernel graphs

				final lightGraphDef = graphs[light.kernelName];
				lightGraph.nodes = stack.allocArray!(GraphNodeId)(lightGraphDef.nodes.length);

				buildKernelGraph(
					lightGraphDef,
					kg,
					(uint nidx, cstring, GraphDefNode, GraphNodeId delegate() getNid) {
						final nid = getNid();
						final n = kg.getNode(nid);
						lightGraph.nodes[nidx] = nid;
						if (KernelGraph.NodeType.Input == n.type) {
							lightGraph.input = nid;
						}
						if (KernelGraph.NodeType.Output == n.type) {
							lightGraph.output = nid;
						}
						if (KernelGraph.NodeType.Data == n.type) {
							n.data.sourceKernelType = SourceKernelType.Light;
							n.data.sourceLightIndex = lightI;
						}
						return nid;
					}
				);

				// Build illumination kernel graphs

				final illumGraphDef = graphs[illumKernelName];
				illumGraph.nodes = stack.allocArray!(GraphNodeId)(illumGraphDef.nodes.length);

				buildKernelGraph(
					illumGraphDef,
					kg,
					(uint nidx, cstring, GraphDefNode def, GraphNodeId delegate() getNid) {
						if ("data" == def.type && lightI > 0) {
							// Data nodes are shared among all illum graph instances
							return lightGraph.nodes[nidx] = lightGraphs[0].nodes[nidx];
						} else {
							final nid = getNid();
							final n = kg.getNode(nid);
							lightGraph.nodes[nidx] = nid;
							if (KernelGraph.NodeType.Input == n.type) {
								lightGraph.input = nid;
							}
							if (KernelGraph.NodeType.Output == n.type) {
								lightGraph.output = nid;
							}
							if (KernelGraph.NodeType.Data == n.type) {
								n.data.sourceKernelType = SourceKernelType.Illumination;
							}
							return nid;
						}
					}
				);
			}
			

			convertKernelNodesToFuncNodes(
				kg,
				&getFuncForKernel,
				(cstring kname, cstring fname) {
					return kname != "Rasterize";
				}
			);
			

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
					&_kdefRegistry.getKernel,
					lightNodesTopo,
					
					// _findSrcParam
					delegate bool(
						cstring dstParam,
						GraphNodeId* srcNid,
						Param** srcParam
					) {
						if (dstParam != "position" || dstParam != "normal") {
							error(
								"Expected position or normal input from a"
								" light kernel. Got: '{}'", dstParam
							);
						}
						
						return findSrcParam(
							kg,
							structureOutput,
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
					&_kdefRegistry.getKernel,
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
								return findSrcParam(
									kg,
									structureOutput,
									dstParam,
									srcNid,
									srcParam
								);

							default:
								return findSrcParam(
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

				kg.removeNode(lightGraphs[lightI].output);
			}


			// ---- Sum the diffuse and specular illumination
			final addFunc = getFuncForKernel("Add", "main");

			GraphNodeId	diffuseSumNid;
			cstring		diffuseSumPName;
			
			reduceGraphData(
				kg,
				(void delegate(GraphNodeId	nid, cstring pname) sink) {
					foreach (ref ig; illumGraphs) {
						GraphNodeId srcNid;
						Param* srcParam;
						
						if (!findSrcParam(
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
						
						if (!findSrcParam(
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
				kg.removeNode(ig.output);
			}

			// ---

			verifyDataFlowNames(kg, &_kdefRegistry.getKernel);

			// --- Conversions

			convertGraphDataFlowExceptOutput(
				kg,
				&_kdefRegistry.converters,
				&_kdefRegistry.getKernel
			);

			final pigmentNodes = stack.allocArray!(GraphNodeId)(graphs[pigmentKernelName].nodes.length);
			final pigmentNodesTopo = stack.allocArray!(GraphNodeId)(pigmentNodes.length);

			buildPigmentGraph(pigmentNodes);
			findTopologicalOrder(kg.backend_readOnly, pigmentNodes, pigmentNodesTopo);

			fuseGraph(
				kg,
				pigmentInput,
				&_kdefRegistry.converters,
				&_kdefRegistry.getKernel,
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
						}

						default:
							return findSrcParam(
								kg,
								structureOutput,
								dstParam,
								srcNid,
								srcParam
							);
					}
				},

				OutputNodeConversion.Perform
			);

			kg.removeNode(structureOutput);
		} else {
			// No affecting lights
			// TODO: zero the diffuse and specular contribs
			// ... or don't draw the object

			scope stack = new StackBuffer;
			final structureNodes = stack.allocArray!(GraphNodeId)(kg.numNodes);
			{
				uword i = 0;
				foreach (nid, dummy; kg.iterNodes) {
					structureNodes[i++] = nid;
				}
			}

			buildPigmentGraph();

			verifyDataFlowNames(kg, &_kdefRegistry.getKernel);

			fuseGraph(
				kg,
				structureOutput,

				// graph1NodeIter
				(int delegate(ref GraphNodeId) sink) {
					foreach (nid; structureNodes) {
						if (int r = sink(nid)) {
							return r;
						}
					}
					return 0;
				},

				pigmentInput,
				&_kdefRegistry.converters,
				&_kdefRegistry.getKernel,
				OutputNodeConversion.Perform
			);
		}

		verifyDataFlowNames(kg, &_kdefRegistry.getKernel);

		File.set("graph.dot", toGraphviz(kg));

		// ----

		return compileKernelGraph(
			null,
			kg,
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
				// compile the kernels, create an EffectInstance
				// TODO: cache Effects and only create new EffectInstances
				final effect = buildEffectForRenderable(rid);

				// ----

				effect.compile();
				allocateDefaultUniformStorage(effect);

				void** uniforms = effect.getUniformPtrsDataPtr();
				if (uniforms) {
					void setUniform(cstring name, void* ptr) {
						final idx = effect.effectUniformParams.getUniformIndex(name);
						if (idx != -1) {
							uniforms[idx] = ptr;
						}
					}

					setUniform("worldToView", &worldToView);
					setUniform("viewToClip", &viewToClip);
				}

				// ----
				
				EffectInstance efInst = _backend.instantiateEffect(effect);
				allocateDefaultUniformStorage(efInst);
				allocateDefaultVaryingStorage(efInst);

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
