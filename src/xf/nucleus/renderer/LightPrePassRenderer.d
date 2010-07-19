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



private struct SubgraphInfo {
	GraphNodeId[]	nodes;
	GraphNodeId		input;
	GraphNodeId		output;

	bool singleNode() {
		return nodes.length <= 1;
	}
}


pragma (msg, "Move GraphBuilder out to its own module. Take the one from LPP.");
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
		assert (info !is null);
		
		if (KernelImpl.Type.Kernel == kernel.type) {
			if (!kernel.kernel.isConcrete) {
				error("Trying to use an abstract function for a kernel in a graph");
			}

			final nid = kg.addFuncNode(cast(Function)kernel.kernel.func);

			if (stack) {
				info.nodes = stack.allocArrayNoInit!(GraphNodeId)(1);
			}

			if (info.nodes) {
				info.nodes[0] = nid;
			}
			
			info.input = info.output = nid;
		} else {
			if (stack) {
				info.nodes = stack.allocArrayNoInit!(GraphNodeId)(
					numGraphFlattenedNodes(kernel.graph)
				);
			}
			
			buildKernelGraph(
				kernel.graph,
				kg,
				(uint nidx, cstring, GraphDefNode def, GraphNodeId delegate() getNid) {
					if (!spawnDataNodes && "data" == def.type) {
						final nid = dataNodeSource[nidx];
						if (info.nodes) {
							info.nodes[nidx] = nid;
						}
						return nid;
					} else {
						final nid = getNid();
						final n = kg.getNode(nid);

						if (info.nodes) {
							info.nodes[nidx] = nid;
						}

						if (KernelGraph.NodeType.Input == n.type) {
							info.input = nid;
						} else if (KernelGraph.NodeType.Output == n.type) {
							info.output = nid;
						} else if (KernelGraph.NodeType.Data == n.type) {
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


class LightPrePassRenderer : Renderer {
	mixin MRenderer!("LightPrePass");

	enum {
		maxSurfaceParams = 8,
		maxSurfaces = 256
	}

	
	this (RendererBackend backend, IKDefRegistry kdefRegistry) {
		assert (kdefRegistry !is null);
		_kdefRegistry = kdefRegistry;
		_structureEffectCache = new typeof(_structureEffectCache);
		_finalEffectCache = new typeof(_finalEffectCache);
		super(backend);
		createSurfaceParamTex();
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


	private {
		struct SurfaceData {
			struct Info {
				cstring	name;
				word	offset;
			}
			
			Info[]		info;
			void*		data;
			cstring		kernelName;
			ubyte		illumIdx;
			//KernelImpl	illumKernel;
		}

		struct IllumData {
			cstring			kernelName;
			KernelGraph		graph;
			GraphNodeId[]	topological;		// allocated off the KernelGraph's allocator
			GraphNodeId		input;
			GraphNodeId		output;
			ParamList*		dataNodeParams;

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
		IllumData[256]		_illumDataBuf;
		uint				_numIllumData;

		IllumData[] _illumData() {
			return _illumDataBuf[0.._numIllumData];
		}
	}


	// TODO
	override void registerSurface(SurfaceDef def) {
		auto surf = &_surfaces[def.id];
		surf.info.length = def.params.length;

		//assert (def.illumKernel !is null);
		surf.kernelName = def.illumKernel.name.dup;

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

		bool illumFound = false;
		foreach (ubyte i, ref illum; _illumData) {
			if (illum.kernelName == surf.kernelName) {
				surf.illumIdx = i;
				illumFound = true;
				break;
			}
		}

		if (!illumFound) {
			{
				uint idx = _numIllumData++;
				assert (idx < 256);
				surf.illumIdx = cast(ubyte)idx;
			}
			auto illum = &_illumData[surf.illumIdx];

			illum.kernelName = surf.kernelName;

			illum.graph = createKernelGraph();
			GraphBuilder builder;
			builder.sourceKernelType = SourceKernelType.Composite;

			SubgraphInfo info;
			builder.build(illum.graph, def.illumKernel, &info, null);

			ConvCtx convCtx;
			convCtx.semanticConverters = &_kdefRegistry.converters;
			convCtx.getKernel = &_kdefRegistry.getKernel;

			convertGraphDataFlow(
				illum.graph,
				convCtx
			);

			removeUnreachableBackwards(illum.graph.backend_readOnly, info.output);
			simplifyKernelGraph(illum.graph);

			illum.input = info.input;
			illum.output = info.output;

			illum.topological = DgScratchAllocator(&illum.graph._mem.pushBack)
				.allocArrayNoInit!(GraphNodeId)(illum.graph.numNodes);

			findTopologicalOrder(illum.graph.backend_readOnly, illum.topological);

			bool dataNodeFound = false;
			foreach (n; illum.graph.iterNodes(KernelGraph.NodeType.Data)) {
				assert (
					!dataNodeFound,
					"Only one Data node currently allowed for Illum kernels. Lazy."
				);
				illum.dataNodeParams = illum.graph.getNode(n).getParamList();
				dataNodeFound = true;
			}
		}

		vec4 texel;

		texel = vec4[cast(float)surf.illumIdx / (maxSurfaces-1), 0, 0, 0];
		_backend.updateTexture(
			_surfaceParamTex,
			vec2i(0, def.id),
			vec2i(1, 1),
			&texel.x
		);

		foreach (i, p; def.params) {
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


	// implements IKDefInvalidationObserver
	// TODO
	void onKDefInvalidated(KDefInvalidationInfo info) {
	}


	private {
		struct FinalEffectCacheKey {
			cstring		pigmentKernel;
			cstring		structureKernel;
			hash_t		hash;

			void computeHash() {
				hash = 0;
				hash += typeid(cstring).getHash(&pigmentKernel);
				hash += typeid(cstring).getHash(&structureKernel);
			}

			hash_t toHash() {
				return hash;
			}

			bool opEquals(ref FinalEffectCacheKey other) {
				return
						pigmentKernel == other.pigmentKernel
					&&	structureKernel == other.structureKernel;
			}
		}

		private {
			HashMap!(FinalEffectCacheKey, EffectInfo) _finalEffectCache;
		}

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

		SubgraphInfo structureInfo;
		SubgraphInfo pigmentInfo;
		
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

		SubgraphInfo outInfo;
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

		SubgraphInfo inInfo;
		{
			final kernel = _kdefRegistry.getKernel("LightPrePassLightIn");
			GraphBuilder builder;
			builder.sourceKernelType = SourceKernelType.Structure;
			builder.build(kg, kernel, &inInfo, stack);
			assert (inInfo.input.valid);
			assert (inInfo.output.valid);
		}

		convertGraphDataFlowExceptOutput(
			kg,
			convCtx
		);

		SubgraphInfo lightInfo;
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

		fmt(
`
float3x4 modelToWorld;
float4x4 worldToView <
	string scope = "effect";
>;
float4x4 viewToWorld <
	string scope = "effect";
>;
float4x4 viewToClip <
	string scope = "effect";
>;
float4x4 clipToView <
	string scope = "effect";
>;
float3 eyePosition <
	string scope = "effect";
>;
float farPlaneDistance <
	string scope = "effect";
>;
`);

		// ----

		CodegenSetup cgSetup;
		cgSetup.inputNode = inInfo.input;
		cgSetup.outputNode = BRDFnode;

		codegen(
			stack,
			kg,
			cgSetup,
			&ctx
		);

		fmt.flush();
		char[1] zero = '\0';
		arrrr.write(zero[]);

		File.set("shader.tmp.cgfx", arrrr.slice());

		final effect = effectInfo.effect = _backend.createEffect(
			null,
			EffectSource.stringz(cast(char*)arrrr.slice().ptr)
		);

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
			setUniform("viewToWorld", &viewToWorld);
			setUniform("viewToClip", &viewToClip);
			setUniform("clipToView", &clipToView);
			setUniform("eyePosition", &eyePosition);
			setUniform("farPlaneDistance", &farPlaneDistance);
		}

		// ----

		findEffectInfo(kg, &effectInfo);

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
		
		foreach (illumIdx, illum; _illumData) {
			fmt("struct BRDF__")(illumIdx)(" {");
			fmt("\t// ")(illum.kernelName);
			fmt.newline;

			final inputNode = illum.graph.getNode(illum.input);
			final outputNode = illum.graph.getNode(illum.output);

			dumpUniforms(ctx, illum.graph, fmt);

			// ---- func body ----
			{
				fmt.formatln("void main(");

				uint parIdx = 0;
				foreach (i, par; &illum.inputs) {
					assert (par.hasTypeConstraint);

					if (parIdx++ != 0) {
						fmt(",").newline;
						ctx.indent(1);
					}

					fmt("in ");
					fmt(par.type);
					fmt(" ");
					emitSourceParamName(ctx, illum.graph, null, illum.input, par.name);
				}
				
				foreach (i, par; &illum.outputs) {
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
					illum.graph,
					null,
					illum.topological,
					graphs[illumIdx][0].node2funcName,
					graphs[illumIdx][0].node2compName
				);

				foreach (i, par; &illum.outputs) {
					GraphNodeId	srcNid;
					Param*		srcParam;

					if (!getOutputParamIndirect(
						illum.graph,
						illum.output,
						par.name,
						&srcNid,
						&srcParam
					)) {
						error(
							"No flow to {}.{}. Should have been caught earlier.",
							illum.output,
							par.name
						);
					}

					fmt.format("\tbridge__{} = ", i);
					emitSourceParamName(ctx, illum.graph, null, srcNid, srcParam.name);
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

		void surfParam(int i) {
			fmt.format(
				"getSurfaceParam.value({:f.16})",
				(cast(float)i + 1.5f) / maxSurfaceParams
			);
		}

		void illumIdxBranch(int i, void delegate() dg) {
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

		foreach (illumIdx, illum; _illumData) {
			illumIdxBranch(illumIdx, {
				fmt("BRDF__")(illumIdx)(" brdf__inst;");
				if (illum.dataNodeParams) foreach (i, param; *illum.dataNodeParams) {
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

		fmt("else { diffuse = float4(1, 0, 0, 0); specular = float4(1, 0, 0, 0); }").newline;

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
		final graphs = stack.allocArray!(SubgraphData[])(_illumData.length);

		ctx.domain = GPUDomain.Fragment;
		ctx.getInterface = &_getInterface;

		foreach (illumIdx, illum; _illumData) {
			graphs[illumIdx] = emitCompositesAndFuncs(
				stack,
				ctx,
				illum.graph
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
		func.params.copyFrom(_kdefRegistry.getKernel("Illumination").kernel.func.params);
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
		final pigmentKernel		= _kdefRegistry.getKernel(material.kernelName);
		final illumKernel		= _kdefRegistry.getKernel(surface.kernelName);

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

		SubgraphInfo outInfo;
		{
			final kernel = _kdefRegistry.getKernel("LightPrePassFinalOut");
			GraphBuilder builder;
			builder.sourceKernelType = SourceKernelType.Pigment;
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
							pigmentInfo.output,
							"out_albedo",
							srcNid,
							srcParam
						);
					}

					case "specular": {
						return getOutputParamIndirect(
							kg,
							pigmentInfo.output,
							"out_specular",
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
			(CodeSink fmt) {
				fmt(
`
float3x4 modelToWorld;
float4x4 worldToView <
	string scope = "effect";
>;
float4x4 viewToWorld <
	string scope = "effect";
>;
float4x4 viewToClip <
	string scope = "effect";
>;
float4x4 clipToView <
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
			setUniform("viewToWorld", &viewToWorld);
			setUniform("viewToClip", &viewToClip);
			setUniform("clipToView", &clipToView);
			setUniform("eyePosition", &eyePosition);
			setUniform("farPlaneDistance", &farPlaneDistance);
		}

		// ----

		findEffectInfo(kg, &effectInfo);

		return effectInfo;
	}


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
						material.kernelName,
						renderables.structureKernel[rid]
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


				if (void** ptr = efInst.getUniformPtrPtr("pigment__diffuseIlluminationSampler")) {
					*cast(Texture**)ptr = &_diffuseIllumTex;
				} else {
					error("diffuseIlluminationSampler not found in the structure kernel.");
				}

				if (void** ptr = efInst.getUniformPtrPtr("pigment__specularIlluminationSampler")) {
					*cast(Texture**)ptr = &_specularIllumTex;
				} else {
					error("specularIlluminationSampler not found in the structure kernel.");
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
	override void onLightCreated(LightId) {
	}
	
	// TODO
	override void onLightDisposed(LightId) {
	}
	
	// TODO
	override void onLightInvalidated(LightId) {
	}


	EffectInstance	lightEI;
	EffectInfo		lightEffectInfo;

		VertexBuffer	_vb;
		VertexAttrib	_va;
		IndexBuffer		_ib;
	

	void renderLights(Light[] lights) {
		if (lightEffectInfo.effect is null) {
			lightEffectInfo = buildLightEffect(lights[0].kernelName);
			auto effect = lightEffectInfo.effect;
			auto efInst = lightEI = _backend.instantiateEffect(effect);

				// HACK
				allocateDefaultUniformStorage(efInst);
				setEffectInstanceUniformDefaults(&lightEffectInfo, efInst);

				vec3[24] positions = void;
				positions[] = Primitives.Cube.positions[];
				foreach (ref v; positions) {
					v *= 100;
				}

				_vb = _backend.createVertexBuffer(
					BufferUsage.StaticDraw,
					cast(void[])positions
				);
				_va = VertexAttrib(
					0,
					vec3.sizeof,
					VertexAttrib.Type.Vec3
				);
				_ib = _backend.createIndexBuffer(
					BufferUsage.StaticDraw,
					Primitives.Cube.indices
				);

			final vdata = efInst.getVaryingParamData("VertexProgram.structure__position");
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
		}

		final renderList = _backend.createRenderList();
		assert (renderList !is null);
		scope (success) _backend.disposeRenderList(renderList);

		final bin = renderList.getBin(lightEffectInfo.effect);
		final rdata = bin.add(lightEI);
		*rdata = typeof(*rdata).init;
		rdata.coordSys = CoordSys.identity;
		final id = &rdata.indexData;
		id.indexBuffer	= _ib;
		id.numIndices	= Primitives.Cube.indices.length;
		id.maxIndex		= 7;

		_backend.render(renderList);
	}

	
	override void render(ViewSettings vs, RenderList* rlist) {
		this.viewToClip = vs.computeProjectionMatrix();
		this.clipToView = this.viewToClip.inverse();
		this.worldToView = vs.computeViewMatrix();
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
				treq.internalFormat = TextureInternalFormat.RGBA8;
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
				treq.internalFormat = TextureInternalFormat.DEPTH_COMPONENT24;
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
			_backend.render(blist);

			// HACK
			_backend.state.depth.enabled = false;
			_backend.framebuffer = _lightFB;
			_backend.clearBuffers();
			renderLights(.lights);
			_backend.state.depth.enabled = true;
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
		EffectInstance[]	_finalRenderableEI;
		IndexData*[]		_structureRenderableIndexData;

		IKDefRegistry		_kdefRegistry;

		vec2i		_fbSize = vec2i.zero;
		Texture		_depthTex;
		Texture		_packed1Tex;
		Framebuffer	_attribFB;

		Texture		_surfaceParamTex;

		Texture		_diffuseIllumTex;
		Texture		_specularIllumTex;
		Framebuffer	_lightFB;

		mat4	worldToView;
		mat4	viewToWorld;
		mat4	viewToClip;
		mat4	clipToView;
		vec3	eyePosition;
		float	farPlaneDistance;
	}
}
