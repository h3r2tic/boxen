module xf.nucleus.post.PostProcessor;

private {
	import
		xf.Common,
		xf.utils.FormatTmp;
	
	import
		xf.nucleus.kdef.model.IKDefRegistry,
		xf.nucleus.kdef.KDefGraphBuilder,
		xf.nucleus.Param,
		xf.nucleus.Function,
		xf.nucleus.Code,
		xf.nucleus.KernelCompiler,
		xf.nucleus.KernelImpl,
		xf.nucleus.graph.KernelGraph,
		xf.nucleus.graph.KernelGraphOps,
		xf.nucleus.Log : error = nucleusError, log = nucleusLog;

	import
		xf.omg.core.LinearAlgebra;

	import
		xf.gfx.Texture,
		xf.gfx.Effect,
		xf.gfx.Framebuffer,
		xf.gfx.IRenderer : RendererBackend = IRenderer;

	import
		xf.mem.StackBuffer,
		xf.mem.Array,
		xf.mem.FixedQueue,
		xf.mem.ScratchAllocator,
		xf.mem.SmallTempArray,
		xf.utils.BitSet;
}



final class PostProcessor {
	this (RendererBackend backend, IKDefRegistry kdefRegistry) {
		_backend = backend;
		_kdefRegistry = kdefRegistry;
	}


	void setKernel(cstring kernelName) {
		if (_kernelName != kernelName) {
			_kernelName = kernelName.dup;
			_settingsDirty = true;
		}
	}


	// Renders into the framebuffer which is current in the _backend renderer
	void render(Texture input) {
		assert (input.valid);

		{
			TextureRequest inputReq;
			assure (input.getInfo(&inputReq));

			vec2i	inputSize = input.getSize.xy;
			final	inputFormat = inputReq.internalFormat;
			
			if (inputSize != _inputSize || inputFormat != _inputFormat) {
				_inputSize = inputSize;
				_inputFormat = inputFormat;
				_settingsDirty = true;
			}
		}

		if (_settingsDirty) {
			reconfigure();
		}

		_render(input);
	}


	struct RTConfig {
		vec2i					size;
		TextureInternalFormat	format;

		// TODO?
		bool canMRTWith(RTConfig other) {
			return size == other.size;
		}
	}


	private void reconfigure() {
		checkBlitSignature();
		
		scope (success) _settingsDirty = false;
		scope stack = new StackBuffer;

		KernelGraph graph = createKernelGraph();
		scope (exit) disposeKernelGraph(graph);

		final kernelImpl = _kdefRegistry.getKernel(_kernelName);
		assert (kernelImpl.type == kernelImpl.type.Graph);	// TODO?

		final graphDef = kernelImpl.graph;

		// build the source graph

		buildKernelGraph(
			graphDef,
			graph
		);

		// insert conversion nodes, handle auto conversions
		
		convertGraphDataFlow(
			graph,
			ConvCtx(
				&_kdefRegistry.converters,
				&_kdefRegistry.getKernel
			)
		);

		RTConfig getRTConfig(GraphNodeId nid) {
			// TODO
			return RTConfig(
				_inputSize,
				_inputFormat
			);
		}

		genRenderStages(
			graph,
			&getRTConfig
		);
	}


	// The data passed to sink() is allocated off the supplied stack
	private void findCompatibleOutputSets(
		StackBufferUnsafe stack,
		GraphNodeId[] nodes,
		RTConfig delegate(GraphNodeId) getRTConfig,
		void delegate(GraphNodeId[]) sink
	) {
		assert (nodes.length > 0);
		
		mixin(ct_allocaArray(`GraphNodeId`, `buf`, `nodes.length`));
		mixin(ct_allocaArray(`bool`, `doneFlags`, `nodes.length`));
		doneFlags[] = false;

		foreach (uword i, n1; nodes) {
			if (!doneFlags[i]) {
				doneFlags[i] = true;

				size_t num = 1;
				buf[0] = n1;
				
				for (uword j = i+1; j < nodes.length; ++j) {
					auto n2 = nodes[j];
					if (!doneFlags[j]) {
						if (getRTConfig(n1).canMRTWith(getRTConfig(n2))) {
							doneFlags[j] = true;
							buf[num++] = n2;
						}
					}
				}

				sink(stack.dupArray(buf[0..num]));
			}
		}
	}


	private void genRenderStages(
		KernelGraph graph,
		RTConfig delegate(GraphNodeId) getRTConfig
	) {
		scope stack = new StackBufferUnsafe;

		auto outNodeSets = FixedQueue!(GraphNodeId[])(
			stack.allocArrayNoInit!(GraphNodeId[])(graph.capacity)
		);
		auto inNodes = FixedArray!(GraphNodeId)(
			stack.allocArrayNoInit!(GraphNodeId)(graph.capacity)
		);
		auto subgraphNodes = FixedArray!(GraphNodeId)(
			stack.allocArrayNoInit!(GraphNodeId)(graph.capacity)
		);

		auto old2new = stack.allocArrayNoInit!(GraphNodeId)(graph.capacity);

		auto nodeFlags = DynamicBitSet();
		nodeFlags.alloc(graph.capacity, &stack.allocRaw);

		auto nq = FixedQueue!(GraphNodeId)(
			stack.allocArrayNoInit!(GraphNodeId)(graph.capacity)
		);

		foreach (nid; graph.iterNodes(KernelGraph.NodeType.Output)) {
			assert (outNodeSets.isEmpty);
			final arr = stack._new!(GraphNodeId)()[0..1];
			arr[0] = nid;
			*outNodeSets.pushBack() = arr;
		}

		while (!outNodeSets.isEmpty) {
			nodeFlags.clearAll();
			final outNodes = *outNodeSets.popFront();

			/*
			 * Seed the queue with the output nodes from the previous stage.
			 */

			foreach (n; outNodes) {
				*nq.pushBack() = n;
				nodeFlags.set(n.id);
				subgraphNodes.pushBack(n);
			}

			/*
			 * Walk backwards from the outputs of the previous stage stopping at Blit.
			 */

			while (!nq.isEmpty) {
				final oldDst = *nq.popFront();
				assert (nodeFlags.isSet(oldDst.id));
				final newDst = old2new[oldDst.id];
				
				foreach (oldSrc; graph.flow.iterIncomingConnections(oldDst)) {
					auto oldSrcNode = graph.getNode(oldSrc);
					
					if ((	KernelGraph.NodeType.Kernel == oldSrcNode.type
						&&	"Blit" == oldSrcNode.kernel.kernel.func.name)
						||	KernelGraph.NodeType.Input == oldSrcNode.type
					) {
						if (!nodeFlags.isSet(oldSrc.id)) {
							inNodes.pushBack(oldSrc);
							nodeFlags.set(oldSrc.id);
						}
					} else {
						if (!nodeFlags.isSet(oldSrc.id)) {
							*nq.pushBack() = oldSrc;
							nodeFlags.set(oldSrc.id);
						}
					}

					subgraphNodes.pushBack(oldSrc);
				}
			}

			if (inNodes.length > 0) {
				findCompatibleOutputSets(
					stack,
					inNodes.data,
					getRTConfig,
					(GraphNodeId[] outs) {
						*outNodeSets.pushBack() = outs;
					}
				);

				genRenderStage(graph, inNodes.data, outNodes, subgraphNodes.data);

				subgraphNodes.clear();
				inNodes.clear();
				nq.clear();
			}
		}
	}


	private void genRenderStage(
		KernelGraph graph,
		GraphNodeId[] inNodes,
		GraphNodeId[] outNodes,
		GraphNodeId[] oldNodes
	) {
		scope stack = new StackBuffer;
		final allocator = DgScratchAllocator(&stack.allocRaw);
		
		assert (inNodes.length > 0);
		assert (outNodes.length > 0);

		auto subgraph = createKernelGraph();
		scope (exit) disposeKernelGraph(subgraph);
		
		final inNid = subgraph.addNode(KernelGraph.NodeType.Input);
		final outNid = subgraph.addNode(KernelGraph.NodeType.Output);
		final dataNid = subgraph.addNode(KernelGraph.NodeType.Data);

		// Create the vertex shader func

		final vertCode = Code();
		vertCode.append(`rasterPos = float4(inPos, 0, 1);`, allocator);

		final vertFunc = stack._new!(Function)(
			"Blit_vert"[],
			cast(cstring[])null,	// tags
			vertCode,
			&stack.allocRaw
		); {
			final p = vertFunc.params.add(ParamDirection.In, "inPos");
			p.hasPlainSemantic = true;
			p.type = "float2";
		} {
			final p = vertFunc.params.add(ParamDirection.Out, "rasterPos");
			p.hasPlainSemantic = true;
			p.type = "float4";
			p.semantic.addTrait("use", "position");
			p.semantic.addTrait("basis", "clip");
		}

		// Create a func for sampling images for the fragment shader
		
		final fragCode = Code();
		fragCode.append(`output = input.sample(uv);`, allocator);

		final fragFunc = stack._new!(Function)(
			"Blit_frag"[],
			cast(cstring[])null,	// tags
			fragCode,
			&stack.allocRaw
		); {
			final p = fragFunc.params.add(ParamDirection.In, "input");
			p.hasPlainSemantic = true;
			p.type = "Image";
		} {
			final p = fragFunc.params.add(ParamDirection.In, "uv");
			p.hasPlainSemantic = true;
			p.type = "float2";
		} {
			final p = fragFunc.params.add(ParamDirection.Out, "output");
			p.hasPlainSemantic = true;
			p.type = "float4";
		}

		// Get the func used for sampling textures, it will be needed in the
		// fragment shader

		final tex2DFunc = cast(Function)_kdefRegistry.getKernel("Tex2D").kernel.func;
		assert (tex2DFunc !is null);

		// We'll have to convert the original textures to Image though, and this
		// is what the SamplerToImage will do

		final samplerToImage = cast(Function)_kdefRegistry.getKernel("SamplerToImage").kernel.func;
		assert (samplerToImage !is null);

		// The input node will only have a float2 position

		{
			// Don't use outside of the scope, might be reallocated.
			final inNode = subgraph.getNode(inNid).input();
			auto pos = inNode.params.add(ParamDirection.Out, "position");
			pos.hasPlainSemantic = true;
			pos.type = "float2";
		}

		final fragNid = subgraph.addFuncNode(fragFunc);

		// A Rasterize node is required by codegen

		final vertNid = subgraph.addFuncNode(vertFunc);

		final rastNid = subgraph.addNode(KernelGraph.NodeType.Kernel);

		subgraph.getNode(rastNid).kernel.kernel
			= _kdefRegistry.getKernel("Rasterize").kernel;

		subgraph.flow.addDataFlow(
			vertNid, "rasterPos",
			rastNid, "inPos"
		);

		subgraph.flow.addDataFlow(
			inNid, "position",
			vertNid, "inPos"
		);

		// ----

		final old2new = stack.allocArrayNoInit!(GraphNodeId)(graph.capacity);


		bool isInputNode(GraphNodeId nid) {
			foreach (n; inNodes) {
				if (n == nid) {
					return true;
				}
			}
			return false;
		}

		bool isOutputNode(GraphNodeId nid) {
			foreach (n; outNodes) {
				if (n == nid) {
					return true;
				}
			}
			return false;
		}

		// Create regular nodes

		foreach (oldNid; oldNodes) {
			// Will handle input and output nodes differently
			if (isInputNode(oldNid) || isOutputNode(oldNid)) {
				continue;
			}

			// Create the node and copy its stuff

			final oldNode = graph.getNode(oldNid);
			final newNid = subgraph.addNode(oldNode.type);
			final newNode = subgraph.getNode(newNid);
			oldNode.copyTo(newNode);

			old2new[oldNid.id] = newNid;
		}

		// Find all input and output params

		struct BridgeParam {
			cstring		name;
			GraphNodeId	oldNid;
			GraphNodeId	newNid;
		}

		mixin MSmallTempArray!(BridgeParam)	inputBridge;
		mixin MSmallTempArray!(BridgeParam)	outputBridge;

		foreach (oldNid; inNodes) {
			final oldNode = graph.getNode(oldNid);
			foreach (param; *oldNode.getParamList()) {
				if (!param.isOutput) {
					continue;
				}
				
				assert ("Image" == param.type);

				inputBridge.pushBack(BridgeParam(param.name, oldNid), &stack.allocRaw);
			}
		}

		foreach (oldNid; outNodes) {
			final oldNode = graph.getNode(oldNid);
			foreach (param; *oldNode.getParamList()) {
				if (!param.isInput) {
					continue;
				}
				
				assert ("Image" == param.type);

				outputBridge.pushBack(BridgeParam(param.name, oldNid), &stack.allocRaw);
			}
		}

		// Create samplers and sampler->Image funcs for the input bridge

		foreach (i, ref input; inputBridge.items) {
			final s2imgNid = subgraph.addFuncNode(samplerToImage);
			final s2imgNode = subgraph.getNode(s2imgNid);
			final dataNode = subgraph.getNode(dataNid).data();
			dataNode.sourceKernelType = SourceKernelType.Composite;

			input.newNid = s2imgNid;

			formatTmp(
				(Fmt fmt) {
					fmt.format("in__{}", i);
				},
				(cstring str) {
					auto par = dataNode.params.add(ParamDirection.Out, str);
					par.hasPlainSemantic = true;
					par.type = "sampler2D";

					subgraph.flow.addDataFlow(
						dataNid, str,
						s2imgNid, "sampler"
					);
				}
			);
		}

		// Create outputs and sampling funcs for the output bridge

		foreach (i, ref output; outputBridge.items) {
			final sampleNid = subgraph.addFuncNode(fragFunc);
			final sampleNode = subgraph.getNode(sampleNid);
			final outNode = subgraph.getNode(outNid).output();

			output.newNid = sampleNid;

			subgraph.flow.addDataFlow(
				inNid, "position",
				sampleNid, "uv"
			);

			formatTmp(
				(Fmt fmt) {
					fmt.format("out__{}", i);
				},
				(cstring str) {
					auto par = outNode.params.add(ParamDirection.In, str);
					par.hasPlainSemantic = true;
					par.type = "float4";

					subgraph.flow.addDataFlow(
						sampleNid, "output",
						outNid, str
					);
				}
			);
		}

		// Finally, copy data flow

		foreach (oldSrc; oldNodes) {
			bool srcIsInput = isInputNode(oldSrc);
			
			foreach (oldDst; graph.flow.iterOutgoingConnections(oldSrc)) {
				bool dstIsOutput = isOutputNode(oldDst);
				
				foreach (fl; graph.flow.iterDataFlow(oldSrc, oldDst)) {
					GraphNodeId newSrc, newDst;
					cstring fromName, toName;
					
					if (srcIsInput) {
						foreach (bp; inputBridge.items) {
							if (bp.oldNid == oldSrc && bp.name == fl.from) {
								newSrc = bp.newNid;
								fromName = "image";	// output from SamplerToImage
								break;
							}
						}
						assert (newSrc.valid);
					} else {
						newSrc = old2new[oldSrc.id];
						fromName = fl.from;
					}

					if (dstIsOutput) {
						foreach (bp; outputBridge.items) {
							if (bp.oldNid == oldDst && bp.name == fl.to) {
								newDst = bp.newNid;
								toName = "input";	// input to Blit_frag
								break;
							}
						}
						assert (newDst.valid);
					} else {
						newDst = old2new[oldDst.id];
						toName = fl.to;
					}

					subgraph.flow.addDataFlow(
						newSrc, fromName,
						newDst, toName
					);
				}
			}
		}

		addRenderStage(subgraph, inNid, outNid);
	}


	private void addRenderStage(
		KernelGraph graph,
		GraphNodeId inNid,
		GraphNodeId outNid
	) {
		ConvCtx convCtx;
		convCtx.semanticConverters = &_kdefRegistry.converters;
		convCtx.getKernel = &_kdefRegistry.getKernel;

		convertGraphDataFlow(
			graph,
			convCtx
		);
		
		
		final setup = CodegenSetup();
		setup.inputNode = inNid;
		setup.outputNode = outNid;
		setup.getInterface = (cstring name, AbstractFunction* func) {
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
		
		Effect stageEffect = compileKernelGraph(
			"BlitStage",
			graph,
			setup,
			_backend,
			null	// extra codegen
		);
	}


	private void checkBlitSignature() {
		KernelImpl kimpl;
		if (!_kdefRegistry.getKernel("Blit", &kimpl)) {
			error("Blit kernel not found in the registry");
		}

		if (kimpl.type != KernelImpl.Type.Kernel) {
			error("The Blit kernel must be abstract.");
		}

		auto blitFunc = kimpl.kernel.func;

		if (blitFunc.params.length != 2) {
			error("Expected 2 params for the Blit kernel, not {}.", blitFunc.params.length);
		}
		
		if (ParamDirection.In != blitFunc.params[0].dir) {
			error("Wrong Blit kernel signature. The first param must be 'in'.");
		}
		
		if (ParamDirection.Out != blitFunc.params[1].dir) {
			error("Wrong Blit kernel signature. The first param must be 'in'.");
		}

		if ("input" != blitFunc.params[0].name) {
			error("Wrong Blit kernel signature. The first param must be called 'input'.");
		}

		if ("output" != blitFunc.params[1].name) {
			error("Wrong Blit kernel signature. The second param must be called 'input'.");
		}

		if ("Image" != blitFunc.params[0].type) {
			error("Wrong Blit kernel signature. The first param must be of type Image.");
		}
		
		if ("Image" != blitFunc.params[1].type) {
			error("Wrong Blit kernel signature. The second param must be of type Image.");
		}

		// TODO: also check SamplerToImage and Tex2D
	}


	private void _render(Texture input) {
		assert (!_settingsDirty);
	}


	private {
		RendererBackend	_backend;
		IKDefRegistry	_kdefRegistry;
		bool			_settingsDirty = false;

		cstring _kernelName = null;
		
		vec2i					_inputSize = vec2i.zero;
		TextureInternalFormat	_inputFormat;
	}
}
