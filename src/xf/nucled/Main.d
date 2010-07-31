module Main;

version (StackTracing) import tango.core.tools.TraceExceptions;

import
	xf.Common,
	xf.utils.GfxApp,
	xf.test.gfx.Common,

	xf.nucled.ParametersRollout,

	xf.omg.core.LinearAlgebra,
	xf.omg.core.CoordSys,
	
	tango.io.Stdout,
	tango.text.convert.Format;

import xf.hybrid.Hybrid;
import xf.hybrid.WidgetConfig : HybridConfig = Config;
import xf.hybrid.backend.Gfx : HybridRenderer = Renderer, TopLevelWidget = TopLevel;
	


void main() {
	(new TestApp).run;
}


class TestApp : GfxApp {
	HybridRenderer	guiRenderer;
	HybridConfig	guiConfig;


	ParametersRollout	paramsRollout;

	
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
			final graphEdTabView = TabView(`graphEd`);
			graphEdTabView.layoutAttribs = "hfill vfill hexpand vexpand";

			graphEdTabView.label[0] = "onoz";
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
}
