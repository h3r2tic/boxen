module xf.nucled.GPUShaderPreview;

private {
	import xf.nucled.Graph : NodeContents;
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
	//import xf.dog.Dog;
	
	//import tango.io.Stdout;
	
	//alias xf.nucleus.Viewport.Viewport Viewport;
}



class GPUShaderPreview : NodeContents {
	override void doGUI() {
		/+if (viewport is null || viewport.enabled) {
			auto glViewport = GLViewport();
			glViewport.layoutAttribs = "hexpand hfill";
			glViewport.renderingHandler = &this.draw;
			glViewport.userSize(vec2(128, 80));
		}+/
	}
	
	
	override void refresh() {
		/+if (world) {
			world.markKernelsDirty();
		}
		
		if (viewport) {
			viewport.refresh();
		}+/
	}
	
	
	/+void draw(vec2i size, GL gl) {
		//gl.lookAt(vec3(-0.3, 0, 1), vec3.zero);
		// BUG: shouldn't these be in the reverse order? lookAt upsets it. probably Viewport has it all backwards
		gl.LoadIdentity();
		gl.Translatef(0, 0, -0.7);
		gl.Rotatef(30, 1, 0, 0);
		//gl.Rotatef(20, 0, 1, 0);
		
		gl.Clear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

		gl.Enable(GL_DEPTH_TEST);
		gl.Disable(GL_BLEND);
		
		if (world is null) {
			world = new NucleusWorld(nucleus, gl);
			INucleusWorld.ImportParams importParams;
			importParams.defaultKernel = kernelName;
			world.importHme(`data/scenes/teapot/scene.hme`, vec3fi[0, -.3f, 0], quat.identity, 1, importParams);
			
			foreach (leaf; &world.iterRgLeaves) {
				auto renderable = leaf.renderable;
				renderable.kernel = kernelName;
				renderable.overrideKernel(graphProcessor);
			}
			
			auto light = new PointLight(nucleus);
			with (light) {
				position = vec3(2, 1.5, 1);
				color = vec4.one * 15;
			}
			world.addEffector(light);
			
			viewport = new Viewport(world, `RenderPreview`);
		}
		
		//renderScene(scene, viewRenderable, nucleus, size, gl);
		viewport.draw(size, gl);
		if (viewport.drawingException !is null) {
			auto e = viewport.drawingException;
			e.writeOut((char[] msg) { Stdout(msg); });
			Stdout.newline;
			viewport.enabled = false;
		}
	}
	
	
	this (char[] kernelName, INucleus nucleus, char[] nodeLabel) {
		this.kernelName = kernelName;
		this.nodeLabel = nodeLabel;
		this.nucleus = nucleus;
		this.graphProcessor = new PreviewGraphProcessor(null, nucleus, nodeLabel);
		/+this.viewRenderable = nucleus.createRenderable();
		this.viewRenderable.kernel = "RenderViewport";+/
	}
	
	
	char[]			kernelName;
	char[]			nodeLabel;
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
