module Main;

version (StackTracing) import tango.core.tools.TraceExceptions;

import
	xf.Common,
	xf.core.Registry,
	xf.utils.GfxApp,
	xf.test.gfx.Common,

	xf.nucled.ParametersRollout,
	xf.nucled.GraphEditor,
	xf.nucled.Graph,
	xf.nucled.Viewport,

	xf.vsd.VSD,

	xf.loader.Common,

	xf.nucleus.Nucleus,
	xf.nucleus.Scene,
	xf.nucleus.light.TestLight,
	xf.nucleus.asset.CompiledSceneAsset,
	xf.nucleus.asset.compiler.SceneCompiler,

	xf.omg.core.LinearAlgebra,
	xf.omg.core.CoordSys,
	xf.omg.core.Misc,
	xf.omg.color.HSV,

	xf.mem.ScratchAllocator,
	xf.mem.MainHeap,
	
	tango.io.Stdout,
	tango.text.convert.Format,
	tango.math.random.Kiss;

import xf.hybrid.Hybrid;
import xf.hybrid.WidgetConfig : HybridConfig = Config;
import xf.hybrid.widgets.SceneView;
import xf.hybrid.backend.Gfx : HybridRenderer = Renderer, TopLevelWidget = TopLevel;
	


void main() {
	(new TestApp).run;
}



struct TabDesc {
	enum Role {
		GraphEditor,
		KernelImplSelector,
		KernelImplNameSelector,
		SceneView
	}

	char[]						label;
	Role							role;
	GraphEditor				graphEditor;
	//KernelSelectorPopup	kernelSelector;

	//KernelDef					kernelDef;
	//char[]						kernelFuncName;
	
	private char[]			_compositeName;


	char[] compositeName() {
		return _compositeName is null ? "default" : _compositeName;
	}
	
	void compositeName(char[] n) {
		_compositeName = n;
	}
}


class TestApp : GfxApp {
	HybridRenderer	guiRenderer;
	HybridConfig	guiConfig;

	ParametersRollout	paramsRollout;
	TabDesc[int]		tabs;
	int					activeTab = 0;

	Viewport	fwdViewport;
	SceneView	fwdSV;
	Renderer	fwdRenderer;

	VSDRoot		vsd;

	TestLight[]		lights;
	vec3[]			lightOffsets;
	float[]			lightDists;
	float[]			lightSpeeds;
	float[]			lightAngles;
	vec4[]			lightIllums;

	
	override void configureWindow(Window wnd) {
		super.configureWindow(wnd);
		wnd.width = 1040;
		wnd.height = 650;
		/+wnd.width = 1050;
		wnd.height = 1680;
		wnd.fullscreen = true;+/
		wnd.title = "Hybrid hello world";
	}
	
	
	override void initialize() {
		setMediaDir(`../test/media`);
		initializeNucleus(this.renderer, "../test/media/kdef", ".");

		guiRenderer = new HybridRenderer(renderer);

		gui.overrideInputChannel(inputHub.mainChannel);
		
		gui.vfsMountDir(`../hybrid/`);
		guiConfig = loadHybridConfig(`./GUI.cfg`);

		paramsRollout = new ParametersRollout();

		tabs[0] = TabDesc(
			"Top-level pipeline",
			TabDesc.Role.GraphEditor,
			new GraphEditor(`RenderViewport`, kdefRegistry, new GraphMngr),
			null/+,
			core.kregistry[`RenderViewport`]+/
		);

		vsd = VSDRoot();
		fwdRenderer = createRenderer("Forward");

		const numLights = 3;
		for (int i = 0; i < numLights; ++i) {
			createLight((lights ~= new TestLight)[$-1]);
			lightOffsets ~= vec3(0, 0.1 + Kiss.instance.fraction() * 2.0, 0);
			lightAngles ~= Kiss.instance.fraction() * 360.0f;
			lightDists ~= 2;// + Kiss.instance.fraction();
			lightSpeeds ~= 0.7f * (0.3f * Kiss.instance.fraction() + 0.7f) * (Kiss.instance.fraction() > 0.5f ? 1 : -1);

			float h = cast(float)i / numLights;//Kiss.instance.fraction();
			float s = 0.6f;
			float v = 1.0f;

			vec4 rgba = vec4.zero;
			hsv2rgb(h, s, v, &rgba.r, &rgba.g, &rgba.b);
			lightIllums ~= rgba;
		}

		cstring model = `mesh/masha.hsf`;
		float scale = 0.02f;

		SceneAssetCompilationOptions opts;
		opts.scale = scale;

		final compiledScene = compileHSFSceneAsset(
			model,
			DgScratchAllocator(&mainHeap.allocRaw),
			opts
		);

		loadScene(compiledScene, &vsd, CoordSys(vec3fi[1, -2, 0]));
		loadScene(compiledScene, &vsd, CoordSys(vec3fi[-1, -2, 0]));

		fwdViewport = new Viewport(fwdRenderer, &vsd);
	}


	void updateLights() {
		for (int li = 0; li < lights.length; ++li) {
			lightAngles[li] += lightSpeeds[li];
		}

		for (int li = 0; li < lights.length; ++li) {
			lightAngles[li] = fmodf(lightAngles[li], 360.0);
		}

		static float lightDist = 0.8f;
		static float lightScale = 0.0f;
		if (0 == lightScale) lightScale = 10f / lights.length;

		static float lightRad = 1.0f;

		foreach (li, l; lights) {
			l.position = quat.yRotation(lightAngles[li]).xform(lightOffsets[li] + vec3(0, 0, 2) * (lightDist + lightDists[li]));
			l.lumIntens = lightIllums[li] * lightScale;
			l.radius = lightRad;
		}
	}


	override void render() {
		updateLights();
		
		renderer.resetState();
		renderer.clearBuffers();

		gui.begin(guiConfig);
		
		TopLevelWidget("main").userSize = vec2(window.width, window.height);

		Group(`menu`) [{
			horizontalMenu(
				menuGroup("File",
					/+menuLeaf("Save", onSave() ),
					menuLeaf("Load", onLoad() ),+/
					menuLeaf("Exit", exitApp())
				),
				/+menuGroup("Implement",
					menuLeaf("Kernel", {
						auto ksel = new KernelSelectorPopup;
						ksel.kernels = &core.kregistry.kernels;
						int newTab = graphEdTabView.numTabs;
						graphEdTabView.activeTab = newTab;
						tabs[newTab] = TabDesc(
							"New kernel ...",
							TabDesc.Role.KernelImplSelector,
							null,
							ksel
						);
					}())
				),+/
				menuGroup("Help",
					menuLeaf("About", Stdout.formatln("help.about"))
				)
			);
		}];

		paramsRollout.doGUI();

		gui.push(`main`);
			doTabsGUI();
		gui.pop();

		Group(`.outputPanel`) [{
			auto defCheck = Check();
			
			SceneView initSv(SceneView sv) {
				if (!sv.initialized) {
					sv.userSize = vec2(480, 300);
					with (sv) {
						shiftView(vec3(0, 1, 2));
						rotatePitch(30);
						displayMode = DisplayMode.Solid;
						viewType = ViewType.Perspective;
					}
				}
				return sv;
			}

			if (defCheck.text("forward: ").checked) {
				fwdSV = initSv(SceneView());
				Dummy().userSize = vec2(20, 0);
			}
			
			if (Check().text("deferred: ").checked) {
				/+fsv = initSv(SceneView());
				
				if (sv) {
					fsv.yaw = sv.yaw;
					fsv.pitch = sv.pitch;
					fsv.roll = sv.roll;
					fsv.viewOffset = sv.viewOffset;
					fsv.coordSys = sv.coordSys;
				}+/
			}

			if (fwdSV) fwdViewport.doGUI(fwdSV);
			//if (fsv) fviewport.doGUI(fsv);
		}];
		
		gui.end();
		gui.render(guiRenderer);
	}

	void doTabsGUI() {
		final graphEdTabView = TabView(`graphEd`);
		graphEdTabView.layoutAttribs = "hfill vfill hexpand vexpand";

		foreach (ti, td; tabs) {
			graphEdTabView.label[ti] = td.label;
		}

		gui.open;
		activeTab = graphEdTabView.activeTab;
		auto layers = Group(activeTab) [{
			if (auto tabDesc = activeTab in tabs) {
				switch (tabDesc.role) {
					case TabDesc.Role.SceneView: {
						/+if (viewportTab is null) {
							viewportTab = new ViewportTab(core, world);
						}
						viewportTab.doGUI();+/
					} break;
					
					case TabDesc.Role.GraphEditor: {
						tabDesc.graphEditor.doGUI();
					} break;
						
					/+case TabDesc.Role.KernelImplSelector:
						KernelDef	kernel;
						char[]		funcName;
						if (tabDesc.kernelSelector.doGUI(
							(KernelDef kernel, char[] funcName) {
								return true;
							},
							kernel,
							funcName
						)) {
							tabDesc.label = "new Impl!( " ~ kernel.name ~ " )";
							tabDesc.role = TabDesc.Role.KernelImplNameSelector;
							tabDesc.kernelDef = kernel;
							tabDesc.kernelFuncName = funcName;
						}
						break;
						
					case TabDesc.Role.KernelImplNameSelector:
						VBox().cfg(`layout = { spacing = 5; }`) [{
							char[256] buf;
							Label().text(buf[0..sprintf(buf.ptr, "Select a composite to edit for kernel %.*s", "TODO")]);
							
							{
								int i = 0;
								auto picker = Picker(); picker [{
									foreach (kernel, graph; &core.iterCompositeKernels) {
										assert (kernel !is null, "kernel is null");
										assert (graph !is null, "graph is null");
										if (tabDesc.kernelDef.name == kernel.name) {
											Label(i++).text = trim(graph.label).length > 0 ? trim(graph.label) : "no name o_O";
										}
									}
								}];
								if (picker.anythingPicked) {
									int j = 0;
									foreach (kernel, graph; &core.iterCompositeKernels) {
										if (tabDesc.kernelDef.name == kernel.name) {
											if (j++ == picker.pickedIdx) {
												tabDesc.compositeName = trim(graph.label).dup;
												tabDesc.label = tabDesc.kernelDef.name ~ "( " ~ tabDesc.compositeName ~ " )";
												tabDesc.graphEditor = new GraphEditor(tabDesc.kernelDef.name, core, new GraphMngr(core));

												auto path = getCompositeKernelPath(tabDesc.kernelDef.name, tabDesc.compositeName, false);
												KDefGraph graphDef = loadKDefGraph(path);
												tabDesc.graphEditor.loadKernelGraph(graphDef);

												tabDesc.role = TabDesc.Role.GraphEditor;
												break;
											}
										}
									}
								}
								
								if (0 == i) {
									Label().text("No composite kernels defined");
								}
							}
							
							HBox() [{
								char[] name = trim(Input().cfg(`size = 100 0;`).text);
								if (Button().text("New").clicked && name.length > 0) {
									tabDesc.compositeName = name.dup;
									tabDesc.label = tabDesc.kernelDef.name ~ "( " ~ tabDesc.compositeName ~ " )";
									tabDesc.graphEditor = new GraphEditor(tabDesc.kernelDef.name, core, new GraphMngr(core)),
									createKernelImplIONodes(tabDesc.kernelDef, tabDesc.kernelFuncName, tabDesc.graphEditor);
									tabDesc.role = TabDesc.Role.GraphEditor;
								}
							}];
						}];
						break;+/

					default: assert (false);
				}
			} else {
				// blah
			}
		}];
		if (!layers.initialized) {
			layers.cfg(`layout = Layered;`);
			layers.layoutAttribs = "hfill vfill hexpand vexpand";
		}
		gui.close;
	}
}
