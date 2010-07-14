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
		xf.omg.core.LinearAlgebra,
		xf.omg.core.CoordSys;

	import
		xf.gfx.Texture,
		xf.gfx.Effect,
		xf.gfx.Framebuffer,
		xf.gfx.Buffer,
		xf.gfx.VertexBuffer,
		xf.gfx.IndexBuffer,
		xf.gfx.RenderList,
		xf.gfx.IRenderer : RendererBackend = IRenderer;

	import
		xf.mem.StackBuffer,
		xf.mem.Array,
		xf.mem.FixedQueue,
		xf.mem.ScratchAllocator,
		xf.mem.ChunkQueue,
		xf.mem.SmallTempArray,
		xf.utils.BitSet;

	// tmp
	import xf.nucleus.graph.GraphMisc;
	import tango.io.device.File;
}



final class PostProcessor {
	this (RendererBackend backend, IKDefRegistry kdefRegistry) {
		_backend = backend;
		_kdefRegistry = kdefRegistry;
		_allocator = ScratchFIFO();
		_allocator.initialize();
		_mem = DgScratchAllocator(&_allocator.pushBack);

		vec2[4] positions = void;
		positions[0] = vec2(-1, -1);
		positions[1] = vec2(1, -1);
		positions[2] = vec2(1, 1);
		positions[3] = vec2(-1, 1);

		uint[6] indices = void;
		indices[0] = 0; indices[1] = 1; indices[2] = 2;
		indices[3] = 0; indices[4] = 2; indices[5] = 3;

		_vb = backend.createVertexBuffer(
			BufferUsage.StaticDraw,
			cast(void[])positions
		);
		_va = VertexAttrib(
			0,
			vec2.sizeof,
			VertexAttrib.Type.Vec2
		);
		_ib = backend.createIndexBuffer(
			BufferUsage.StaticDraw,
			indices
		);

		/+final vdata = efInst.getVaryingParamData("VertexProgram.input.position");
		vdata.buffer = &vb;
		vdata.attrib = &va;+/
	}


	struct RenderStage {
		RenderStage*	next;
		Effect			effect;
		EffectInstance	efInst;
		Texture[]		outTextures;
		StageInputSrc[]	inputs;
		Framebuffer		fb;
	}


	struct StageInputSrc {
		RenderStage*	stage;
		StageInputSrc*	nextInSharedOutput;
		uword			outputIdx;
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

		/+File.set("graph.dot", toGraphviz(graph));
		assert (false);+/

		// insert conversion nodes, handle auto conversions
		
		convertGraphDataFlow(
			graph,
			ConvCtx(
				&_kdefRegistry.converters,
				&_kdefRegistry.getKernel
			)
		);

		RTConfig getRTConfig(GraphNodeId nid) {
			vec2i	size = _inputSize;
			auto	format = _inputFormat;

			auto attribs = graph.getNode(nid).attribs;
			foreach (a; attribs) {
				if ("resample" == a.name) {
					assert (ParamValueType.Float2 == a.valueType);
					vec2 resample;
					a.getValue(&resample.x, &resample.y);
					size.x = cast(int)(resample.x * size.x);
					size.y = cast(int)(resample.y * size.y);
				}
			}
			
			return RTConfig(
				size,
				format
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
		QItem[] nodes,
		RTConfig delegate(GraphNodeId) getRTConfig,
		void delegate(QItem[]) sink
	) {
		assert (nodes.length > 0);
		
		mixin(ct_allocaArray(`QItem`, `buf`, `nodes.length`));
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
						if (getRTConfig(n1.nid).canMRTWith(getRTConfig(n2.nid))) {
							doneFlags[j] = true;
							buf[num++] = n2;
						}
					}
				}

				sink(stack.dupArray(buf[0..num]));
			}
		}
	}


	private struct QItem {
		GraphNodeId		nid;
		StageInputSrc*	inputSrc;
	}


	private void genRenderStages(
		KernelGraph graph,
		RTConfig delegate(GraphNodeId) getRTConfig
	) {
		scope stack = new StackBufferUnsafe;

		auto outNodeSets = FixedQueue!(QItem[])(
			stack.allocArrayNoInit!(QItem[])(graph.capacity)
		);
		auto inNodes = FixedArray!(QItem)(
			stack.allocArrayNoInit!(QItem)(graph.capacity)
		);
		auto stageInNodes = FixedArray!(GraphNodeId)(
			stack.allocArrayNoInit!(GraphNodeId)(graph.capacity)
		);
		auto subgraphNodes = FixedArray!(GraphNodeId)(
			stack.allocArrayNoInit!(GraphNodeId)(graph.capacity)
		);

		auto old2new = stack.allocArrayNoInit!(GraphNodeId)(graph.capacity);

		auto nodeFlags = DynamicBitSet();
		nodeFlags.alloc(graph.capacity, &stack.allocRaw);

		auto nq = FixedQueue!(QItem)(
			stack.allocArrayNoInit!(QItem)(graph.capacity)
		);

		foreach (nid; graph.iterNodes(KernelGraph.NodeType.Output)) {
			assert (outNodeSets.isEmpty);
			inNodes.pushBack(QItem(nid, null));
		}

		while (inNodes.length > 0) {
			findCompatibleOutputSets(
				stack,
				inNodes.data,
				getRTConfig,
				(QItem[] outs) {
					*outNodeSets.pushBack() = outs;
				}
			);

			inNodes.clear();

			while (!outNodeSets.isEmpty) {
				nodeFlags.clearAll();
				final outNodes = *outNodeSets.popFront();

				/*
				 * Seed the queue with the output nodes from the previous stage.
				 */

				foreach (n; outNodes) {
					*nq.pushBack() = n;
					nodeFlags.set(n.nid.id);
					subgraphNodes.pushBack(n.nid);
				}

				/*
				 * Walk backwards from the outputs of the previous stage stopping at Blit.
				 */

				while (!nq.isEmpty) {
					final oldDstQItem = *nq.popFront();
					final oldDst = oldDstQItem.nid;
					assert (nodeFlags.isSet(oldDst.id));
					final newDst = old2new[oldDst.id];
					
					foreach (oldSrc; graph.flow.iterIncomingConnections(oldDst)) {
						auto oldSrcNode = graph.getNode(oldSrc);

						bool isBlit = (
							KernelGraph.NodeType.Kernel == oldSrcNode.type
							&&	"Blit" == oldSrcNode.kernel.kernel.func.name
						);

						if (isBlit || KernelGraph.NodeType.Input == oldSrcNode.type) {
							if (!nodeFlags.isSet(oldSrc.id)) {
								stageInNodes.pushBack(oldSrc);
								nodeFlags.set(oldSrc.id);
							}
						} else {
							if (!nodeFlags.isSet(oldSrc.id)) {
								*nq.pushBack() = QItem(oldSrc, null);
								nodeFlags.set(oldSrc.id);
							}
						}

						subgraphNodes.pushBack(oldSrc);
					}
				}

				if (stageInNodes.length > 0) {
					auto rs = genRenderStage(
						graph,
						stageInNodes.data,
						outNodes,
						subgraphNodes.data
					);

					createRenderStageFramebuffer(
						rs,
						outNodes,
						getRTConfig
					);

					// TODO: check whether params are used in the Cg effect
					bool isAnyOutputUsed(GraphNodeId node) {
						return true;
					}

					foreach (n; outNodes) {
						if (auto info = n.inputSrc) {
							for (auto it = info; it; it = it.nextInSharedOutput) {
								it.stage = rs;
							}
						}
					}

					stageNodeIter: foreach (iidx, n1; stageInNodes) {
						if (KernelGraph.NodeType.Input == graph.getNode(n1).type) {
							continue;
						}
						
						if (isAnyOutputUsed(n1)) {
							// HACK: assumes only one input param per node
							final sis = &rs.inputs[iidx];
							
							foreach (ref n2; inNodes) {
								if (n1 == n2.nid) {
									sis.nextInSharedOutput = n2.inputSrc;
									n2.inputSrc = sis;
									continue stageNodeIter;
								}
							}
							inNodes.pushBack(QItem(n1, sis));
						}
					}

					stageInNodes.clear();
				}

				subgraphNodes.clear();
				nq.clear();
			}
		}

		connectStageTextures();
	}


	private void createRenderStageFramebuffer(
		RenderStage* rs,
		QItem[] outNodes,
		RTConfig delegate(GraphNodeId) getRTConfig
	) {
		// HACK: assumes only one output per node

		foreach (i, item; outNodes) {
			assert ((item.inputSrc is null) == (rs.next is null));

			if (item.inputSrc !is null) {	// Texture not needed otherwise
				final cfg = getRTConfig(item.nid);

				TextureRequest treq;
				treq.internalFormat = cfg.format;
				treq.minFilter = TextureMinFilter.Linear;
				treq.magFilter = TextureMagFilter.Linear;
				rs.outTextures[i] = _backend.createTexture(
					cfg.size,
					treq
				);
			}
		}

		if (rs.next !is null) {
			final cfg = FramebufferConfig();
			vec2i size = cfg.size = rs.outTextures[0].getSize().xy;
			cfg.location = FramebufferLocation.Offscreen;
			foreach (i, ref tex; rs.outTextures) {
				cfg.color[i] = tex;
			}
			rs.fb = _backend.createFramebuffer(cfg);
		}
	}


	private void connectStageTextures() {
		for (auto st = _renderStageList; st; st = st.next) {
			foreach (i, ref input; st.inputs) {
				if (input.stage !is null) {
					Texture* tex = &input.stage.outTextures[input.outputIdx];
					renameInputParam(
						i,
						(cstring name) {
							if (auto pp = st.efInst.getUniformPtrPtr(name)) {
								*cast(Texture**)pp = tex;
							}
						}
					);
				} else {
					Texture* tex = &_inputTexture;
					renameInputParam(
						i,
						(cstring name) {
							if (auto pp = st.efInst.getUniformPtrPtr(name)) {
								*cast(Texture**)pp = tex;
							}
						}
					);
				}
			}
		}
	}


	private void renameInputParam(
		uword i,
		void delegate(cstring) sink
	) {
		formatTmp(
			(Fmt fmt) {
				fmt.format("tex__{}", i);
			},
			sink
		);
	}


	uint rsIdx = 0;

	private RenderStage* genRenderStage(
		KernelGraph graph,
		GraphNodeId[] inNodes,
		QItem[] outNodes,
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
		vertCode.append(
			"rasterPos = float4(inPos, 0, 1);\n"
			"uv = inPos * 0.5 + 0.5;",
			allocator
		);

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
		} {
			final p = vertFunc.params.add(ParamDirection.Out, "uv");
			p.hasPlainSemantic = true;
			p.type = "float2";
			p.semantic.addTrait("use", "uv");
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

		final old2new = stack.allocArray!(GraphNodeId)(graph.capacity);

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
				if (n.nid == nid) {
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
			uword numIn = 0;
			foreach (param; *oldNode.getParamList()) {
				if (!param.isOutput) {
					continue;
				}
				
				assert ("Image" == param.type);

				inputBridge.pushBack(BridgeParam(param.name, oldNid), &stack.allocRaw);
				++numIn;
			}

			// This will hold true while only the special Blit nodes are allowed
			// to split execution stages and while only one input is allowed
			// at the beginning of the post-proc pipeline.
			// If this restriction is lifted, QItem must be adjusted to carry
			// a node-param tuple instead of being only concerned aboud nodes.
			assert (1 == numIn);
		}

		foreach (i, oldNid; outNodes) {
			final oldNode = graph.getNode(oldNid.nid);
			uword numOut = 0;
			foreach (param; *oldNode.getParamList()) {
				if (!param.isInput) {
					continue;
				}
				
				assert ("Image" == param.type);

				outputBridge.pushBack(
					BridgeParam(param.name, oldNid.nid),
					&stack.allocRaw
				);

				++numOut;
			}

			if (0 == numOut) {
				error("Node {} has 0 outputs, wtf.", oldNid.nid.id);
			}

			if (numOut != 1) {
				char[] meh;
				foreach (param; *oldNode.getParamList()) {
					if (!param.isInput) {
						continue;
					}
					meh ~= param.toString ~ "   ";
				}
				error("Onoz, multiple outputs in node. {}", meh);
			}
			assert (1 == numOut);		// as above
			
			// HACK: assumes the above
			// Mark which output a given input should map to
			if (auto info = oldNid.inputSrc) {
				for (auto it = info; it; it = it.nextInSharedOutput) {
					it.outputIdx = i;
				}
			}
		}

		// Create samplers and sampler->Image funcs for the input bridge

		foreach (i, ref input; inputBridge.items) {
			final s2imgNid = subgraph.addFuncNode(samplerToImage);
			final s2imgNode = subgraph.getNode(s2imgNid);
			final dataNode = subgraph.getNode(dataNid).data();
			dataNode.sourceKernelType = SourceKernelType.Composite;

			input.newNid = s2imgNid;

			renameInputParam(i, (cstring str) {
				auto par = dataNode.params.add(ParamDirection.Out, str);
				par.hasPlainSemantic = true;
				par.type = "sampler2D";

				subgraph.flow.addDataFlow(
					dataNid, str,
					s2imgNid, "sampler"
				);
			});
		}

		// Create outputs and sampling funcs for the output bridge

		foreach (i, ref output; outputBridge.items) {
			final sampleNid = subgraph.addFuncNode(fragFunc);
			final sampleNode = subgraph.getNode(sampleNid);
			final outNode = subgraph.getNode(outNid).output();

			output.newNid = sampleNid;

			subgraph.flow.addDataFlow(
				vertNid, "uv",
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

		foreach (oldDst; oldNodes) {
			if (isInputNode(oldDst)) {
				continue;
			}
			
			bool dstIsOutput = isOutputNode(oldDst);

			foreach (oldSrc; graph.flow.iterIncomingConnections(oldDst)) {
				bool srcIsInput = isInputNode(oldSrc);
				
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

					assert (newSrc.valid);
					assert (newDst.valid);

					subgraph.flow.addDataFlow(
						newSrc, fromName,
						newDst, toName
					);
				}
			}
		}

		formatTmp((Fmt fmt) {
			fmt.format("graph{}.dot", rsIdx);
		}, (cstring name) {
			File.set(name, toGraphviz(subgraph));
		});
		++rsIdx;

		return addRenderStage(subgraph, inNid, outNid, inputBridge.length);
	}


	private RenderStage* addRenderStage(
		KernelGraph graph,
		GraphNodeId inNid,
		GraphNodeId outNid,
		uword numInputs
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

		stageEffect.compile();

		final rs = _mem._new!(RenderStage)();
		rs.next = _renderStageList;
		_renderStageList = rs;

		rs.effect = stageEffect;
		rs.efInst = _backend.instantiateEffect(stageEffect);

		final vdata = rs.efInst.getVaryingParamData("VertexProgram.structure__position");
		vdata.buffer = &_vb;
		vdata.attrib = &_va;

		final outNode = graph.getNode(outNid).output();
		
		rs.outTextures = _mem.allocArray!(Texture)(outNode.params.length);
		rs.inputs = _mem.allocArray!(StageInputSrc)(numInputs);

		return rs;
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

		_inputTexture = input;

		final finalFB = _backend.framebuffer;
		final origState = *_backend.state;

		_backend.state.depth.enabled = false;

		for (auto rs = _renderStageList; rs !is null; rs = rs.next) {
			final renderList = _backend.createRenderList();
			assert (renderList !is null);
			scope (success) _backend.disposeRenderList(renderList);

			final bin = renderList.getBin(rs.effect);
			final rdata = bin.add(rs.efInst);
			*rdata = RenderableData.init;
			rdata.coordSys = CoordSys.identity;
			final id = &rdata.indexData;
			id.indexBuffer	= _ib;
			id.numIndices	= 6;
			id.maxIndex		= 5;

			if (rs.next is null) {
				*_backend.state = origState;
				_backend.framebuffer = finalFB;
			} else {
				_backend.framebuffer = rs.fb;
				_backend.state.viewport.width = rs.fb.size.x;
				_backend.state.viewport.height = rs.fb.size.y;
			}

			_backend.render(renderList);
		}
	}


	private {
		RendererBackend	_backend;
		IKDefRegistry	_kdefRegistry;
		bool			_settingsDirty = false;

		ScratchFIFO			_allocator;
		DgScratchAllocator	_mem;

		cstring _kernelName = null;
		
		vec2i					_inputSize = vec2i.zero;
		TextureInternalFormat	_inputFormat;

		VertexBuffer	_vb;
		VertexAttrib	_va;
		IndexBuffer		_ib;

		Texture			_inputTexture;

		RenderStage*	_renderStageList;
	}
}
