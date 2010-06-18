module xf.nucleus.renderer.ForwardRenderer;

private {
	import xf.Common;
	import xf.nucleus.Defs;
	import xf.nucleus.Renderable;
	import xf.nucleus.Renderer;
	import xf.nucleus.RenderList;
	import xf.nucleus.KernelParamInterface;
	import xf.nucleus.KernelCompiler;
	import xf.nucleus.kdef.model.IKDefRegistry;
	import xf.nucleus.kdef.KDefGraphBuilder;
	import xf.nucleus.graph.KernelGraph;
	import xf.nucleus.graph.KernelGraphOps;
	import xf.nucleus.graph.GraphMisc;
	import xf.nucleus.quark.QuarkDef;
	import xf.nucleus.Log : log = nucleusLog, error = nucleusError;
	
	import Nucleus = xf.nucleus.Nucleus;
	
	import xf.gfx.Effect;
	import xf.gfx.IRenderer : RendererBackend = IRenderer;
	import xf.gfx.IndexData;
	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.CoordSys;
	import xf.omg.util.ViewSettings;
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


	private void compileEffectsForRenderables(RenderableId[] rids) {
		foreach (idx, rid; rids) {
			if (!this._renderableValid.isSet(rid)) {
				// compile the kernels, create an EffectInstance
				// TODO: cache Effects and only create new EffectInstances

				final structureKernelName	= renderables.structureKernel[rid];
				final surfaceKernelName		= renderables.surfaceKernel[rid];

				GraphDef[char[]] graphs;

				foreach (g; &_kdefRegistry.graphs) {
					graphs[g.label] = g;
				}

				// ----

				GraphNodeId output, input;

				auto kg = createKernelGraph();
				buildKernelGraph(
					graphs[structureKernelName],
					kg
				);
				foreach (nid, n; kg.iterNodes) {
					if (KernelGraph.NodeType.Output == n.type) {
						output = nid;
					}
					if (KernelGraph.NodeType.Data == n.type) {
						n.data.sourceKernelType = SourceKernelType.Structure;
					}
				}
				assert (output.valid);

				
				buildKernelGraph(
					graphs[surfaceKernelName],
					kg
				);
				foreach (nid, n; kg.iterNodes) {
					if (KernelGraph.NodeType.Input == n.type && nid.id > output.id) {
						input = nid;
					}
					if (
						KernelGraph.NodeType.Data == n.type
					&&	SourceKernelType.Undefined == n.data.sourceKernelType
					) {
						n.data.sourceKernelType = SourceKernelType.Surface;
					}
				}
				assert (output.valid);

				// ----

				convertKernelNodesToFuncNodes(
					kg,
					(cstring kname, cstring fname) {
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
					},
					(cstring kname, cstring fname) {
						return kname != "Rasterize";
					}
				);

				// ----

				verifyDataFlowNames(kg, &_kdefRegistry.getKernel);

				fuseGraph(
					kg,
					output,
					input,
					&_kdefRegistry.converters,
					&_kdefRegistry.getKernel
				);

				verifyDataFlowNames(kg, &_kdefRegistry.getKernel);

				File.set("graph.dot", toGraphviz(kg));

				// ----

				final effect = compileKernelGraph(
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

				// ----

				effect.compile();

				void** uniforms = effect.getUniformPtrsDataPtr();

				void setUniform(cstring name, void* ptr) {
					uniforms[effect.effectUniformParams.getUniformIndex(name)]
						= ptr;
				}

				setUniform("worldToView", &worldToView);
				setUniform("viewToClip", &viewToClip);

				// ----
				
				EffectInstance efInst = _backend.instantiateEffect(effect);

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
