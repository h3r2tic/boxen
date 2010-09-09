// massively todo
module xf.nucleus.renderer.DepthRenderer;

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
		xf.nucleus.Code,
		xf.nucleus.RenderList,
		xf.nucleus.KernelImpl,
		xf.nucleus.KernelParamInterface,
		xf.nucleus.KernelCompiler,
		xf.nucleus.SurfaceDef,
		xf.nucleus.Material,
		xf.nucleus.SamplerDef,
		xf.nucleus.codegen.Codegen,
		xf.nucleus.codegen.Body,
		xf.nucleus.codegen.Defs,
		xf.nucleus.codegen.Rename,
		xf.nucleus.codegen.Deps,
		xf.nucleus.codegen.Misc,
		xf.nucleus.kdef.Common,
		xf.nucleus.kdef.model.IKDefRegistry,
		xf.nucleus.kdef.model.KDefInvalidation,
		xf.nucleus.kdef.KDefGraphBuilder,
		xf.nucleus.graph.GraphOps,
		xf.nucleus.graph.KernelGraph,
		xf.nucleus.graph.KernelGraphOps,
		xf.nucleus.graph.GraphMisc,
		xf.nucleus.graph.Simplify,
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
		xf.gfx.Framebuffer,
		xf.gfx.Buffer,
		xf.gfx.VertexBuffer,
		xf.gfx.IndexBuffer,
		xf.gfx.IndexData,
		xf.omg.core.LinearAlgebra,
		xf.omg.core.CoordSys,
		xf.omg.util.ViewSettings,
		xf.mem.StackBuffer,
		xf.mem.MainHeap,
		xf.mem.ScratchAllocator,
		xf.mem.SmallTempArray,
		xf.utils.DgOutputStream,
		xf.gfx.IRenderer : RendererBackend = IRenderer;

	import Primitives = xf.gfx.misc.Primitives;

	import xf.mem.Array;
	import MemUtils = xf.utils.Memory;
	import xf.utils.FormatTmp;

	import tango.util.container.HashMap;

	import tango.stdc.stdio : sprintf;

	// TMP
	static import xf.utils.Memory;
	import tango.io.device.File;
	import tango.core.Variant;
}



class DepthRenderer : Renderer {
	mixin MRenderer!("Depth");
	cstring depthOutKernel = "DepthRendererOut";


	this (RendererBackend backend, IKDefRegistry kdefRegistry) {
		assert (kdefRegistry !is null);
		_kdefRegistry = kdefRegistry;
		_structureEffectCache = new typeof(_structureEffectCache);
		super(backend);
	}


	override void setParam(cstring name, Variant value) {
		switch (name) {
			case "outKernel": {
				depthOutKernel = value.get!(cstring);
			} break;

			default: {
				super.setParam(name, value);
			} break;
		}
	}


	// implements IKDefInvalidationObserver
	// TODO
	void onKDefInvalidated(KDefInvalidationInfo info) {
	}


	private {
		HashMap!(KernelImplId, EffectInfo) _structureEffectCache;
	}


	private EffectInfo buildStructureEffectForRenderable(RenderableId rid) {
		scope stack = new StackBuffer;

		EffectInfo effectInfo;
		final structureKernel = _kdefRegistry.getKernel(renderables.structureKernel[rid]);

		alias KernelGraph.NodeType NT;

		// ---- Build the Structure kernel graph

		BuilderSubgraphInfo structureInfo;
		
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

		bool removeNodeIfTypeMatches(GraphNodeId id, NT type) {
			if (type == kg.getNode(id).type) {
				kg.removeNode(id);
				return true;
			} else {
				return false;
			}
		}

		BuilderSubgraphInfo outInfo;
		{
			final kernel = _kdefRegistry.getKernel(depthOutKernel);
			GraphBuilder builder;
			builder.sourceKernelType = SourceKernelType.Undefined;
			builder.build(kg, kernel, &outInfo, stack);
			assert (outInfo.input.valid);
			assert (outInfo.output.valid);
		}

		final outNodesTopo = stack.allocArray!(GraphNodeId)(outInfo.nodes.length);
		findTopologicalOrder(kg.backend_readOnly, outInfo.nodes, outNodesTopo);

		fuseGraph(
			kg,
			outInfo.input,
			convCtx,
			outNodesTopo,
			
			// _findSrcParam
			delegate bool(
				Param* dstParam,
				GraphNodeId* srcNid,
				Param** srcParam
			) {
				switch (dstParam.name) {
					case "position": {
						return getOutputParamIndirect(
							kg,
							structureInfo.output,
							"position",
							srcNid,
							srcParam
						);
					}
					default: return false;
				}
			},

			OutputNodeConversion.Perform
		);

		kg.flow.removeAllAutoFlow();

		File.set("dgraph.dot", toGraphviz(kg));

		verifyDataFlowNames(kg);

		// ----

		final ctx = CodegenContext(&stack.allocRaw);

		CodegenSetup cgSetup;
		cgSetup.inputNode = structureInfo.input;
		cgSetup.outputNode = outInfo.output;

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
float farPlaneDistance <
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
			setUniform("farPlaneDistance", &farPlaneDistance);
		}

		// ----

		findEffectInfo(_backend, kg, &effectInfo);

		return effectInfo;
	}


	bool _getInterface(cstring name, AbstractFunction* func) {
		KernelImpl impl;
		if (	_kdefRegistry.getKernel(name, &impl)
			&&	impl.type == impl.type.Kernel
		) {
			*func = impl.kernel.func;
			return true;
		} else {
			return false;
		}		
	};
	

	private void compileStructureEffectsForRenderables(RenderableId[] rids) {
		foreach (idx, rid; rids) {
			if (!this._renderableValid.isSet(rid) || !_structureRenderableEI[rid].valid) {

				// compile the kernels, create an EffectInstance
				// TODO: cache Effects and only create new EffectInstances
				EffectInfo effectInfo;

				{
					final cacheKey = _kdefRegistry.getKernel(renderables.structureKernel[rid]).id;
					EffectInfo* info = cacheKey in _structureEffectCache;
					
					if (info !is null && info.effect !is null) {
						effectInfo = *info;
					} else {
						effectInfo = buildStructureEffectForRenderable(rid);
						if (info !is null) {
							// Must have been disposed earlier in whatever caused
							// the compilation of the effect anew
							assert (info.effect is null);
							*info = effectInfo;
						} else {
							_structureEffectCache[cacheKey] = effectInfo;
						}
					}
				}

				Effect effect = effectInfo.effect;
				assert (effect !is null);

				// ----

				EffectInstance efInst = _backend.instantiateEffect(effect);

				// HACK
				// all structure params should come from the asset
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
				 * HACK: bla bla, same story as in the forward and lpp renderers
				 */
				setEffectInstanceUniformDefaults(&effectInfo, efInst);

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
							_structureRenderableIndexData[rid] = id;
						}
				));

				if (_structureRenderableEI[rid].valid) {
					_structureRenderableEI[rid].dispose();
				}
				
				_structureRenderableEI[rid] = efInst;
				
				this._renderableValid.set(rid);
			}
		}
	}


	override void onRenderableCreated(RenderableId id) {
		super.onRenderableCreated(id);
		xf.utils.Memory.realloc(_structureRenderableIndexData, id+1);
		xf.utils.Memory.realloc(_structureRenderableEI, id+1);
	}


	override void render(ViewSettings vs, VSDRoot* vsd, RenderList* rlist) {
		this.viewToClip = vs.computeProjectionMatrix();
		this.clipToView = this.viewToClip.inverse();
		this.worldToView = vs.computeViewMatrix();
		this.worldToClip = this.viewToClip * this.worldToView;
		this.viewToWorld = this.worldToView.inverse();
		this.eyePosition = vec3.from(vs.eyeCS.origin);
		this.farPlaneDistance = vs.farPlaneDistance;

		final rids = rlist.list.renderableId[0..rlist.list.length];
		compileStructureEffectsForRenderables(rids);

		final origState = *_backend.state();
		
		scope (exit) {
			*_backend.state() = origState;
		}
			
		final blist = _backend.createRenderList();
		scope (exit) _backend.disposeRenderList(blist);

		foreach (idx, rid; rids) {
			final ei = _structureRenderableEI[rid];
			final bin = blist.getBin(ei.getEffect);
			final item = bin.add(ei);
			
			item.coordSys		= rlist.list.coordSys[idx];
			item.indexData		= *_structureRenderableIndexData[rid];
		}

		_backend.state.sRGB = false;
		_backend.state.depth.enabled = true;
		_backend.state.blend.enabled = false;
		_backend.state.depthClamp = false;
		_backend.render(blist);
	}


	private {
		EffectInstance[]	_structureRenderableEI;
		IndexData*[]		_structureRenderableIndexData;

		IKDefRegistry		_kdefRegistry;

		mat4	worldToView;
		mat4	worldToClip;
		mat4	viewToWorld;
		mat4	viewToClip;
		mat4	clipToView;
		vec3	eyePosition;
		float	farPlaneDistance;
	}
}
