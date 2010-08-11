module xf.nucled.PreviewRenderer;

private {
	import
		xf.Common,
		xf.nucleus.Defs,
		xf.nucleus.Value,
		xf.nucleus.Param,
		xf.nucleus.Function,
		xf.nucleus.Renderable,
		xf.nucleus.RendererMaterialData,
		xf.nucleus.IStructureData,
		xf.nucleus.RenderList,
		xf.nucleus.KernelImpl,
		xf.nucleus.KernelParamInterface,
		xf.nucleus.KernelCompiler,
		xf.nucleus.SurfaceDef,
		xf.nucleus.MaterialDef,
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


// BUG: this renderer is not created like the others, hence the stuff from
// Nucleus.createRenderer is not performed. Call it manually.
class MaterialPreviewRenderer {
	this (
		RendererBackend backend,
		IKDefRegistry kdefRegistry,
		cstring designatedOutputNode,
		cstring designatedOutputParam,
	) {
		_designatedOutputNode = designatedOutputNode;
		_designatedOutputParam = designatedOutputParam;
		_kdefRegistry = kdefRegistry;
		_backend = backend;
	}

	KernelImpl		structureToUse;
	MaterialDef		materialToUse;
	


	private EffectInfo buildEffect() {
		scope stack = new StackBuffer;

		EffectInfo effectInfo;

		final structureKernel	= structureToUse;
		final materialKernel	= materialToUse.materialKernel;

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
			builder.build(kg, structureKernel, &structureInfo, stack, null, true);
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

		GraphNodeId designatedOutputNid;

		{
			GraphBuilder builder;
			builder.sourceKernelType = SourceKernelType.Material;
			builder.build(kg, materialKernel, &materialInfo, stack,
				(cstring nname, GraphNodeId nid) {
					if (_designatedOutputNode == nname) {
						designatedOutputNid = nid;
					}
				},
				true
			);

			assert (materialInfo.input.valid);
		}

		assert (designatedOutputNid.valid);

		final materialNodesTopo = stack.allocArray!(GraphNodeId)(materialInfo.nodes.length);
		findTopologicalOrder(kg.backend_readOnly, materialInfo.nodes, materialNodesTopo);

		//File.set("graph.dot", toGraphviz(kg));

		/+fuseGraph(
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
		);+/

		foreach (param; &kg.getNode(structureInfo.output).getParamList.iterOutputs) {
			kg.flow.addDataFlow(
				structureInfo.output, param.name,
				materialInfo.input, param.name
			);
		}


		bool removeNodeIfTypeMatches(GraphNodeId id, NT type) {
			if (type == kg.getNode(id).type) {
				kg.removeNode(id);
				return true;
			} else {
				return false;
			}
		}

		final designatedParam = kg.getNode(designatedOutputNid)
			.getOutputParam(_designatedOutputParam);
			
		assert (designatedParam !is null, _designatedOutputParam);

		convertGraphDataFlow(
			kg,
			convCtx
		);

		auto outNid = kg.addNode(NT.Output);
		final outNode = kg.getNode(outNid).output.params
			.add(ParamDirection.In, "output");
		outNode.hasPlainSemantic = true;
		outNode.type = designatedParam.type;
		outNode.semantic.addTrait("use", "color");

		kg.flow.addDataFlow(
			designatedOutputNid, _designatedOutputParam,
			outNid, "output"
		);

		removeNodeIfTypeMatches(materialInfo.output, NT.Output);

		// For codegen below
		materialInfo.output = outNid;

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


	void compileEffects() {
		if (!_rebuildEIs) {
			return;
		}
		_rebuildEIs = false;
		
		EffectInfo effectInfo = buildEffect();
		Effect effect = effectInfo.effect;		

		// TODO: mem
		_renderableEI.length = _previewObjects.length;

		foreach (idx, obj; _previewObjects) {
			EffectInstance efInst = _backend.instantiateEffect(effect);
			assert (efInst.valid);

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

			//assert (false, "TODO");
			/+auto material = _materials[renderables.material[rid]];
			foreach (ref info; material.info) {
				char[256] fqn;
				sprintf(fqn.ptr, "material__%.*s", info.name);
				auto name = fromStringz(fqn.ptr);
				void** ptr = getInstUniformPtrPtr(name);
				if (ptr) {
					*ptr = material.data + info.offset;
				}
			}+/

			// ----

			obj.setKernelObjectData(
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
						_renderableIndexData = id;
					}
			));

			if (_renderableEI[idx].valid) {
				_renderableEI[idx].dispose();
			}
			
			_renderableEI[idx] = efInst;
		}

		foreach (ei; _renderableEI) {
			assert (ei.valid);
		}
	}

	
	void render(ViewSettings vs) {
		assert (!_rebuildEIs);

		this.viewToClip = vs.computeProjectionMatrix();
		this.worldToView = vs.computeViewMatrix();
		this.eyePosition = vec3.from(vs.eyeCS.origin);

		final origState = *_backend.state();
		scope (exit) {
			*_backend.state() = origState;
		}

		_backend.resetState();
		_backend.state.depth.enabled = true;
		_backend.state.viewport = origState.viewport;
		_backend.state.scissor = origState.scissor;

		final blist = _backend.createRenderList();
		scope (exit) _backend.disposeRenderList(blist);

		foreach (idx, obj; _previewObjects) {
			final ei = _renderableEI[idx];
			assert (ei.valid);

			final bin = blist.getBin(ei.getEffect);
			final item = bin.add(ei);

			// TODO
			item.coordSys		= CoordSys.identity;//rlist.list.coordSys[idx];
			item.indexData		= *_renderableIndexData;
		}

		_backend.render(blist);
	}


	void setObjects(IStructureData[] obj) {
		_previewObjects = obj;
		_rebuildEIs = true;
	}


	private {
		RendererBackend		_backend;
		
		// HACK
		EffectInstance[]	_renderableEI;
		IndexData*			_renderableIndexData;

		IStructureData[]	_previewObjects;
		bool				_rebuildEIs = true;

		IKDefRegistry		_kdefRegistry;

		mat4	worldToView;
		mat4	viewToClip;
		vec3	eyePosition;

		cstring	_designatedOutputNode;
		cstring	_designatedOutputParam;
	}
}
