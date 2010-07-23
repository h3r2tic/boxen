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
		xf.nucleus.MaterialDef,
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
}



class DepthRenderer : Renderer {
	mixin MRenderer!("Depth");


	this (RendererBackend backend, IKDefRegistry kdefRegistry) {
		assert (kdefRegistry !is null);
		_kdefRegistry = kdefRegistry;
		_structureEffectCache = new typeof(_structureEffectCache);
		super(backend);
	}


	private {
	override void registerSurface() {
		// nothing
	}


	// implements IKDefInvalidationObserver
	// TODO
	void onKDefInvalidated(KDefInvalidationInfo info) {
	}


	private {
		HashMap!(cstring, EffectInfo) _structureEffectCache;
	}


	private EffectInfo buildStructureEffectForRenderable(RenderableId rid) {
		scope stack = new StackBuffer;

		EffectInfo effectInfo;

		SurfaceId surfaceId = renderables.surface[rid];
		auto surface = &_surfaces[surfaceId];

		MaterialId materialId = renderables.material[rid];
		auto material = _materials[materialId];

		final structureKernel	= _kdefRegistry.getKernel(renderables.structureKernel[rid]);
		final pigmentKernel		= _kdefRegistry.getKernel(material.kernelName);
		final illumKernel		= _kdefRegistry.getKernel(surface.kernelName);

		alias KernelGraph.NodeType NT;

		// ---- Build the Structure kernel graph

		BuilderSubgraphInfo structureInfo;
		BuilderSubgraphInfo pigmentInfo;
		
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

		void buildPigmentGraph() {
			GraphBuilder builder;
			builder.sourceKernelType = SourceKernelType.Pigment;
			builder.build(kg, pigmentKernel, &pigmentInfo, stack);

			assert (pigmentInfo.input.valid);
		}


		buildPigmentGraph();

		final pigmentNodesTopo = stack.allocArray!(GraphNodeId)(pigmentInfo.nodes.length);
		findTopologicalOrder(kg.backend_readOnly, pigmentInfo.nodes, pigmentNodesTopo);

		//File.set("graph.dot", toGraphviz(kg));

		fuseGraph(
			kg,
			pigmentInfo.input,
			convCtx,
			pigmentNodesTopo,
			
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

			OutputNodeConversion.Skip
		);


		bool removeNodeIfTypeMatches(GraphNodeId id, NT type) {
			if (type == kg.getNode(id).type) {
				kg.removeNode(id);
				return true;
			} else {
				return false;
			}
		}

		final surfIdDataNid = kg.addNode(NT.Data);
		final surfIdDataNode = kg.getNode(surfIdDataNid).data(); {
			surfIdDataNode.sourceKernelType = SourceKernelType.Composite;
			
			final param = surfIdDataNode.params.add(ParamDirection.Out, "surfaceId");
			param.hasPlainSemantic = true;
			param.type = "float";
		}

		BuilderSubgraphInfo outInfo;
		{
			final kernel = _kdefRegistry.getKernel("LightPrePassGeomOut");
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

					case "normal": {
						return getOutputParamIndirect(
							kg,
							pigmentInfo.output,
							"out_normal",
							srcNid,
							srcParam
						);
					}

					case "surfaceId": {
						*srcNid = surfIdDataNid;
						*srcParam = surfIdDataNode.params
							.getOutput("surfaceId");
						return true;
					}

					default: return false;
				}
			},

			OutputNodeConversion.Perform
		);

		kg.flow.removeAllAutoFlow();

		File.set("graph.dot", toGraphviz(kg));

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
			setUniform("farPlaneDistance", &farPlaneDistance);
		}

		// ----

		findEffectInfo(kg, &effectInfo);

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
					final cacheKey = renderables.structureKernel[rid];
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
				setEffectInstanceUniformDefaults(&effectInfo, efInst);


				{
					SurfaceId surfaceId = renderables.surface[rid];
					// 0-255 -> 0-1
					float si = (cast(float)surfaceId + 0.5f) / 255.0f;
					
					if (void** ptr = efInst.getUniformPtrPtr("surfaceId")) {
						**cast(float**)ptr = si;
					} else {
						error("surfaceId not found in the structure kernel.");
					}
				}


				// ----

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
		xf.utils.Memory.realloc(_structureRenderableEI, id+1);
	}


	override void render(ViewSettings vs, RenderList* rlist) {
		this.viewToClip = vs.computeProjectionMatrix();
		this.clipToView = this.viewToClip.inverse();
		this.worldToView = vs.computeViewMatrix();
		this.worldToClip = this.viewToClip * this.worldToView;
		this.viewToWorld = this.worldToView.inverse();
		this.eyePosition = vec3.from(vs.eyeCS.origin);
		this.farPlaneDistance = vs.farPlaneDistance;

		if (_fbSize != _backend.framebuffer.size) {
			_fbSize = _backend.framebuffer.size;

			if (_depthTex.valid) {
				_depthTex.dispose();
				_packed1Tex.dispose();
				_attribFB.dispose();
				_diffuseIllumTex.dispose();
				_specularIllumTex.dispose();
				_lightFB.dispose();
			}

			{
				TextureRequest treq;
				treq.internalFormat = TextureInternalFormat.RGBA_FLOAT16;
				treq.minFilter = TextureMinFilter.Nearest;
				treq.magFilter = TextureMagFilter.Nearest;
				treq.wrapS = TextureWrap.ClampToEdge;
				treq.wrapT = TextureWrap.ClampToEdge;
				
				_packed1Tex = _backend.createTexture(
					_fbSize,
					treq
				);
				assert (_packed1Tex.valid);
			}

			{
				TextureRequest treq;
				treq.internalFormat = TextureInternalFormat.DEPTH_COMPONENT32F;
				treq.minFilter = TextureMinFilter.Nearest;
				treq.magFilter = TextureMagFilter.Nearest;
				treq.wrapS = TextureWrap.ClampToEdge;
				treq.wrapT = TextureWrap.ClampToEdge;
				
				_depthTex = _backend.createTexture(
					_fbSize,
					treq
				);
				assert (_depthTex.valid);
			}

			{
				TextureRequest treq;
				treq.internalFormat = TextureInternalFormat.RGBA_FLOAT16;
				treq.minFilter = TextureMinFilter.Nearest;
				treq.magFilter = TextureMagFilter.Nearest;
				treq.wrapS = TextureWrap.ClampToEdge;
				treq.wrapT = TextureWrap.ClampToEdge;
				
				_diffuseIllumTex = _backend.createTexture(
					_fbSize,
					treq
				);
				assert (_diffuseIllumTex.valid);
				_specularIllumTex = _backend.createTexture(
					_fbSize,
					treq
				);
				assert (_specularIllumTex.valid);
			}

			{
				final cfg = FramebufferConfig();
				cfg.size = _fbSize;
				cfg.location = FramebufferLocation.Offscreen;
				cfg.color[0] = _packed1Tex;
				cfg.depth = _depthTex;
				_attribFB = _backend.createFramebuffer(cfg);
				assert (_attribFB.valid);
			}

			{
				final cfg = FramebufferConfig();
				cfg.size = _fbSize;
				cfg.location = FramebufferLocation.Offscreen;
				cfg.color[0] = _diffuseIllumTex;
				cfg.color[1] = _specularIllumTex;
				//cfg.depth = TODO
				_lightFB = _backend.createFramebuffer(cfg);
				assert (_lightFB.valid);
			}
		}

		final rids = rlist.list.renderableId[0..rlist.list.length];
		compileStructureEffectsForRenderables(rids);
		compileFinalEffectsForRenderables(rids);

		final outputFB = _backend.framebuffer;
		final origState = *_backend.state();
		
		if (outputFB.acquire()) {
			scope (exit) {
				_backend.framebuffer = outputFB;
				outputFB.dispose();
				*_backend.state() = origState;
			}
			
			_backend.framebuffer = _attribFB;
			_backend.clearBuffers();

			final blist = _backend.createRenderList();
			scope (exit) _backend.disposeRenderList(blist);

			foreach (idx, rid; rids) {
				final ei = _structureRenderableEI[rid];
				final bin = blist.getBin(ei.getEffect);
				final item = bin.add(ei);
				
				item.coordSys		= rlist.list.coordSys[idx];
				item.scale			= vec3.one;
				item.indexData		= *_structureRenderableIndexData[rid];
				item.numInstances	= 1;
			}

			_backend.state.sRGB = false;
			_backend.state.depth.enabled = true;
			_backend.state.blend.enabled = false;
			_backend.render(blist);

			_backend.state.depthClamp = true;
			with (_backend.state.cullFace) {
				enabled = true;
				front = true;
				back = false;
			}

			// HACK
			_backend.state.depth.enabled = false;
			_backend.framebuffer = _lightFB;
			_backend.clearBuffers();

			with (_backend.state.blend) {
				enabled = true;
				src = Factor.One;
				dst = Factor.One;
			}

			renderLights(.lights);
		}

		final blist = _backend.createRenderList();
		scope (exit) _backend.disposeRenderList(blist);

		foreach (idx, rid; rids) {
			final ei = _finalRenderableEI[rid];
			final bin = blist.getBin(ei.getEffect);
			final item = bin.add(ei);
			
			item.coordSys		= rlist.list.coordSys[idx];
			item.scale			= vec3.one;
			item.indexData		= *_structureRenderableIndexData[rid];
			item.numInstances	= 1;
		}
		_backend.render(blist);
	}


	private {
		EffectInstance[]	_structureRenderableEI;

		IKDefRegistry		_kdefRegistry;

		vec2i		_fbSize = vec2i.zero;
		Texture		_depthTex;
		Framebuffer	_attribFB;

		Texture		_surfaceParamTex;

		Texture		_diffuseIllumTex;
		Texture		_specularIllumTex;
		Framebuffer	_lightFB;

		mat4	worldToView;
		mat4	worldToClip;
		mat4	viewToWorld;
		mat4	viewToClip;
		mat4	clipToView;
		vec3	eyePosition;
		float	farPlaneDistance;
	}
}
