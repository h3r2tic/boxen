module xf.nucleus.renderer.LightPrePassRenderer;

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
		xf.nucleus.util.EffectInfo,
		xf.nucleus.StdUniforms;

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
		xf.omg.core.Misc,
		xf.omg.util.ViewSettings,
		xf.mem.StackBuffer,
		xf.mem.MainHeap,
		xf.mem.ScratchAllocator,
		xf.mem.ChunkQueue,
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




class LightPrePassRenderer : Renderer {
	mixin MRenderer!("LightPrePass");

	enum {
		maxSurfaceParams = 8,
		maxSurfaces = 256,
		maxLights = 16*1024		// arbitrary
	}

	mixin MStdUniforms;

	
	this (RendererBackend backend, IKDefRegistry kdefRegistry) {
		assert (kdefRegistry !is null);
		_kdefRegistry = kdefRegistry;
		_structureEffectCache = new typeof(_structureEffectCache);
		_finalEffectCache = new typeof(_finalEffectCache);
		super(backend);
		createSurfaceParamTex();
		createLightParamBuf();
	}


	private void createSurfaceParamTex() {
		TextureRequest treq;
		treq.internalFormat = TextureInternalFormat.RGBA_FLOAT32;
		treq.minFilter = TextureMinFilter.Nearest;
		treq.magFilter = TextureMagFilter.Nearest;
		treq.wrapS = TextureWrap.ClampToEdge;
		treq.wrapT = TextureWrap.ClampToEdge;
		
		_surfaceParamTex = _backend.createTexture(
			vec2i(maxSurfaceParams, maxSurfaces),
			treq
		);
		assert (_surfaceParamTex.valid);
	}


	private void createLightParamBuf() {
		_vb = _backend.createVertexBuffer(
			BufferUsage.StaticDraw,
			maxLights * vec4.sizeof,
			null
		);
		_va = VertexAttrib(
			0,
			vec4.sizeof,
			VertexAttrib.Type.Vec4
		);
		_ib = _backend.createIndexBuffer(
			BufferUsage.StaticDraw,
			maxLights * u32.sizeof,
			null,
			IndexType.U32
		);
	}


	private {
		struct SurfaceData {
			struct Info {
				cstring	name;		// stringz
				void*	ptr;
			}
			
			Info[]			info;
			KernelImplId	kernelId;
			ScratchFIFO		_mem;
			ubyte			reflIdx;

			void dispose() {
				_mem.dispose();
				info = null;
				kernelId = KernelImplId.invalid;
			}
		}

		struct ReflData {
			KernelImplId	kernelId;
			//cstring			kernelName;
			KernelGraph		graph;
			GraphNodeId[]	topological;		// allocated off the KernelGraph's allocator
			GraphNodeId		input;
			GraphNodeId		output;
			ParamList*		dataNodeParams;

			void dispose() {
				disposeKernelGraph(graph);
				dataNodeParams = null;
				// TODO(?)
			}

			int inputs(int delegate(ref int, ref Param) sink) {
				final inputNode = graph.getNode(input);
				assert (inputNode !is null);
				
				if (KernelGraph.NodeType.Input == inputNode.type) {
					return inputNode.input().params.opApply(sink);
				} else {
					int i = 0;
					foreach (ref p; *inputNode.getParamList()) {
						if (p.isInput()) {
							if (int r = sink(i, p)) return r;
							++i;
						}
					}
					return 0;
				}
			}

			int outputs(int delegate(ref int, ref Param) sink) {
				final outputNode = graph.getNode(output);
				assert (outputNode !is null);
				
				if (KernelGraph.NodeType.Output == outputNode.type) {
					return outputNode.output().params.opApply(sink);
				} else {
					int i = 0;
					foreach (ref p; *outputNode.getParamList()) {
						if (p.isOutput()) {
							if (int r = sink(i, p)) return r;
							++i;
						}
					}
					return 0;
				}
			}

		}

		SurfaceData[256]	_surfaces;
		ReflData[256]		_reflDataBuf;
		uint				_numReflData;

		ReflData[] _reflData() {
			return _reflDataBuf[0.._numReflData];
		}
	}


	// TODO
	override void registerSurface(SurfaceDef def) {
		auto surf = &_surfaces[def.id];
		if (surf.info) surf.dispose();

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

		bool reflFound = false;
		foreach (ubyte i, ref refl; _reflData) {
			if (refl.kernelId == surf.kernelId) {
				if (surf.reflIdx != i) {
					// when updating the surface with a new kernel
					_invalidateLightEffect = true;
				}
				surf.reflIdx = i;
				reflFound = true;
				break;
			}
		}

		if (!reflFound) {
			_invalidateLightEffect = true;
			
			{
				uint idx = _numReflData++;
				assert (idx < 256);
				surf.reflIdx = cast(ubyte)idx;
			}
			auto refl = &_reflData[surf.reflIdx];

			refl.kernelId = surf.kernelId;

			refl.graph = createKernelGraph();
			GraphBuilder builder;
			builder.sourceKernelType = SourceKernelType.Composite;

			BuilderSubgraphInfo info;
			builder.build(refl.graph, def.reflKernel, &info, null);

			ConvCtx convCtx;
			convCtx.semanticConverters = &_kdefRegistry.converters;
			convCtx.getKernel = &_kdefRegistry.getKernel;

			convertGraphDataFlow(
				refl.graph,
				convCtx
			);

			removeUnreachableBackwards(refl.graph.backend_readOnly, info.output);
			simplifyKernelGraph(refl.graph);

			refl.input = info.input;
			refl.output = info.output;

			refl.topological = DgScratchAllocator(&refl.graph._mem.pushBack)
				.allocArrayNoInit!(GraphNodeId)(refl.graph.numNodes);

			findTopologicalOrder(refl.graph.backend_readOnly, refl.topological);

			bool dataNodeFound = false;
			foreach (n; refl.graph.iterNodes(KernelGraph.NodeType.Data)) {
				assert (
					!dataNodeFound,
					"Only one Data node currently allowed for refl kernels. Lazy."
				);
				refl.dataNodeParams = refl.graph.getNode(n).getParamList();
				dataNodeFound = true;
			}
		}

		vec4 texel;

		texel = vec4[cast(float)surf.reflIdx / (maxSurfaces-1), 0, 0, 0];
		_backend.updateTexture(
			_surfaceParamTex,
			vec2i(0, def.id),
			vec2i(1, 1),
			&texel.x
		);

		auto refl = &_reflData[surf.reflIdx];

		if (refl.dataNodeParams) foreach (i, dnp; *refl.dataNodeParams) {
			if (auto p = def.params.get(dnp.name)) {
				assert (p.valueSize < 16);
				memcpy(&texel.x, p.value, p.valueSize);

				_backend.updateTexture(
					_surfaceParamTex,
					vec2i(i+1, def.id),
					vec2i(1, 1),
					&texel.x
				);
			}
		}
	}


	protected void unregisterSurfaces() {
		foreach (ref surf; _surfaces) {
			surf.dispose();
		}
	}


	// implements IKDefInvalidationObserver
	// TODO
	void onKDefInvalidated(KDefInvalidationInfo info) {
		foreach (ref rd; _reflData) {
			rd.dispose();
		}
		_numReflData = 0;
		unregisterMaterials();
		_renderableValid.clearAll();
		

		scope stack = new StackBuffer;
		mixin MSmallTempArray!(Effect) toDispose;
		
		if (info.anyConverters) {
			foreach (eck, ref einfo; _finalEffectCache) {
				if (einfo.isValid) {
					toDispose.pushBack(einfo.effect, &stack.allocRaw);
					einfo.dispose();
				}
			}

			foreach (eck, ref einfo; _structureEffectCache) {
				if (einfo.isValid) {
					toDispose.pushBack(einfo.effect, &stack.allocRaw);
					einfo.dispose();
				}
			}
		} else {
			foreach (eck, ref einfo; _finalEffectCache) {
				if (einfo.isValid) {
					if (
							!_kdefRegistry.getKernel(eck.materialKernel).isValid
						||	!_kdefRegistry.getKernel(eck.structureKernel).isValid
					) {
						toDispose.pushBack(einfo.effect, &stack.allocRaw);
						einfo.dispose();
					}
				}
			}

			foreach (eck, ref einfo; _structureEffectCache) {
				if (!_kdefRegistry.getKernel(eck).isValid) {
					toDispose.pushBack(einfo.effect, &stack.allocRaw);
					einfo.dispose();
				}
			}
		}

		foreach (ref ei; _structureRenderableEI) {
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

		foreach (ref ei; _finalRenderableEI) {
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


		_invalidateLightEffect = true;
	}


	private {
		struct FinalEffectCacheKey {
			KernelImplId	materialKernel;
			KernelImplId	structureKernel;
			//hash_t			hash;

			void computeHash() {
				/+hash = 0;
				hash += materialKernel.value;
				hash *= 7;
				hash += structureKernel.value;+/
			}

			/+hash_t toHash() {
				return hash;
			}

			bool opEquals(ref FinalEffectCacheKey other) {
				return
						materialKernel == other.materialKernel
					&&	structureKernel == other.structureKernel;
			}+/
		}

		private {
			HashMap!(FinalEffectCacheKey, EffectInfo) _finalEffectCache;
		}

		HashMap!(KernelImplId, EffectInfo) _structureEffectCache;
	}


	private EffectInfo buildStructureEffectForRenderable(RenderableId rid) {
		scope stack = new StackBuffer;

		EffectInfo effectInfo;

		SurfaceId surfaceId = renderables.surface[rid];
		auto surface = &_surfaces[surfaceId];

		MaterialId materialId = renderables.material[rid];
		auto material = _materials[materialId];

		final structureKernel	= _kdefRegistry.getKernel(renderables.structureKernel[rid]);
		final materialKernel	= _kdefRegistry.getKernel(*_materialKernels[materialId]);
		final reflKernel		= _kdefRegistry.getKernel(surface.kernelId);

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
			builder.build(kg, materialKernel, &materialInfo, stack, null, true);

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
							materialInfo.output,
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
			_kdefRegistry,
			(CodeSink fmt) {
				fmt(stdUniformsCg);
			}
		);

		// ----

		effect.compile();

		// HACK
		allocateDefaultUniformStorage(effect);

		bindStdUniforms(effect);

		// ----

		findEffectInfo(_backend, kg, &effectInfo);

		return effectInfo;
	}


	private EffectInfo buildLightEffect(cstring lightKernel) {
		scope stack = new StackBuffer;

		EffectInfo effectInfo;

		alias KernelGraph.NodeType NT;

		ConvCtx convCtx;
		convCtx.semanticConverters = &_kdefRegistry.converters;
		convCtx.getKernel = &_kdefRegistry.getKernel;

		auto kg = createKernelGraph();
		scope (exit) {
			disposeKernelGraph(kg);
		}

		bool removeNodeIfTypeMatches(GraphNodeId id, NT type) {
			if (type == kg.getNode(id).type) {
				kg.removeNode(id);
				return true;
			} else {
				return false;
			}
		}

		GraphNodeId gsNode;

		BuilderSubgraphInfo inInfo;
		{
			final kernel = _kdefRegistry.getKernel("LightPrePassLightIn");
			GraphBuilder builder;
			builder.sourceKernelType = SourceKernelType.Structure;
			builder.build(kg, kernel, &inInfo, stack, (cstring name, GraphNodeId nid) {
				if ("rast" == name) {
					gsNode = nid;
				}
			});
			assert (inInfo.input.valid);
			assert (inInfo.output.valid);
		}
		assert (gsNode.valid);

		convertGraphDataFlowExceptOutput(
			kg,
			convCtx
		);

		BuilderSubgraphInfo lightInfo;
		{
			final kernel = _kdefRegistry.getKernel(lightKernel);
			GraphBuilder builder;
			builder.sourceKernelType = SourceKernelType.Light;
			builder.sourceLightIndex = 0;
			builder.build(kg, kernel, &lightInfo, stack);
			assert (lightInfo.input.valid);
			assert (lightInfo.output.valid);
		}

		auto lightNodesTopo = stack.allocArray!(GraphNodeId)(lightInfo.nodes.length);
		findTopologicalOrder(kg.backend_readOnly, lightInfo.nodes, lightNodesTopo);

		fuseGraph(
			kg,
			lightInfo.input,
			convCtx,
			lightNodesTopo,
			
			// _findSrcParam
			delegate bool(
				Param* dstParam,
				GraphNodeId* srcNid,
				Param** srcParam
			) {
				switch (dstParam.name) {
					case "position":
						return getOutputParamIndirect(
							kg,
							inInfo.output,
							"position",
							srcNid,
							srcParam
						);

					default:
						assert (false, dstParam.name);
				}
			},
			
			OutputNodeConversion.Skip
		);

		// Codegen the BRDF

		final ctx = CodegenContext(&stack.allocRaw);
		const prealloc = 128 * 1024;	// 128KB should be enough for anyone :P
		auto layout = Layout!(char).instance;
		scope arrrr = new Array(stack.allocArrayNoInit!(char)(prealloc), 0);
		scope fmt = new FormatOutput!(char)(layout, arrrr, "\n");
		ctx.sink = fmt;

		final BRDFfunc = codegenBRDF(stack, kg, &ctx);

		// ----

		final BRDFnode = kg.addFuncNode(BRDFfunc);
		void connectIndirect(GraphNodeId src, cstring srcParam, cstring dstParam) {
			Param* p;
			GraphNodeId nid;
			if (getOutputParamIndirect(
				kg,
				src,
				srcParam,
				&nid,
				&p
			)) {
				kg.flow.addDataFlow(nid, p.name, BRDFnode, dstParam);
			} else {
				error("Source for {} not found.", dstParam);
			}
		}
		
		connectIndirect(inInfo.output, "position", "toEye");
		connectIndirect(inInfo.output, "normal", "normal");
		connectIndirect(inInfo.output, "getSurfaceParam", "getSurfaceParam");
		
		connectIndirect(lightInfo.output, "intensity", "intensity");
		connectIndirect(lightInfo.output, "toLight", "toLight");
		connectIndirect(lightInfo.output, "lightSize", "lightSize");

		removeNodeIfTypeMatches(inInfo.output, NT.Output);
		removeNodeIfTypeMatches(lightInfo.output, NT.Output);

		convertGraphDataFlow(kg, convCtx);

		kg.flow.removeAllAutoFlow();

		File.set("graph.dot", toGraphviz(kg));

		verifyDataFlowNames(kg);

		// ----

		fmt(stdUniformsCg);

		// ----

		CodegenSetup cgSetup;
		cgSetup.inputNode = inInfo.input;
		cgSetup.outputNode = BRDFnode;
		cgSetup.gsNode = gsNode;

		codegen(
			stack,
			kg,
			cgSetup,
			&ctx,
			_kdefRegistry
		);

		fmt.flush();
		char[1] zero = '\0';
		arrrr.write(zero[]);

		File.set("lshader.tmp.cgfx", arrrr.slice());

		EffectCompilationOptions ecopts;
		ecopts.useGeometryProgram = true;
		ecopts.geomProgramInput = GeomProgramInput.Point;
		ecopts.geomProgramOutput = GeomProgramOutput.Triangle;
		final effect = effectInfo.effect = _backend.createEffect(
			null,
			EffectSource.stringz(cast(char*)arrrr.slice().ptr),
			ecopts
		);

		effect.compile();

		// HACK
		allocateDefaultUniformStorage(effect);

		bindStdUniforms(effect);

		// ----

		findEffectInfo(_backend, kg, &effectInfo);

		return effectInfo;
	}



	private {
		import tango.io.stream.Format;
		import tango.io.device.Array;
		import tango.text.convert.Layout;
		import tango.io.device.File;
	}


	void dumpBRDFs(CodegenContext* ctx, SubgraphData[][] graphs) {
		auto fmt = ctx.sink;
		
		foreach (reflIdx, refl; _reflData) {
			fmt("struct BRDF__")(reflIdx)(" {");
			fmt("\t// ")(_kdefRegistry.getKernel(refl.kernelId).name);
			fmt.newline;

			final inputNode = refl.graph.getNode(refl.input);
			final outputNode = refl.graph.getNode(refl.output);

			dumpUniforms(ctx, refl.graph, fmt);

			// ---- func body ----
			{
				fmt.formatln("void main(");

				uint parIdx = 0;
				foreach (i, par; &refl.inputs) {
					assert (par.hasTypeConstraint);

					if (parIdx++ != 0) {
						fmt(",").newline;
						ctx.indent(1);
					}

					fmt("in ");
					fmt(par.type);
					fmt(" ");
					emitSourceParamName(ctx, refl.graph, null, refl.input, par.name);
				}
				
				foreach (i, par; &refl.outputs) {
					assert (par.hasTypeConstraint);

					if (parIdx++ != 0) {
						fmt(",").newline;
						ctx.indent(1);
					}

					fmt("out ");
					fmt(par.type);
					fmt(" ");
					fmt.format("bridge__{}", i);
				}

				fmt(") {").newline();

				domainCodegenBody(
					ctx,
					refl.graph,
					null,
					refl.topological,
					graphs[reflIdx][0].node2funcName,
					graphs[reflIdx][0].node2compName
				);

				foreach (i, par; &refl.outputs) {
					GraphNodeId	srcNid;
					Param*		srcParam;

					if (!getOutputParamIndirect(
						refl.graph,
						refl.output,
						par.name,
						&srcNid,
						&srcParam
					)) {
						error(
							"No flow to {}.{}. Should have been caught earlier.",
							refl.output,
							par.name
						);
					}

					fmt.format("\tbridge__{} = ", i);
					emitSourceParamName(ctx, refl.graph, null, srcNid, srcParam.name);
					fmt(';').newline();
				}

				fmt("}").newline();
			}
			// ---- end of func body ----
			
			fmt("};").newline;
		}
	}


	void codegenBRDFEval(
		StackBufferUnsafe stack,
		CodegenContext* ctx
	) {
		final fmt = ctx.sink;

		fmt("if (all(intensity <= float4(0.00001))) { discard; }").newline;

		void surfParam(int i) {
			fmt.format(
				"getSurfaceParam.value({:f.16})",
				(cast(float)i + 1.5f) / maxSurfaceParams
			);
		}

		void reflIdxBranch(int i, void delegate() dg) {
			if (i > 0) {
				fmt("else ");
			}
			
			fmt.formatln(
				"if (brdf__Index < {:f.16}) {{",
				(cast(float)i + 0.5f) / maxSurfaces
			).newline;

			dg();

			fmt.newline()('}');
		}
		
		fmt("float brdf__Index = ");
		surfParam(-1);
		fmt(".x;").newline;

		foreach (reflIdx, refl; _reflData) {
			reflIdxBranch(reflIdx, {
				fmt("BRDF__")(reflIdx)(" brdf__inst;");
				if (refl.dataNodeParams) foreach (i, param; *refl.dataNodeParams) {
					fmt.format("brdf__inst.{} = ", param.name);
					surfParam(i);
					switch (param.type) {
						case "float":
							fmt(".x"); break;
						case "float2":
							fmt(".xy"); break;
						case "float3":
							fmt(".xyz"); break;
						default: break;
					}
					fmt(';').newline;
				}
				fmt("brdf__inst.main(normal, intensity, lightSize, toLight, toEye, diffuse, specular);");
			});
		}

		fmt("else { diffuse = float4(1, 0, 1, 0); specular = float4(1, 0, 1, 0); }").newline;

		//fmt("diffuse = brdf__Index * 128;");
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
	

	Function codegenBRDF(
		StackBufferUnsafe stack,
		KernelGraph kg,
		CodegenContext* ctx
	) {
		final graphs = stack.allocArray!(SubgraphData[])(_reflData.length);

		ctx.domain = GPUDomain.Fragment;
		ctx.getInterface = &_getInterface;

		foreach (reflIdx, refl; _reflData) {
			graphs[reflIdx] = emitCompositesAndFuncs(
				stack,
				ctx,
				refl.graph
			);
		}

		dumpBRDFs(ctx, graphs);

		Code code;
		void codeAppend(void[] meh) {
			code.append(cast(char[])meh, DgScratchAllocator(&stack.allocRaw));
		}

		auto layout = Layout!(char).instance;
		scope fmt2 = new FormatOutput!(char)(
			layout,
			new DgOutputStream(&codeAppend),
			"\n"
		);

		final fmt1 = ctx.sink;

		ctx.sink = fmt2;

		codegenBRDFEval(stack, ctx);
		
		fmt2.flush();
		ctx.sink = fmt1;

		final func = stack._new!(Function)("BRDF__eval"[], cast(cstring[])null, code, &stack.allocRaw);
		func.params.copyFrom(_kdefRegistry.getKernel("Reflectance").kernel.func.params);
		{
			auto p = func.params.add(ParamDirection.In, "getSurfaceParam");
			p.hasPlainSemantic = true;
			p.type = "LPP_GetSurfaceParam";
		}

		return func;
	}


	private EffectInfo buildFinalEffectForRenderable(RenderableId rid) {
		scope stack = new StackBuffer;

		EffectInfo effectInfo;

		SurfaceId surfaceId = renderables.surface[rid];
		auto surface = &_surfaces[surfaceId];

		MaterialId materialId = renderables.material[rid];
		auto material = _materials[materialId];

		final structureKernel	= _kdefRegistry.getKernel(renderables.structureKernel[rid]);
		final materialKernel	= _kdefRegistry.getKernel(*_materialKernels[materialId]);
		final reflKernel		= _kdefRegistry.getKernel(surface.kernelId);

		alias KernelGraph.NodeType NT;

		// ---- Build the Structure kernel graph

		BuilderSubgraphInfo structureInfo;
		BuilderSubgraphInfo materialInfo;
		
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
			final kernel = _kdefRegistry.getKernel("LightPrePassFinalOut");
			GraphBuilder builder;
			builder.sourceKernelType = SourceKernelType.Material;
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

					case "albedo": {
						return getOutputParamIndirect(
							kg,
							materialInfo.output,
							"out_albedo",
							srcNid,
							srcParam
						);
					}

					case "specular": {
						return getOutputParamIndirect(
							kg,
							materialInfo.output,
							"out_specular",
							srcNid,
							srcParam
						);
					}

					case "emissive": {
						return getOutputParamIndirect(
							kg,
							materialInfo.output,
							"out_emissive",
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
			_kdefRegistry,
			(CodeSink fmt) {
				fmt(stdUniformsCg);
			}
		);

		// ----

		effect.compile();

		// HACK
		allocateDefaultUniformStorage(effect);

		bindStdUniforms(effect);

		// ----

		findEffectInfo(_backend, kg, &effectInfo);

		return effectInfo;
	}


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


				pragma (msg, "do this for modified materials even when stuff is not re-compiled");

				{
					SurfaceId surfaceId = renderables.surface[rid];
					float si = (cast(float)surfaceId + 0.5f) / maxSurfaces;
					
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
					sprintf(fqn.ptr, "material__%.*s", info.name);
					auto name = fromStringz(fqn.ptr);
					void** ptr = getInstUniformPtrPtr(name);
					if (ptr) {
						*ptr = info.ptr;
					}
				}

				// ----

				_structureRenderableIndexData[rid] = null;

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
			}
		}
	}


	private void compileFinalEffectsForRenderables(RenderableId[] rids) {
		foreach (idx, rid; rids) {
			if (!this._renderableValid.isSet(rid) || !_finalRenderableEI[rid].valid) {

				// compile the kernels, create an EffectInstance
				// TODO: cache Effects and only create new EffectInstances
				EffectInfo effectInfo;

				{
					MaterialId materialId = renderables.material[rid];
					auto material = _materials[materialId];

					final cacheKey = FinalEffectCacheKey(
						*_materialKernels[materialId],
						_kdefRegistry.getKernel(renderables.structureKernel[rid]).id
					);
					cacheKey.computeHash();
					
					EffectInfo* info = cacheKey in _finalEffectCache;
					
					if (info !is null && info.effect !is null) {
						effectInfo = *info;
					} else {
						effectInfo = buildFinalEffectForRenderable(rid);
						if (info !is null) {
							// Must have been disposed earlier in whatever caused
							// the compilation of the effect anew
							assert (info.effect is null);
							*info = effectInfo;
						} else {
							_finalEffectCache[cacheKey] = effectInfo;
						}
					}
				}

				Effect effect = effectInfo.effect;
				assert (effect !is null);

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


				if (void** ptr = efInst.getUniformPtrPtr("material__diffuseIlluminationSampler")) {
					*cast(Texture**)ptr = &_diffuseIllumTex;
				} else {
					//error("diffuseIlluminationSampler not found in the structure kernel.");
				}

				if (void** ptr = efInst.getUniformPtrPtr("material__specularIlluminationSampler")) {
					*cast(Texture**)ptr = &_specularIllumTex;
				} else {
					//error("specularIlluminationSampler not found in the structure kernel.");
				}


				// ----

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
							/+log.info("_renderableIndexData[{}] = {};", rid, id);
							_finalRenderableIndexData[rid] = id;+/
						}
				));

				if (_finalRenderableEI[rid].valid) {
					_finalRenderableEI[rid].dispose();
				}
				
				_finalRenderableEI[rid] = efInst;
				
				this._renderableValid.set(rid);
			}
		}
	}


	override void onRenderableCreated(RenderableId id) {
		super.onRenderableCreated(id);
		xf.utils.Memory.realloc(_structureRenderableEI, id+1);
		xf.utils.Memory.realloc(_structureRenderableIndexData, id+1);
		xf.utils.Memory.realloc(_finalRenderableEI, id+1);
	}


	// TODO
	override void onLightCreated(LightId lightId) {
		if (lightId >= maxLights) {
			// HACK
			error("Increase the maxLights constant in the LightPrePassRenderer.");
		}
		
		assert (lightEI.length == lightId);
		lightEI ~= EffectInstance.init;
	}
	
	// TODO
	override void onLightDisposed(LightId) {
		assert (false, "TODO");
	}
	
	// TODO
	override void onLightInvalidated(LightId) {
	}


	EffectInstance[]	lightEI;
	EffectInfo			lightEffectInfo;
	bool				_invalidateLightEffect = false;


	VertexBuffer	_vb;
	VertexAttrib	_va;
	IndexBuffer		_ib;
	

	void renderLights(Light[] lights) {
		if (_invalidateLightEffect) {
			if (lightEffectInfo.isValid) {
				_invalidateLightEffect = false;
				
				foreach (ref ei; lightEI) {
					ei.dispose();
				}
				_backend.disposeEffect(lightEffectInfo.effect);
				lightEffectInfo.dispose();
			}
		}
		
		if (lightEffectInfo.effect is null) {
			lightEffectInfo = buildLightEffect(lights[0].kernelName);
		}

		foreach (light; lights) {
			if (!lightEI[light._id].valid) {
				auto effect = lightEffectInfo.effect;
				auto efInst = lightEI[light._id] = _backend.instantiateEffect(effect);

				allocateDefaultUniformStorage(efInst);
				
				// HACK
				setEffectInstanceUniformDefaults(&lightEffectInfo, efInst);

				final vdata = efInst.getVaryingParamData("VertexProgram.structure__posRadius");
				vdata.buffer = &_vb;
				vdata.attrib = &_va;

				if (auto pp = efInst.getUniformPtrPtr("structure__depthSampler")) {
					*cast(Texture**)pp = &_depthTex;
				}
				if (auto pp = efInst.getUniformPtrPtr("structure__packed1Sampler")) {
					*cast(Texture**)pp = &_packed1Tex;
				}
				if (auto pp = efInst.getUniformPtrPtr("structure__surfaceParamSampler")) {
					*cast(Texture**)pp = &_surfaceParamTex;
				}

				u32 idx = light._id;
				_ib.setSubData(u32.sizeof * idx, cast(void[])((&idx)[0..1]));
			}

			auto efInst = lightEI[light._id];

			final renderList = _backend.createRenderList();
			assert (renderList !is null);
			scope (success) _backend.disposeRenderList(renderList);

			light.setKernelData(
				KernelParamInterface(
				
					// getVaryingParam
					null,

					// getUniformParam
					(cstring name) {
						char[256] fqn;
						sprintf(fqn.ptr, "light%u__%.*s", 0, name);

						if (auto p = efInst.getUniformPtrPtr(fromStringz(fqn.ptr))) {
							return p;
						} else {
							return cast(void**)null;
						}
					},

					// setIndexData
					null
			));

			vec4 posRadius = void;
			posRadius.xyz = light.position;
			posRadius.w = light.influenceRadius;

			light.calcInfluenceRadius();
			
			_vb.setSubData(vec4.sizeof * light._id, cast(void[])((&posRadius)[0..1]));


			/*
			 * This discards framebuffer fragments outside of the min-max range
			 * computed from the light's minimal and maximal z value in view space.
			 *
			 * TODO: clip the light volume to the view frustum and compute
			 * a tighter bound.
			 */
			with (_backend.state.depthBounds) {
				enabled = true;

				vec4 hpos = vec4(light.position.tuple, 1);
				vec4 vpos = worldToView * hpos;

				vec4 vposMin = vpos;
				vposMin.z += light.influenceRadius;
				vposMin.z = min(vposMin.z, -nearPlaneDistance);
				
				vec4 vposMax = vpos;
				vposMax.z -= light.influenceRadius;
				vposMax.z = min(vposMax.z, -nearPlaneDistance);

				vec4 cposMin = viewToClip * vposMin;
				vec4 cposMax = viewToClip * vposMax;

				minz = 0.5 * cposMin.z / cposMin.w + 0.5;
				maxz = 0.5 * cposMax.z / cposMax.w + 0.5;
			}

			final bin = renderList.getBin(lightEffectInfo.effect);
			final rdata = bin.add(efInst);
			rdata.coordSys = CoordSys.identity;
			final id = &rdata.indexData;
			id.indexBuffer	= _ib;
			id.indexOffset	= light._id;
			id.numIndices	= 1;
			id.maxIndex		= light._id;
			id.topology		= MeshTopology.Points;

			_backend.render(renderList);
		}
	}

	
	override void render(ViewSettings vs, VSDRoot* vsd, RenderList* rlist) {
		// HACK
		foreach (l; .lights) {
			l.prepareRenderData(vsd);
		}

		updateStdUniforms(vs);

		if (_fbSize != _backend.state.viewport.size) {
			_fbSize = _backend.state.viewport.size;

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
				treq.internalFormat = TextureInternalFormat.INTENSITY_FLOAT32;
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
				treq.internalFormat = TextureInternalFormat.DEPTH_COMPONENT24;
				treq.minFilter = TextureMinFilter.Nearest;
				treq.magFilter = TextureMagFilter.Nearest;
				treq.wrapS = TextureWrap.ClampToEdge;
				treq.wrapT = TextureWrap.ClampToEdge;
				
				_sharedDepthTex = _backend.createTexture(
					_fbSize,
					treq
				);
				assert (_sharedDepthTex.valid);
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
				cfg.color[1] = _depthTex;
				cfg.depth = _sharedDepthTex;
				_attribFB = _backend.createFramebuffer(cfg);
				assert (_attribFB.valid);
			}

			{
				final cfg = FramebufferConfig();
				cfg.size = _fbSize;
				cfg.location = FramebufferLocation.Offscreen;
				cfg.color[0] = _diffuseIllumTex;
				cfg.color[1] = _specularIllumTex;
				cfg.depth = _sharedDepthTex;
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
			
			_backend.resetState();

			_backend.framebuffer = _attribFB;
			_backend.clearBuffers();

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
			_backend.state.cullFace = origState.cullFace;
			_lightFB.settings.clearDepthEnabled = true;
			_backend.render(blist);

			_backend.state.depthClamp = true;
			with (_backend.state.cullFace) {
				enabled = true;
				front = true;
				back = false;
			}

			with (_backend.state.depth) {
				enabled = true;
				writeMask = false;
				func = func.Greater;
			}
			
			_backend.framebuffer = _lightFB;
			_lightFB.settings.clearDepthEnabled = false;
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
			item.indexData		= *_structureRenderableIndexData[rid];
		}
		_backend.render(blist);
	}


	private {
		EffectInstance[]	_structureRenderableEI;
		EffectInstance[]	_finalRenderableEI;
		IndexData*[]		_structureRenderableIndexData;

		IKDefRegistry		_kdefRegistry;

		vec2i		_fbSize = vec2i.zero;
		Texture		_depthTex;
		Texture		_sharedDepthTex;
		Texture		_packed1Tex;
		Framebuffer	_attribFB;

		Texture		_surfaceParamTex;

		Texture		_diffuseIllumTex;
		Texture		_specularIllumTex;
		Framebuffer	_lightFB;
	}
}
