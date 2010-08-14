module xf.nucled.GPUShaderPreview;

private {
	import xf.Common;
	import xf.nucled.Graph : NodeContents, Graph, GraphNode;
	import xf.nucled.PreviewRenderer;

	import xf.nucleus.kdef.model.IKDefRegistry;
	import xf.nucleus.IStructureData;
	import xf.nucleus.Param;
	import xf.nucleus.KernelImpl;
	import xf.gfx.IRenderer : RendererBackend = IRenderer;

	import xf.hybrid.Common;

	/+import xf.nucleus.model.INucleus;
	import xf.nucleus.Renderable;
	import xf.nucleus.Effector;
	import xf.nucleus.model.INucleusWorld;
	import xf.nucleus.NucleusWorld;
	import xf.nucleus.rg.Node;
	import xf.nucleus.rg.Leaf;
	import xf.nucleus.rg.FlatGroup;
	import xf.nucleus.model.GraphProcessor;
	import xf.nucleus.Viewport;
	import xf.nucleus.graph.Node : CalcNode, Node, GPUWrapNode, OutputNode, DataFlow;
	import xf.nucleus.graph.Graph : _connect;
	import xf.nucleus.CommonDef;+/

	//import tango.core.Variant;
	//import xf.hybrid.backend.GL;
	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.CoordSys;
	import xf.omg.util.ViewSettings;

	import xf.mem.StackBuffer;
	import xf.mem.ScratchAllocator;
	//import xf.dog.Dog;
	
	//import tango.io.Stdout;
	
	//alias xf.nucleus.Viewport.Viewport Viewport;
}


class CustomDrawWidget : Widget {
	override EventHandling handleRender(RenderEvent e) {
		if (!widgetVisible) {
			return EventHandling.Stop;
		}
		
		if (e.sinking && renderingHandler) {
			if (auto r = e.renderer) {
				r.pushClipRect();
				r.clip(Rect(this.globalOffset, this.globalOffset + this.size));
				r.direct(&this._handleRender, Rect(this.globalOffset, this.globalOffset + this.size));
				r.popClipRect();
			}
		}

		return EventHandling.Continue;
	}

	void _handleRender(GuiRenderer r) {
		renderingHandler(vec2i.from(this.size));
	}

	void delegate(vec2i) renderingHandler;

	mixin MWidget;
}



class GPUShaderPreview : NodeContents {
	override void doGUI() {
		auto w = CustomDrawWidget();
		w.layoutAttribs = "hexpand hfill";
		w.renderingHandler = &this.draw;
		w.userSize(vec2(140, 100));
	}
	
	
	override void refresh() {
		/+if (world) {
			world.markKernelsDirty();
		}
		
		if (viewport) {
			viewport.refresh();
		}+/
	}
	
	
	void draw(vec2i size) {
		_backend.framebuffer.settings.clearColorValue[0] = vec4.zero;
		_backend.framebuffer.settings.clearColorEnabled[0] = true;
		_backend.clearBuffers();

		ViewSettings vs;
		vs.eyeCS = CoordSys(vec3fi[0.14, 1.7, 1.9], quat.xRotation(-30.f));
		vs.verticalFOV = 62.f;		// in Degrees; _not_ half of the FOV
		vs.aspectRatio = cast(float)size.x / size.y;
		vs.nearPlaneDistance = 0.1f;
		vs.farPlaneDistance = 100.0f;
		_renderer.render(vs);
	}


	void setObjects(IStructureData[] obj) {
		_renderer.setObjects(obj);
	}


	void compileEffects() {
		_renderer.compileEffects();
	}


	void onParamsChanged(Graph kg) {
		scope stack = new StackBuffer;
		final plist = ParamList(&stack.allocRaw);

		foreach (n; kg.nodes) {
			if (GraphNode.Type.Data != n.type) {
				continue;
			}

			if (n.data) {
				foreach (p; n.data.params) {
					if (p.value) {
						plist.add(p);
					}
				}
			}
		}
		
		_renderer.materialParams = plist;
		_renderer.updateMaterialData();
		_renderer.materialParams = ParamList.init;
	}
	
	
	this (
		RendererBackend backend,
		IKDefRegistry reg,
		KernelImpl matKernel,
		cstring nodeLabel,
		cstring nodeOutput
	) {
		this._backend = backend;
		//this.kernelName = kernelName;
		this.nodeLabel = nodeLabel;
		//this.nucleus = nucleus;
		//this.graphProcessor = new PreviewGraphProcessor(null, nucleus, nodeLabel);
		_renderer = new MaterialPreviewRenderer(
			backend,
			reg,
			nodeLabel, nodeOutput
		);

		_renderer.materialToUse = matKernel;
/+
		// HACK

		foreach (mname, mat; &reg.materials) {
			if ("tmpMat" == mname){
				_renderer.materialToUse = mat.materialKernel;
			}
		}+/

		assert (_renderer.materialToUse.isValid);

		_renderer.structureToUse = reg.getKernel("DefaultMeshStructure");
		
		
		/+this.viewRenderable = nucleus.createRenderable();
		this.viewRenderable.kernel = "RenderViewport";+/
	}
	

	RendererBackend			_backend;
	MaterialPreviewRenderer _renderer;
	cstring					nodeLabel;
	/+char[]			kernelName;
	//IRenderable	viewRenderable;
	INucleus		nucleus;
	NucleusWorld	world;
	Viewport		viewport;
	
	PreviewGraphProcessor	graphProcessor;+/
}

/+

private {
	final class PreviewGraphProcessor : GraphProcessor {
		this (KernelOverride previous, INucleus nucleus, char[] nodeLabel) {
			this.nodeLabel = nodeLabel;
			super(previous, nucleus);
		}
		
		
		override void beforeLinking(ref IGraph graph) {
			if (_previous) _previous.beforeLinking(graph);
			
			auto rasterize = graph.findNode((CalcNode n) { return "Rasterize" == n.quark.kernelName; });
			auto theNode = graph.findNode((Node n) { return nodeLabel == n.label; });
			
			char[] outParamName;
			foreach (p; &theNode.iterOutputParams) {
				outParamName = p.name;
				break;
			}
			
			Node[] initialNodes;
			
			if (outParamName) {
				OutputNode outNode;
				//if (!cast(OutputNode)theNode) {
					outNode = new OutputNode;
					outNode.domain = Domain.GPU;
					outNode.primLevel = PrimLevel.Fragment;
					outNode.addParam(Param(Param.Direction.In, "float4", "forgedColorOutput", Semantic(Trait("use", Variant("color"[])))));
					graph.addNode(outNode);
				/+} else {
					outNode = cast(OutputNode)theNode;
					outNode
				}+/

				_connect(false, theNode, outNode, [DataFlow(outParamName, "forgedColorOutput")]);
				initialNodes ~= outNode;
			}
			
			GPUWrapNode gpuWrap = graph.findNode((GPUWrapNode) { return true; });
			if (gpuWrap) {
				initialNodes ~= gpuWrap;
			}
			
			graph.removeUnreachable(initialNodes ~ [cast(Node)theNode, rasterize]);
		}
		
		
		char[] nodeLabel;
	}
}
+/
