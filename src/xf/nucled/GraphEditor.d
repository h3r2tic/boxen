module xf.nucled.GraphEditor;

private {
	import xf.Common;
	
	import xf.hybrid.Hybrid;
	import xf.hybrid.Common;
	import xf.hybrid.CustomWidget;
	//import xf.hybrid.backend.GL;
	import xf.hybrid.Font;
	/+import xf.dog.Dog;
	import xf.dog.Cg;+/
	//import xf.utils.Bind;
	import xf.utils.Array : arrayRemove = remove;
	//import xf.utils.OldCfg : CfgLoader;
	
	import xf.nucled.DrawingUtils;
	import xf.nucled.KernelSelector;
	//import xf.nucled.Blob;
	import xf.nucled.Graph;
	import xf.nucled.Widgets;
	import xf.nucled.Misc;
	//import xf.nucled.KernelGraphGen;
	import xf.nucled.Settings;
	import xf.nucled.GPUShaderPreview : GPUShaderPreview;

	import xf.nucleus.kdef.model.IKDefRegistry;
	import xf.nucleus.kdef.Common : KDefGraph = GraphDef, KDefGraphNode = GraphDefNode, ParamListValue, Statement;
	import xf.nucleus.kernel.KernelDef;
	import xf.nucleus.KernelImpl;
	import xf.nucleus.Param;
	import xf.nucleus.IStructureData;
	import xf.nucleus.Log;

	import xf.gfx.IRenderer : RendererBackend = IRenderer;
	import xf.gfx.Texture;
	
	/+import xf.nucleus.CommonDef;
	//import xf.nucleus.KernelCore;
	import xf.nucleus.model.INucleus;
	import xf.nucleus.kernel.KernelDef;
	import xf.nucleus.graph.Node : isValidDemuxFunction;
	import xf.nucleus.Exception;
	import xf.nucleus.cg.Cg;
	import xf.nucleus.support.Texture;
	import xf.nucleus.BasicRegistration;
	import xf.nucleus.model.KernelProvider : stripKernelTemplateArgs;
	
	// for data previews
	import xf.nucleus.model.IRenderable;
	import xf.nucleus.cpu.Reflection : CPUQuark, IFlowInspector, IFlowInspectorNode, IDataInspector;
	import xf.nucleus.support.Framebuffer;
	
	import xf.linker.DefaultLinker;+/

	import xf.mem.ChunkQueue;
	import xf.mem.ScratchAllocator;

/+	import tango.text.Util;
	import tango.io.stream.Format;
	import tango.text.convert.Layout : TextLayout = Layout;
	import tango.io.device.File : FileConduit = File;
	import tango.io.model.IConduit : InputStream, OutputStream;
	import tango.sys.Process;+/
	
	import tango.stdc.stdio : sscanf;
	import tango.stdc.stringz;

	import tango.core.Thread;
	//import tango.core.Memory : GC;
	import tango.io.Stdout;

	import tango.text.convert.Format;

	import xf.mem.StackBuffer;
}


/+
struct DataPreviewCache {
	const int		updatePeriod = 10;
	int				updateTick;
	Texture			previewData;
	vec2i			previewSize = {x: 160, y: 100};


	void dispose() {
		if (previewData.valid) {
			previewData.release();
		}
	}
	
	void updateWithTex(Texture fbTex, vec2 tc) {
		assert (fbTex._res_mngr !is null);
		auto gl = fbTex.getGL();

		/+if (glViewport !is null) {
			glViewport.widgetVisible = true;
		}+/
		
		auto cfg = FramebufferConfig(FramebufferLocation.Offscreen);
		cfg.size = previewSize;

		TextureRequest treq;
		treq.pixelType = PixelType.UByte;
		treq.minFilter = TextureMinFilter.Linear;
		treq.magFilter = TextureMagFilter.Linear;
		if (this.previewData.valid) {
			this.previewData.release();
		}
		this.previewData = TextureMngr(gl).acquire(previewSize, treq);

		cfg.color[0] = this.previewData;
		auto fb = FramebufferMngr(gl).acquire(cfg);
		scope (exit) fb.release;
		
		use (fb) in {
			gl.Disable(GL_DEPTH_TEST);
			gl.MatrixMode(GL_PROJECTION);
			gl.LoadIdentity();
			gl.gluOrtho2D(0, 1, 0, 1);
			gl.MatrixMode(GL_MODELVIEW);
			gl.LoadIdentity();
			gl.Viewport(0, 0, previewSize.tuple);
			gl.Disable(GL_SCISSOR_TEST);
			
			gl.Enable(fbTex.glTarget);
			gl.Disable(GL_BLEND);
			gl.BindTexture(fbTex.glTarget, fbTex.id);
			
			gl.Color3f(1, 1, 1);
			gl.immediate(GL_QUADS, {
				gl.TexCoord2f(0, 0);
				gl.Vertex2f(0, 0);
				gl.TexCoord2f(tc.x, 0);
				gl.Vertex2f(1, 0);
				gl.TexCoord2f(tc.x, tc.y);
				gl.Vertex2f(1, 1);
				gl.TexCoord2f(0, tc.y);
				gl.Vertex2f(0, 1);
			});
			
			gl.Enable(GL_SCISSOR_TEST);
		};
	}

	void update(void* ptr, TypeInfo ti) {
		if (ti is typeid(Framebuffer)) {
			if (previewData.valid && (++updateTick % updatePeriod != 0)) {
				return;
			}
			
			auto srcFb = (cast(Framebuffer*)ptr);
			auto fbTex = srcFb.acquireColorTexture(0);
			if (fbTex.valid) {
				scope (exit) fbTex.release();
				updateWithTex(fbTex, vec2.from(srcFb.size) / vec2.from(fbTex.size));
			}
		} else if (ti is typeid(Texture)) {
			updateWithTex(*(cast(Texture*)ptr), vec2.one);
		}
	}
}


class DataPreview : NodeContents, IDataInspector {
	GLViewport			glViewport;
	char[]					fieldName;
	DataPreviewCache	cache;
	FlowInspector		flowInspector;
	
	
	void doGUI() {
		if (cache.previewData.valid || flowInspector !is null) {
			glViewport = GLViewport();
			glViewport.renderingHandler = &this.draw;
			vec2i size = vec2i.zero;
			if (cache.previewData.valid) {
				size = cache.previewSize;
			}
			if (flowInspector !is null) {
				size.x += flowInspector.requiredSize.x;
				size.y = max(size.y, flowInspector.requiredSize.y);
			}
			glViewport.userSize(vec2.from(size));
		}
	}
	
	
	void refresh() {
		cache.dispose();
	}
	
	
	void inspect(char[] funcName, char[] paramName, Param.Direction dir, void* ptr, TypeInfo ti) {
		if (dir != Param.Direction.Out) {
			return;
		}
		
		// only show the first param
		if (fieldName is null) {
			fieldName = paramName;
		} else if (fieldName != paramName) {
			return;
		}
		
		cache.update(ptr, ti);
	}
	
	
	// implements IDataInspector
	FlowInspector createFlowInspector() {
		assert (flowInspector is null);		// uh, TODO: disposing it?
		return flowInspector = new FlowInspector;
	}
	
	
	void draw(vec2i size, GL gl) {
		gl.MatrixMode(GL_PROJECTION);
		gl.LoadIdentity();
		gl.gluOrtho2D(0, size.x, size.y, 0);
		gl.MatrixMode(GL_MODELVIEW);
		gl.LoadIdentity();
		gl.Disable(GL_BLEND);
		gl.Disable(GL_DEPTH_TEST);

		void drawCache(DataPreviewCache cache, vec2i size, vec2i position) {
			if (cache.previewData.valid) {
				gl.Enable(cache.previewData.glTarget);
				gl.BindTexture(cache.previewData.glTarget, cache.previewData.id);
				
				gl.Color3f(1, 1, 1);
				gl.immediate(GL_QUADS, {
					gl.TexCoord2f(0, 0);
					gl.Vertex2f(position.x, position.y + size.y);
					gl.TexCoord2f(1, 0);
					gl.Vertex2f(position.x + size.x, position.y + size.y);
					gl.TexCoord2f(1, 1);
					gl.Vertex2f(position.x + size.x, position.y);
					gl.TexCoord2f(0, 1);
					gl.Vertex2f(position.x, position.y);
				});
				
				gl.Disable(cache.previewData.glTarget);
			} else {
				gl.Color3f(1, 1, 0);
				gl.immediate(GL_QUADS, {
					gl.Vertex2f(position.x, position.y);
					gl.Vertex2f(position.x + size.x, position.y);
					gl.Vertex2f(position.x + size.x, position.y + size.y);
					gl.Vertex2f(position.x, position.y + size.y);
				});
			}
		}
		
		vec2i outputPos = vec2i.zero;
		if (auto ins = flowInspector) {
			outputPos.x = ins.requiredSize.x;
			outputPos.y = (ins.requiredSize.y - cache.previewSize.y) / 2;
			
			foreach (name, node; ins.nodes) {
				drawCache(node.cache, node.cache.previewSize, node.position);
			}
		}
		
		drawCache(cache, cache.previewSize, outputPos);
	}
}


class FlowInspector : IFlowInspector {
	FlowInspectorNode createNode(char[] name) {
		dirty = true;
		auto n = new FlowInspectorNode;
		nodes[name] = n;
		return n;
	}
	
	void connect(char[] src, char[] dst) {
		dirty = true;
		connections[src] ~= dst;
	}
	
	
	vec2i requiredSize() {
		recalc();
		return _requiredSize;
	}
	
	
	private {
		void calcRequiredSize() {
			vec2i from = vec2i(int.max, int.max);
			vec2i to = vec2i(int.min, int.min);
			
			foreach (_meh, node; nodes) {
				from.x = min(from.x, node.position.x);
				from.y = min(from.y, node.position.y);
				to.x = max(to.x, node.position.x + node.size.x);
				to.y = max(to.y, node.position.y + node.size.y);
			}
			
			_requiredSize = to - from;
			
			foreach (_meh, ref node; nodes) {
				node.position -= from;
			}
		}
		
		
		void recalc() {
			if (dirty) {
				dirty = false;
				doLayout();
				calcRequiredSize();
			}
		}
		
		
		void doLayout() {
			char[] dot = "Digraph G { graph [dpi=1, fixedsize=true, concentrate=true, remincross=true, ratio=compress, nodesep=0.2, rankdir=LR];\n";
			foreach (name, node; nodes) {
				dot ~= name ~ " [shape=box, width=160, height=100];\n";
			}
			foreach (from, toArr; connections) {
				foreach (to; toArr) {
					dot ~= from ~ " -> " ~ to ~ ";\n";
				}
			}
			dot ~= "}";
			
			auto p = new Process(true, "dot/dot.exe", "-Tplain");
			p.workDir = "dot";
			p.execute;
			p.stdin.write(dot);
			p.stdin.close();
			p.stderr.close();
			char[] data = cast(char[])p.stdout.load();
			Stdout.formatln("yay got graphviz data: {}", data);
			
			foreach (line; tango.text.Util.lines(data)) {
				char[64] n1, n2;
				char[256] buf;
				float x, y, w, h;
				if (5 == sscanf(toStringz(line, buf[]), "node %63s %f %f %f %f", n1.ptr, &x, &y, &w, &h)) {
					auto node = nodes[fromStringz(n1.ptr)];
					node.size.x = cast(int)w;
					node.size.y = cast(int)h;
					node.position.x = cast(int)x;
					node.position.y = cast(int)y;
					node.position -= node.size / 2;
				}

				else if (2 == sscanf(toStringz(line), "edge %63s %63s", n1.ptr, n2.ptr)) {
					Stdout.formatln("yay, a connection");
				}
			}
			
			delete data;
		}
	}
	
	
	FlowInspectorNode[char[]]	nodes;
	char[][][char[]]					connections;

	private {
		bool								dirty;
		vec2i							_requiredSize;
	}
}


class FlowInspectorNode : IFlowInspectorNode {
	DataPreviewCache	cache;
	vec2i					position;		// top-left corner
	vec2i					size;
	
	void inspect(void* ptr, TypeInfo ti) {
		cache.update(ptr, ti);
	}
	
	void dispose() {
		cache.dispose();
	}
}+/



class GraphEditor {
	this (
		cstring kernelName,
		IKDefRegistry registry,
		RendererBackend backend,
		GraphMngr graphMngr
	) {
		_kernelName = kernelName;
		_graph = new Graph(graphMngr);
		_graph.loadObservers ~= &this.onGraphLoad;
		_background = new Background;
		_background.iterConnections = &_graph.iterAllConnections;
		_background.graphMngr = graphMngr;
		_ksel = new KernelSelectorPopup;
		_ksel.kernels = &registry.kernelImpls;
		_graphMngr = graphMngr;
		_registry = registry;
		_backend = backend;
	}


	Graph graph() {
		return _graph;
	}
	
	
	void setObjectsForPreview(IStructureData[] obj) {
		_objectsForPreview = obj;
	}
	
	
	protected void onGraphLoad(Graph g) {
		/+if (_renderableForPreview !is null) {
			if (_renderableForPreview.prepare()) {
				assert (g is _graph);
				CPUQuark[char[]] cpuQuarks;

				foreach (quarkName, cpuQuark; &_renderableForPreview.linkedKernel.iterCPUQuarks) {
					cpuQuarks[quarkName] = cpuQuark;
				}
				
				foreach (n; g.nodes) {
					auto dp = new DataPreview;
					n.contents = dp;
					if (auto cpuQuark = n.label in cpuQuarks) {
						(*cpuQuark).dataInspector = dp;
					}
				}
			}
		}+/
	}


	/+char[] savedGraphFile() {
		return _kernelName ~ ".kgraph";
	}+/
	

	/+void generateKernelGraph() {
		if (!tryRecompile) {
			return;
		}
		
		//markSceneKernelsDirty(scene);
		kernelGraphReady = false;
		assert (_graph !is null);
		
		pragma (msg, "TODO: saving graph kernels into temporary .kdef files and loading them using the normal approach instead of using KernelGraphGen");
		
		
		/+scope gen = new KernelGraphGen(_core);
		
		try {
			auto kernelGraph = gen.generate(_graph);
			_core.linker.clearCache();
			_core.matcher.clearImpls(_kernelName);
			_core.matcher.registerImpl(_kernelName, kernelGraph, 100);
			kernelGraphReady = true;
			tryRecompile = false;
		} catch (NucleusException exc) {
			Stdout("Exception while generating a kernel graph:").newline;
			exc.writeOut((char[] msg) { Stdout(msg); });
			Stdout.newline;
		} catch (Exception exc) {
			/+Stdout.formatln("ERROR: {} - {}({}) - {}", exc.toString, exc.file, exc.line, exc.info ? exc.info.toString : "");
			if (exc.info) {
				Stdout(exc.info.toString);
			}+/
			exc.writeOut((char[] msg) { Stdout(msg); });
			Stdout.newline;
		}+/
	}+/
	

	GraphNode selected() {
		return _graphMngr.selected;
	}

	
	void refresh(/+char[] tmpFileName+/) {
		Stdout.formatln(`GraphEditor.refresh`);
		tryRecompile = true;
		//generateKernelGraph(tmpFileName);
		
		foreach (n; _graph.nodes) {
			refreshContents(n);
		}
	}


	void onParamsChanged() {
		foreach (n; _graph.nodes) {
			if (auto sp = cast(GPUShaderPreview)n.contents) {
				sp.onParamsChanged(_graph);
			}
		}
	}


	void refreshContents(GraphNode n) {
		foreach (i, con; &n.iterOutputs) {
			if (con.name == depOutputConnectorName) {
				continue;
			}

			final memfifo = new ScratchFIFO;
			final mem = DgScratchAllocator(&memfifo.pushBack);

			final graphDef = mem._new!(GraphDef)(
				cast(Statement[])null,
				mem._allocator
			);

			graph.dump(graphDef, _registry);

			if (n.contents is null) {
			//try {
				final sp = new GPUShaderPreview(
					_backend,
					_registry,
					KernelImpl(graphDef),
					n.label, con.name
				);
				n.contents = sp;

				sp.setObjects(_objectsForPreview);
				sp.compileEffects();

				break;
			/+} catch (NucleusException e) {
				e.writeOut((cstring s) {
					Stdout(e);
					Stdout.newline;
				});
				n.contents = null;
			}+/
			} else if (auto gsp = cast(GPUShaderPreview)n.contents) {
				gsp._renderer.materialToUse = KernelImpl(graphDef);
				n.contents.refresh();
			}
		}
	}
	
	
	void loadKernelGraph(KDefGraph source) {
		assert (source !is null);
		
		_graph.clearNodes();
		_graph.load(source);

		foreach (n; _graph.nodes) {
			if (n.isKernelBased) {
				auto kernel = _registry.getKernel(n.kernelName);
				if (!kernel.isValid) {
					throw new Exception("loadKernelGraph(): could not find a kernel named '" ~ n.kernelName ~ "' in the registry");
				} else {
					createKernelNodeInputs(n, kernel);
				}
			}

			refreshContents(n);
		}
	}


	void createIONodes(ParamList params) {
		final inode = new GraphNode(GraphNode.Type.Input);
		final onode = new GraphNode(GraphNode.Type.Output);

		_graph.addNode(inode);
		_graph.addNode(onode);

		inode.spawnPosition = vec2(100, this.workspaceSize.y / 2);
		onode.spawnPosition = vec2(this.workspaceSize.x - 200, this.workspaceSize.y / 2);

		foreach (param; params) {
			assert (param.hasPlainSemantic, "TODO: impl of kernels with sem exprs");
			if (param.isInput) {
				inode.addOutput(param);
			}
			if (param.isOutput) {
				onode.addInput(param);
			}
		}
	}


	void createKernelNodeInputs(GraphNode node, KernelImpl impl) {
		if (KernelImpl.Type.Kernel == impl.type) {
			final kernel = impl.kernel;
			final func = kernel.func;

			foreach (param; func.params) {
				Stdout.formatln(`Creating a param '{}'`, param.name);
				if (param.isInput) {
					node.inputs ~= new ConnectorInfo(param, node);
				} else {
					node.outputs ~= new ConnectorInfo(param, node);
				}
			}
		} else {
			final graph = cast(GraphDef)impl.graph;
			foreach (name, n; graph.nodes) {
				if ("input" == n.type) {
					foreach (param; n.params) {
						node.inputs ~= new ConnectorInfo(param, node);
					}
				} else if ("output" == n.type) {
					foreach (param; n.params) {
						node.outputs ~= new ConnectorInfo(param, node);
					}
				}
			}
		}
	}

	
	void dismissable(void delegate() dg) {
		if (DismissableOverlay(`.dismissableOverlay`) [{
			dg();
		}].dismissed) {
			mode = Mode.Default;
		}
	}
	
	
	vec2 rightMouseButtonDownPos = vec2.zero;
	vec2 workspaceOffset = vec2.zero;
	
	
	EventHandling workspaceClickHandler(ClickEvent e) {
		if (e.bubbling && !e.handled && MouseButton.Left == e.button) {
			_graphMngr.onNodeSelected(null);
		}

		return EventHandling.Continue;
	}
	
	
	EventHandling workspaceMouseButtonHandler(MouseButtonEvent e) {
		if (Mode.Default == mode && MouseButton.Right == e.button && (e.bubbling && !e.handled)) {
			if (e.down) {
				rightMouseButtonDownPos = e.pos + workspaceOffset;
			} else if ((rightMouseButtonDownPos - (e.pos + workspaceOffset)).length < 4) {
				/+if (auto selected = _graphMngr.selected) {

					gui().popup!(VBox)(selected) = (GraphNode sel) {
						return contextMenu(
							menuGroup("template?",
								menuLeaf("true", sel.isTemplate = true),
								menuLeaf("false", sel.isTemplate = false)
							)
						).isOpen;
					};

				} else {+/
					mode = Mode.NodeSelection;
					spawnPosition = e.pos;
					spawnPosWindow = gui.mousePos;
				//}

				return EventHandling.Stop;
			}
		}
		
		return EventHandling.Continue;
	}
	
	
	void doGUI() {
		// TODO
		auto wb = CustomDraw();
		if (!wb.initialized) {
			wb.renderingHandler = &_background.draw;
			wb.layoutAttribs = "hfill vfill";
		}
		_background.viewGlobalOffset = wb.globalOffset;

		this.workspaceSize = wb.size;

		auto dragView = DraggableView() [{
			auto wk = Workspace(); wk [{
				_graph.doGUI;
			}];
			
			if (!wk.initialized) {
				wk.addHandler(&workspaceMouseButtonHandler);
				wk.addHandler(&workspaceClickHandler);
				wk.layoutAttribs = "hfill vfill";
				wk.infinite = true;
			}
			
			this.workspaceOffset = wk.parentOffset;
		}];
		
		if (!dragView.initialized) {
			dragView.layoutAttribs = "hfill vfill";
		}
	

		if (Mode.KernelSelection == mode) {
			bool kernelFilter(KernelImpl kernel) {
				return true;
			};

			KernelImpl	kernel;
			
			dismissable = {
				padded(70) = {
					if (_ksel.doGUI(&kernelFilter, kernel)) {
						mode = Mode.Default;
						
						auto node = new GraphNode(spawningType, kernel.name);
						node.spawnPosition = spawnPosition;
						//node.CPU = kernel.type == KernelDef.Type.CPU;
						createKernelNodeInputs(node, kernel);
						node.label = Format("node_{}", node.id);
													
						/+auto func = kernel.getFunction(funcName);
						
						foreach (param; &func.iterParams) {
							if (param.isInput) {
								node.inputs ~= new ConnectorInfo(param.name, node);
							} else {
								node.outputs ~= new ConnectorInfo(param.name, node);
							}
						}+/
						
						_graph.addNode(node);
					}
				};
			};
		} else if (Mode.NodeSelection == mode) {
			dismissable = {
				globalPos(spawnPosWindow) = {
					Button layout(Button b) {
						b.layoutAttribs = "vexpand";
						(cast(Label)b.getSub(`label`)).fontSize = 10;
						b.userSize = vec2(65, 55);
						return b;
					}
					
					VBox().spacing(5) [{
						HBox().spacing(5) [{
							Dummy().layoutAttribs(`hexpand hfill`);

							if (layout(Button()).text(`input`).clicked) {
								mode = Mode.Default;
								auto node = new GraphNode(GraphNode.Type.Input);
								node.spawnPosition = spawnPosition;
								_graph.addNode(node);
							}

							if (layout(Button()).text(`output`).clicked) {
								mode = Mode.Default;
								auto node = new GraphNode(GraphNode.Type.Output);
								node.spawnPosition = spawnPosition;
								_graph.addNode(node);
							}

							Dummy().layoutAttribs(`hexpand hfill`);
						}].layoutAttribs = "hexpand hfill vexpand vfill";

						HBox().spacing(5) [{
							Dummy().layoutAttribs(`hexpand hfill`);

							if (layout(Button()).text(`data`).clicked) {
								mode = Mode.Default;
								auto node = new GraphNode(GraphNode.Type.Data);
								node.spawnPosition = spawnPosition;
								_graph.addNode(node);
							}

							if (layout(Button()).text(`calc`).clicked) {
								mode = Mode.KernelSelection;
								spawningType = GraphNode.Type.Calc;
							}

							Dummy().layoutAttribs(`hexpand hfill`);
						}].layoutAttribs = "hexpand hfill vexpand vfill";
					}];
				};
			};
		}
	}
	
	
	private {
		enum Mode {
			Default,
			NodeSelection,
			KernelSelection
		}
		Mode mode = Mode.Default;


		vec2				spawnPosition = vec2.zero;
		vec2				spawnPosWindow = vec2.zero;
		GraphNode.Type		spawningType;

		bool				kernelGraphReady = false;
		bool				tryRecompile = false;

		IStructureData[]	_objectsForPreview;

		char[]				_kernelName;
		IKDefRegistry		_registry;
		RendererBackend		_backend;
		//INucleus			_core;
		Graph				_graph;
		Background			_background;
		KernelSelectorPopup	_ksel;
		
		GraphMngr			_graphMngr;

		//IRenderable				_renderableForPreview;
	}

	public {
		vec2				workspaceSize = vec2.zero;
	}
}



class Background {
	int delegate(int delegate(ref Connection))	iterConnections;
	vec2										viewGlobalOffset;
	GraphMngr									graphMngr;

	struct CurveToDraw {
		vec2	src;
		vec2	dst;
	}
	
	CurveToDraw[]	_thinCurves;
	CurveToDraw[]	_thickCurves;


	void drawThick(GuiRenderer r) {
		foreach (c; _thickCurves) {
			vec4 innerColor = vec4(0, 0, 0, 0.01);
			vec4 outerColor = vec4(0, 0, 0, 0.04);
			vec4 lineColor = vec4(0.0, 0.0, 0.0, 0.1);
			
			const float thickness = 25f;
			
			vec2[32][3] pts;
			int numPts;
			
			const float arrowSize = 30.f;
			c.dst.x -= arrowSize;
			
			tesselateThickCurve(c.src, c.dst, thickness, (vec2 p0, vec2 p1, vec2 p2) {
				pts[0][numPts] = p0;
				pts[1][numPts] = p1;
				pts[2][numPts] = p2;
				++numPts;
			});
			
			vec2[3] arrowPoints; {
				vec2 p = pts[1][numPts-1];
				p.x += arrowSize;
				arrowPoints[0] = p;
				arrowPoints[1] = p + vec2(-arrowSize, -(thickness*0.5f+arrowSize*0.3f));
				arrowPoints[2] = p + vec2(-arrowSize, (thickness*0.5f+arrowSize*0.3f));
			}

			uword numTris = 4 + (numPts-1)*4;
			scope stack = new StackBuffer;

			vec2[] triPoints = stack.allocArrayNoInit!(vec2)(numTris*3);
			vec4[] triColors = stack.allocArrayNoInit!(vec4)(numTris*3);

			uword numVerts = 0;
			
			{
				vec4 color = vec4.zero;
				void vertex(float* p) {
					triColors[numVerts] = color;
					triPoints[numVerts] = *cast(vec2*)p;
					++numVerts;
				}

				auto center = (arrowPoints[1] + arrowPoints[2]) * 0.5f;
				
				color = innerColor;
				vertex(arrowPoints[0].ptr);
				color = innerColor;
				vertex(center.ptr);
				color = outerColor;
				vertex(pts[2][numPts-1].ptr);

				color = innerColor;
				vertex(arrowPoints[0].ptr);
				color = outerColor;
				vertex(pts[0][numPts-1].ptr);
				color = innerColor;
				vertex(center.ptr);

				color = outerColor;

				vertex(arrowPoints[0].ptr);
				vertex(arrowPoints[2].ptr);
				vertex(pts[0][numPts-1].ptr);
				
				vertex(arrowPoints[0].ptr);
				vertex(pts[2][numPts-1].ptr);
				vertex(arrowPoints[1].ptr);
			}

			{
				vec2 p0, p1, p2, p3;
				void add(vec4 c0, vec4 c1) {
					triColors[numVerts] = c0;
					triPoints[numVerts] = p0;
					++numVerts;
					
					triColors[numVerts] = c1;
					triPoints[numVerts] = p1;
					++numVerts;

					triColors[numVerts] = c0;
					triPoints[numVerts] = p2;
					++numVerts;


					triColors[numVerts] = c0;
					triPoints[numVerts] = p2;
					++numVerts;

					triColors[numVerts] = c1;
					triPoints[numVerts] = p1;
					++numVerts;

					triColors[numVerts] = c1;
					triPoints[numVerts] = p3;
					++numVerts;
				}
				
				for (int i = 0; i+1 < numPts; ++i) {
					p0 = pts[0][i];
					p1 = pts[1][i];
					p2 = pts[0][i+1];
					p3 = pts[1][i+1];

					add(outerColor, innerColor);
				}

				for (int i = 0; i+1 < numPts; ++i) {
					p0 = pts[1][i];
					p1 = pts[2][i];
					p2 = pts[1][i+1];
					p3 = pts[2][i+1];

					add(innerColor, outerColor);
				}
			}

			assert (numVerts == numTris*3);
			r.triangles(triPoints, triColors);

			float lineThickness = 1.0f;

			r.color(lineColor);
			r.line(pts[0][0..numPts], lineThickness);
			r.line(pts[2][0..numPts], lineThickness);

			{
				vec2[8] arrow = void;
				arrow[0] = pts[2][numPts-1];
				arrow[1] = arrowPoints[1];

				arrow[2] = arrowPoints[1];
				arrow[3] = arrowPoints[0];

				arrow[4] = arrowPoints[0];
				arrow[5] = arrowPoints[2];

				arrow[6] = arrowPoints[2];
				arrow[7] = pts[0][numPts-1];
				r.lines(arrow[], lineThickness);
			}
		}
	}
	
	
	void drawThin(GuiRenderer r) {
		r.color(vec4(1, 1, 1, .3));
		const int numSegments = 16;

		foreach (c; _thinCurves) {
			vec2[numSegments+1]	pts;
			uint				numPts;

			bool fwoosh = false;
			tesselateCurve(numSegments, c.src, c.dst, (vec2 p) {
				pts[numPts++] = p;
			});

			r.line(pts[0..numPts], 1.5f);
		}
	}
	
	
	void draw(vec2i size, GuiRenderer r) {
		/+gl.MatrixMode(GL_PROJECTION);
		gl.LoadIdentity();
		gl.gluOrtho2D(0, size.x, size.y, 0);
		gl.MatrixMode(GL_MODELVIEW);
		gl.LoadIdentity();
		
		gl.Translatef(-viewGlobalOffset.x, -viewGlobalOffset.y, 0);
		
		gl.LineWidth(2);
		gl.Enable(GL_LINE_SMOOTH);
		gl.Enable(GL_BLEND);
		gl.BlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

		cpuBlob.pointSize = findBlobSize(true);
		vertexBlob.pointSize = findBlobSize(false);
		fragmentBlob.pointSize = findBlobSize(false);
		cpuBlob.draw(gl);
		vertexBlob.draw(gl);
		fragmentBlob.draw(gl);+/
		
		if (graphMngr.connecting) {
			vec2 src;
			vec2 dst;
			bool thick = false;
			
			if (graphMngr.connectingFromInput) {
				src = graphMngr.mousePos;
				dst = graphMngr.connectingFrom.windowPos;
				thick = .depInputConnectorName == graphMngr.connectingFrom.name;
			} else {
				src = graphMngr.connectingFrom.windowPos;
				dst = graphMngr.mousePos;
				thick = .depOutputConnectorName == graphMngr.connectingFrom.name;
			}

			src -= viewGlobalOffset;
			dst -= viewGlobalOffset;
			
			if (thick) {
				_thickCurves ~= CurveToDraw(src, dst);
			} else {
				_thinCurves ~= CurveToDraw(src, dst);
			}
		}		
		
		foreach (con; iterConnections) {
			foreach (fl; con.flow) {
				auto src = con.from.outputs.find(fl.from);
				auto dst = con.to.inputs.find(fl.to);
				assert (src !is null, fl.from);
				assert (dst !is null, fl.to);
				
				bool thick = .depOutputConnectorName == fl.from;

				if (thick) {
					_thickCurves ~= CurveToDraw(
						src.windowPos - viewGlobalOffset,
						dst.windowPos - viewGlobalOffset
					);
				} else {
					_thinCurves ~= CurveToDraw(
						src.windowPos - viewGlobalOffset,
						dst.windowPos - viewGlobalOffset
					);
				}
			}
		}
		

		drawThick(r);
		drawThin(r);
		_thickCurves.length = 0;
		_thinCurves.length = 0;
	}
}
