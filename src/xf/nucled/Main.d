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
	xf.nucled.Dump,
	xf.nucled.MaterialBrowser,
	xf.nucled.SurfaceBrowser,
	xf.nucled.Widgets,
	xf.nucled.Intersect,
	xf.nucled.ViewportTab,

	xf.vsd.VSD,

	xf.loader.Common,

	xf.nucleus.Nucleus,
	xf.nucleus.kdef.Common,
	xf.nucleus.Scene,
	xf.nucleus.KernelImpl,
	xf.nucleus.IStructureData,
	xf.nucleus.light.Point,
	xf.nucleus.light.Spot,
	xf.nucleus.asset.CompiledSceneAsset,
	xf.nucleus.asset.compiler.SceneCompiler,
	xf.nucleus.structure.MeshStructure,

	xf.loader.scene.hsf.Hsf,
	xf.loader.Common,

	xf.omg.core.LinearAlgebra,
	xf.omg.core.CoordSys,
	xf.omg.core.Misc,
	xf.omg.color.HSV,

	xf.mem.ScratchAllocator,
	xf.mem.MainHeap,
	xf.mem.Array,

	xf.utils.Bind,
	
	tango.io.Stdout,
	tango.io.device.File,
	tango.text.convert.Format,
	tango.text.Util,
	tango.stdc.ctype,
	tango.math.random.Kiss;

import xf.hybrid.Hybrid;
import xf.hybrid.WidgetConfig : HybridConfig = Config;
import xf.hybrid.widgets.SceneView;
import xf.hybrid.backend.Gfx : HybridRenderer = Renderer, TopLevelWidget = TopLevel;

import tango.util.log.Trace;		// TMP
	


import tango.stdc.stdio : getchar;
import tango.stdc.stdlib : exit;

void main(cstring[] args) {
	try {
		(new TestApp).run;
	} catch (Exception e) {
		e.writeOut((cstring s) { Stdout(s); });
		Stdout.newline();
		Stdout.formatln("Hit me with like an Enter.");
		getchar();
		exit(1);
	}
}



struct TabDesc {
	enum Role {
		GraphEditor,
		KernelImplSelector,
		KernelImplNameSelector,
		SceneView
	}

	char[]					label;
	Role					role;
	GraphEditor				graphEditor;
	//KernelSelectorPopup	kernelSelector;

	//KernelDef				kernelDef;
	//char[]				kernelFuncName;
	
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

	Viewport	defViewport;
	SceneView	defSV;
	Renderer	defRenderer;

	ViewportTab	viewportTab;

	MaterialBrowser	matBrowser;
	SurfaceBrowser	surfBrowser;

	TabView		graphEdTabView;

	VSDRoot		vsd;

	Light[]		lights;
	vec3[]		lightOffsets;
	float[]		lightDists;
	float[]		lightSpeeds;
	float[]		lightAngles;
	vec4[]		lightIllums;

	IStructureData[]	previewObjects;
	Array!(TrayRacer)	trayRacers;

	GlobalMode	globalMode;

	
	override void configureWindow(Window wnd) {
		super.configureWindow(wnd);
/+		wnd.width = 1040;
		//wnd.height = 650;
		wnd.height = 900;+/

		wnd.width = 1040;
		wnd.height = 1200;

		wnd.title = "Nucled";
		this.exitOnEscape = false;
	}


	private GraphEditor createGraphEditor(cstring name) {
		final ge = new GraphEditor(name, kdefRegistry, rendererBackend, new GraphMngr);
		ge.setObjectsForPreview(previewObjects);
		return ge;
	}


	override void initialize() {
		setMediaDir(`../test/media`);
		initializeNucleus(this.renderer, "../test/media/kdef", ".");

		{
			cstring previewModel = `mesh/teapot.hsf`;
			
			float scale = 1f;

			SceneAssetCompilationOptions opts;
			opts.scale = scale;

			final compiledScene = compileHSFSceneAsset(
				previewModel,
				DgScratchAllocator(&mainHeap.allocRaw),
				opts
			);
			assert (compiledScene.meshes.length > 0);

			final allocator = DgScratchAllocator(&mainHeap.allocRaw);

			previewObjects.length = compiledScene.meshes.length;
			foreach (i, m; compiledScene.meshes) {
				previewObjects[i] =
					allocator._new!(MeshStructure)(m, rendererBackend);
			}
		}

		guiRenderer = new HybridRenderer(renderer);

		gui.overrideInputChannel(inputHub.mainChannel);
		
		gui.vfsMountDir(`../hybrid/`);
		guiConfig = loadHybridConfig(`./GUI.cfg`);

		paramsRollout = new ParametersRollout(kdefRegistry);

		/+tabs[0] = TabDesc(
			"Top-level pipeline",
			TabDesc.Role.GraphEditor,
			createGraphEditor(`RenderViewport`),
			null/+,
			core.kregistry[`RenderViewport`]+/
		);+/

		tabs[0] = TabDesc(
			"Scene view",
			TabDesc.Role.SceneView
		);

		vsd = VSDRoot();
		fwdRenderer = createRenderer("Forward");
		defRenderer = createRenderer("LightPrePass");

		version (FixedTest) {
			const numLights = 50;
			alias PointLight LightType;
		} else {
			const numLights = 3;
			alias SpotLight_VSM LightType;
		}
		
		for (int i = 0; i < numLights; ++i) {
			createLight((lights ~= new LightType)[$-1]);
			version (Sponza) {
				lightOffsets ~= vec3(0, 0.1 + Kiss.instance.fraction() * 10.0, 0);
				lightAngles ~= Kiss.instance.fraction() * 360.0f;
				lightDists ~= Kiss.instance.fraction() * 5;
				lightSpeeds ~= 0.7f * (0.3f * Kiss.instance.fraction() + 0.7f) * (Kiss.instance.fraction() > 0.5f ? 1 : -1);
			} else {
				lightOffsets ~= vec3(0, 2.0 + Kiss.instance.fraction() * 3.0, 0);
				lightAngles ~= Kiss.instance.fraction() * 360.0f;
				lightDists ~= Kiss.instance.fraction() * 0.3f + 0.15f;
				lightSpeeds ~= 0.2f * (0.3f * Kiss.instance.fraction() + 0.7f) * (Kiss.instance.fraction() > 0.5f ? 1 : -1);

				/+lightOffsets ~= vec3(0, -2 + Kiss.instance.fraction() * 4, 0);
				lightAngles ~= Kiss.instance.fraction() * 360.0f;
				lightDists ~= Kiss.instance.fraction() * 0.3f - 0.15f;
				lightSpeeds ~= 0.2f * (0.3f * Kiss.instance.fraction() + 0.7f) * (Kiss.instance.fraction() > 0.5f ? 1 : -1);+/
			}

			float h = cast(float)i / numLights;//Kiss.instance.fraction();
			float s = 0.2f;
			float v = 1.0f;

			vec4 rgba = vec4.zero;
			hsv2rgb(h, s, v, &rgba.r, &rgba.g, &rgba.b);

			version (FixedTest) {
				lightIllums ~= rgba * (1000.f / numLights);
			} else {
				lightIllums ~= 40 * rgba;// * (1000.f / numLights);
			}
		}

		lightIllums[0] *= 0.25;
		lightIllums[1] *= 0.35;

		lightAngles[0] = 0;
		lightAngles[1] = 120;
		lightAngles[2] = 240;
		
		lightSpeeds[0..3] = 0.1f;

		lightOffsets[0] = vec3.unitY * 4;
		lightOffsets[1] = vec3.unitY * 4;
		lightOffsets[2] = vec3.unitY * 3;

		{
			cstring model = `mesh/ubot.hsf`;
			float scale = 1.0f;

			model = getResourcePath(model);			
			scope loader = new HsfLoader;
			loader.load(model);

			SceneAssetCompilationOptions opts;
			opts.scale = scale;

			final compiledScene = compileHSFSceneAsset(
				loader,
				DgScratchAllocator(&mainHeap.allocRaw),
				opts
			);

			loadScene(compiledScene, &vsd, CoordSys.identity,
				(uword i, RenderableId rid) {
					trayRacers.growBy(i+1-trayRacers.length);
					final mem = DgScratchAllocator(&mainHeap.allocRaw);

					vec3[] pos = mem.dupArray(loader.meshes[i].positions);
					foreach (ref p; pos) {
						p *= scale;
					}
					
					trayRacers[i] = mem._new!(MeshTrayRacer)(
						pos,
						mem.dupArray(loader.meshes[i].indices)
					);
				}
			);
		}

		fwdViewport = new Viewport(fwdRenderer, &vsd, &trayRacers);
		defViewport = new Viewport(defRenderer, &vsd, &trayRacers);

		fwdViewport.contextMenuHandler = &viewportContextMenuHandler;
		defViewport.contextMenuHandler = &viewportContextMenuHandler;

		matBrowser = new MaterialBrowser(kdefRegistry, rendererBackend);
		matBrowser.setObjectsForPreview(previewObjects);

		surfBrowser = new SurfaceBrowser(kdefRegistry, rendererBackend);
		surfBrowser.setObjectsForPreview(previewObjects);
	}


	void beginMaterialSelection(RenderableId[] rids) {
		globalMode.mode = GlobalMode.Mode.SelectingMaterial;
		globalMode.selectingMaterial = GlobalMode.SelectingMaterial(
			rids
		);
	}


	void beginSurfaceSelection(RenderableId[] rids) {
		globalMode.mode = GlobalMode.Mode.SelectingSurface;
		globalMode.selectingSurface = GlobalMode.SelectingSurface(
			rids
		);
	}


	bool viewportContextMenuHandler(
		int delegate(int delegate(ref RenderableId)) selIter
	) {
		return contextMenu(
			menuLeaf("Set material", {
				RenderableId[] ids;
				foreach (s; selIter) {
					ids ~= s;
				}
				beginMaterialSelection(ids);
			}()),
			menuLeaf("Set surface", {
				RenderableId[] ids;
				foreach (s; selIter) {
					ids ~= s;
				}
				beginSurfaceSelection(ids);
			}()),
			menuGroup("stuff",
				menuLeaf("stuff1", Trace.formatln("stuff1")),
				menuLeaf("stuff2", Trace.formatln("stuff2")),
				menuLeaf("stuff3", Trace.formatln("stuff3"))
			),
			menuLeaf("heh"),
			menuLeaf("lul")
		).isOpen;
	}


	void updateLights() {
		for (int li = 0; li < lights.length; ++li) {
			lightAngles[li] += lightSpeeds[li] * 0.2;
		}

		for (int li = 0; li < lights.length; ++li) {
			lightAngles[li] = fmodf(lightAngles[li], 360.0);
		}

		static float lightDist = 0.8f;
		static float lightScale = 0.0f;
		if (0 == lightScale) lightScale = 4.5f / lights.length;

		static float lightRad = 1.0f;

		foreach (li, l; lights) {
			l.position = quat.yRotation(lightAngles[li]).xform(lightOffsets[li] + vec3(0, 0, 2) * (lightDist + lightDists[li]));
			l.lumIntens = lightIllums[li] * lightScale;
			l.radius = lightRad;
		}
	}



	int addTab() {
		// HACK
		for (int i = 0; i < 100000; ++i) {
			if (!(i in tabs)) {
				tabs[i] = TabDesc.init;
				return i;
			}
		}

		assert (false);
	}


	void onSave() {
		if (auto tabDesc = activeTab in tabs) {
			if (TabDesc.Role.GraphEditor == tabDesc.role) {
				scope f = new File("saved.kdef", File.WriteCreate);
				final ge = tabDesc.graphEditor;
				dumpGraph(ge.graph, "tmp", f);
				dumpMaterial(ge.graph, "tmp_default", "tmp", f);
			}
		}
	}


	void onEditMaterialKernel() {
		final tab = addTab();
		graphEdTabView.activeTab = activeTab = tab;
		
		tabs[tab] = TabDesc(
			"Edit Material",
			TabDesc.Role.KernelImplSelector,
			null,
			null
		);
	}


	void onImplementMaterial() {
		final tab = addTab();
		graphEdTabView.activeTab = activeTab = tab;
		
		tabs[tab] = TabDesc(
			"New Material",
			TabDesc.Role.KernelImplNameSelector,
			null,
			null
		);
	}


	KDefGraph loadKDefGraph(cstring path) {
		if (auto kdefModule = kdefRegistry.getModuleForPath(path)) {
			foreach (kname, kernel; kdefModule.kernels) {
				if (KernelImpl.Type.Graph == kernel.type) {
					return KDefGraph(kernel.graph);
				}
			}
			
			throw new Exception("could not find a graph in the module: " ~ path);
		} else {
			throw new Exception("could not load a kdef module from: " ~ path);
		}
	}


	void onLoad() {
		if (auto tabDesc = activeTab in tabs) {
			if (TabDesc.Role.GraphEditor == tabDesc.role) {
				
				/+auto vfsFile = getCompositeKernelFile(tabs[activeTab].kernelDef.name, tabs[activeTab].label, false);
				auto instream = vfsFile.input();
				scope (exit) instream.close;
				curEditor.loadKernelGraph(instream);+/
				//auto path = getCompositeKernelPath(tabs[activeTab].kernelDef.name, tabs[activeTab].compositeName, false);
				KDefGraph graphDef = loadKDefGraph("saved.kdef");
				tabDesc.graphEditor.loadKernelGraph(graphDef);
			}
		}
	}


	private bool _prevRefresh;
	void handleRefresh() {
		if (keyboard.keyDown(KeySym.F5)) {
			if (!_prevRefresh) {
				if (auto tabDesc = activeTab in tabs) {
					if (TabDesc.Role.GraphEditor == tabDesc.role) {
						tabDesc.graphEditor.refresh();
					}
				}
			}			
		} else {
			_prevRefresh = false;
		}
	}


	override void render() {
		handleRefresh();
		
		updateLights();
		
		renderer.resetState();
		renderer.clearBuffers();

		gui.begin(guiConfig);
		
		TopLevelWidget("main").userSize = vec2(window.width, window.height);

		Group(`menu`) [{
			horizontalMenu(
				menuGroup("File",
					menuLeaf("Save", onSave() ),
					menuLeaf("Load", onLoad() ),
					menuLeaf("Exit", exit(0))
				),
				menuGroup("New",
					menuLeaf("Material", onImplementMaterial() ),
					menuLeaf("Surface", {} )
				),
				menuGroup("Edit",
					menuLeaf("Material", onEditMaterialKernel() ),
					menuLeaf("Surface", {})
				),
				menuGroup("Help",
					menuLeaf("About", Stdout.formatln("help.about"))
				)
			);
		}];

		gui.push(`main`);
			doTabsGUI();
		gui.pop();

		if (GlobalMode.Mode.SelectingMaterial == globalMode.mode) {
			if (DismissableOverlay(`.dismissableOverlay`) [{
				matBrowser.doGUI();
				if (auto mat = matBrowser.selected) {
					foreach (rid; globalMode.selectingMaterial.rids) {
						renderables.material[rid]
							= getMaterialIdByName(mat.name);
						invalidateRenderable(rid);
					}
					globalMode.mode = GlobalMode.Mode.Normal;
				}
			}].dismissed) {
				globalMode.mode = GlobalMode.Mode.Normal;
			}
		} else if (GlobalMode.Mode.SelectingSurface == globalMode.mode) {
			if (DismissableOverlay(`.dismissableOverlay`) [{
				surfBrowser.doGUI();
				if (auto surf = surfBrowser.selected) {
					foreach (rid; globalMode.selectingSurface.rids) {
						renderables.surface[rid] = surf.id;
						invalidateRenderable(rid);
					}
					globalMode.mode = GlobalMode.Mode.Normal;
				}
			}].dismissed) {
				globalMode.mode = GlobalMode.Mode.Normal;
			}
		}

		paramsRollout.doGUI();

		Group(`.outputPanel`) [{
			SceneView initSv(SceneView sv) {
				if (!sv.initialized) {
					//sv.userSize = vec2(480, 300);
					sv.userSize = vec2(384, 300);
					with (sv) {
						shiftView(vec3(-0.2, 1.2, 2));
						rotatePitch(-30);
						rotateYaw(-30);
						displayMode = DisplayMode.Solid;
						viewType = ViewType.Perspective;
					}
				}
				return sv;
			}

			VBox() [{
				if (Check().text("forward: ").checked) {
					fwdSV = initSv(SceneView());
				}
			}];

			Dummy().userSize = vec2(8, 0);

			VBox() [{
				if (Check().text("deferred: ").checked) {
					defSV = initSv(SceneView());
					
					if (fwdSV) {
						defSV.yaw = fwdSV.yaw;
						defSV.pitch = fwdSV.pitch;
						defSV.roll = fwdSV.roll;
						defSV.viewOffset = fwdSV.viewOffset;
						defSV.coordSys = fwdSV.coordSys;
					}
				}
			}];

			if (fwdSV) fwdViewport.doGUI(fwdSV);
			if (defSV) defViewport.doGUI(defSV);
		}];
		
		gui.end();
		gui.render(guiRenderer);

		nucleusHotSwap();
	}

	void doTabsGUI() {
		graphEdTabView = TabView(`graphEd`);
		graphEdTabView.layoutAttribs = "hfill vfill hexpand vexpand";

		foreach (ti, td; tabs) {
			graphEdTabView.label[ti] = td.label;
		}

		gui.open;
		activeTab = graphEdTabView.activeTab;
		auto layers = Group(activeTab) [{
			if (auto tabDesc = activeTab in tabs)
			switch (tabDesc.role) {
				case TabDesc.Role.SceneView: {
					if (viewportTab is null) {
						viewportTab = new ViewportTab(fwdRenderer, &vsd, &trayRacers);
					}
					viewportTab.doGUI();
				} break;
				
				case TabDesc.Role.GraphEditor: {
					tabDesc.graphEditor.doGUI();
				} break;
					
				case TabDesc.Role.KernelImplSelector: {
					matBrowser.doGUI();
					if (auto mat = matBrowser.selected) {
						final kernel = kdefRegistry.getKernel(mat.materialKernelName);
						if (KernelImpl.Type.Graph == kernel.type) {
							final editor = createGraphEditor(mat.materialKernelName.dup);
							editor.workspaceSize = graphEdTabView.size;
							editor.loadKernelGraph(GraphDef(kernel.graph));
							//editor.createIONodes(kdefRegistry.getKernel("Material").kernel.func.params);

							tabDesc.compositeName = mat.materialKernelName.dup;
							tabDesc.label = "mat " ~ tabDesc.compositeName;
							tabDesc.graphEditor = editor;
							tabDesc.role = TabDesc.Role.GraphEditor;
						}
					}

					/+KernelDef	kernel;
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
					}+/
				} break;
					
				case TabDesc.Role.KernelImplNameSelector:
					VBox().icfg(`layout = { spacing = 5; attribs = "hexpand"; }`) [{
						char[256] buf;
						Label().text("Enter the name for the new material kernel:");

						bool isValid = true;
						
						HBox().icfg(`layout = { spacing = 5; }`) [{
							char[] name = trim(Input().icfg(`size = 200 0;`).text);
							auto okButton = Button().text("OK");

							if (name.length > 0) {
								isValid = isValidIdentifier(name);

								if (isValid && okButton.clicked) {
									final editor = createGraphEditor(name.dup);
									editor.workspaceSize = graphEdTabView.size;
									editor.createIONodes(kdefRegistry.getKernel("Material").kernel.func.params);

									tabDesc.compositeName = name.dup;
									tabDesc.label = "mat " ~ tabDesc.compositeName;
									tabDesc.graphEditor = editor;
									tabDesc.role = TabDesc.Role.GraphEditor;
								}
							}
						}];

						if (!isValid) {
							Label().icfg(`style.normal = { color = red; }`).text("This name is not valid.");
						}

						Dummy().userSize = vec2(0, 20);

						VBox() [{
							Label().text("(The name must only contain alphanumeric characters");
							Label().text("and underscores, and cannot start with a number)");
						}];
					}];
					break;

				default: assert (false);
			}

			GraphEditor curEditor = null;
			if (TabDesc.Role.GraphEditor == tabs[activeTab].role) {
				curEditor = tabs[activeTab].graphEditor;
			}

			if (curEditor !is null) {
				paramsRollout.setNode(curEditor.selected);
				if (paramsRollout.changed) {
					curEditor.onParamsChanged();
					foreach (mat; allMaterials) {
						fwdRenderer.updateMaterial(mat);
						defRenderer.updateMaterial(mat);
					}
				}
			} else {
				paramsRollout.setNode(null);
			}
		}];
		if (!layers.initialized) {
			layers.icfg(`layout = Layered;`);
			layers.layoutAttribs = "hfill vfill hexpand vexpand";
		}
		gui.close;
	}
}

bool isValidIdentifier(cstring str) {
	if (0 == str.length || (!isalpha(str[0]) && str[0] != '_')) {
		return false;
	}
	foreach (c; str[1..$]) {
		if (!isalnum(c) && c != '_') {
			return false;
		}
	}
	return true;
}
