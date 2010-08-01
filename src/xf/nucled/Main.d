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

	xf.omg.core.LinearAlgebra,
	xf.omg.core.CoordSys,
	
	tango.io.Stdout,
	tango.text.convert.Format;

import xf.nucleus.kdef.model.IKDefRegistry;
import tango.io.vfs.FileFolder;

import xf.hybrid.Hybrid;
import xf.hybrid.WidgetConfig : HybridConfig = Config;
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

	IKDefRegistry	kdefRegistry;
	FileFolder		vfs;

	ParametersRollout	paramsRollout;
	TabDesc[int]		tabs;
	int					activeTab = 0;

	
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
		guiRenderer = new HybridRenderer(renderer);

		gui.overrideInputChannel(inputHub.mainChannel);
		
		gui.vfsMountDir(`../hybrid/`);
		guiConfig = loadHybridConfig(`./GUI.cfg`);

		paramsRollout = new ParametersRollout();

		vfs = new FileFolder(".");

		kdefRegistry = create!(IKDefRegistry)();
		kdefRegistry.setVFS(vfs);
		kdefRegistry.registerFolder("../test/media/kdef");
		kdefRegistry.registerFolder(".");
		kdefRegistry.reload();
		kdefRegistry.dumpInfo();

		tabs[0] = TabDesc(
			"Top-level pipeline",
			TabDesc.Role.GraphEditor,
			new GraphEditor(`RenderViewport`, kdefRegistry, new GraphMngr),
			null/+,
			core.kregistry[`RenderViewport`]+/
		);
	}


	override void render() {
		renderer.resetState();
		renderer.clearBuffers();

		gui.begin(guiConfig);
		
		TopLevelWidget("main").userSize = vec2(window.width, window.height);

		Group(`menu`) [{
			horizontalMenu(
				menuGroup("File",
					menuGroup("New",
						menuLeaf("File", Stdout.formatln("file.new.file")),
						menuLeaf("Project", Stdout.formatln("file.new.project")),
						menuLeaf("Workspace", Stdout.formatln("file.new.workspace"))
					),
					menuGroup("Import",
						menuLeaf("File", Stdout.formatln("file.import.file")),
						menuLeaf("Net", Stdout.formatln("file.import.net"))
					),
					menuLeaf("Open", Stdout.formatln("file.open")),
					menuLeaf("Close", Stdout.formatln("file.close")),
					menuLeaf("Save", Stdout.formatln("file.save")),
					menuLeaf("Exit", exitApp())
				),
				menuGroup("Edit",
					menuLeaf("Undo", Stdout.formatln("edit.undo")),
					menuLeaf("Redo", Stdout.formatln("edit.redo")),
					menuLeaf("Cut", Stdout.formatln("edit.cut")),
					menuLeaf("Copy", Stdout.formatln("edit.copy")),
					menuLeaf("Paste", Stdout.formatln("edit.paste"))
				),
				menuGroup("View",
					menuLeaf("Refresh", Stdout.formatln("view.refresh")),
					menuLeaf("Fullscreen", Stdout.formatln("view.fullscreen")),
					menuLeaf("Cascade", Stdout.formatln("view.cascade")),
					menuLeaf("Tile", Stdout.formatln("view.tile"))
				),
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
			
			if (defCheck.text("deferred: ").checked) {
				//sv = initSv(SceneView());
				Dummy().userSize = vec2(20, 0);
			}
			
			if (Check().text("forward: ").checked) {
				/+fsv = initSv(SceneView());
				
				if (sv) {
					fsv.yaw = sv.yaw;
					fsv.pitch = sv.pitch;
					fsv.roll = sv.roll;
					fsv.viewOffset = sv.viewOffset;
					fsv.coordSys = sv.coordSys;
				}+/
			}

			/+if (sv) viewport.doGUI(sv);
			if (fsv) fviewport.doGUI(fsv);+/
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
