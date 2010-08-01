module Main;

version (StackTracing) import tango.core.tools.TraceExceptions;

import
	xf.Common,
	xf.utils.GfxApp,
	xf.test.gfx.Common,

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

	
	override void configureWindow(Window wnd) {
		super.configureWindow(wnd);
		wnd.width = 870;
		wnd.height = 570;
		/+wnd.width = 1050;
		wnd.height = 1680;
		wnd.fullscreen = true;+/
		wnd.title = "Hybrid hello world";
	}
	
	
	override void initialize() {
		guiRenderer = new HybridRenderer(renderer);

		gui.overrideInputChannel(inputHub.mainChannel);
		
		gui.vfsMountDir(`../../../hybrid/`);
		guiConfig = loadHybridConfig(`./GUI.cfg`);
	}


	override void render() {
		renderer.resetState();
		renderer.clearBuffers();

		gui.begin(guiConfig);
		
		TopLevelWidget("main").userSize = vec2(window.width, window.height);
		
		Label(`.comboBoxSelection`).text = Format(
			"{} ({})",
			Combo(`.comboBox`).selected,
			Combo(`.comboBox`).selectedIdx
		);

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

		gui.push(`main`);
			if (Button(`button1`).clicked) {
				Stdout.formatln("Button1 clicked!");
				static int fntSize = 13;
				fntSize ^= 2;
				(cast(Label)Button(`button1`).getSub("label")).fontSize(fntSize);
			}
			
			Button(`button1`);
			Button(`button2`).text = "button2";
			
			static bool btn2HasExtra = false;
			
			if (Button(`.main.button2`).clicked) {
				btn2HasExtra = !btn2HasExtra;
			}
			
			if (btn2HasExtra) {
				gui.open(`rightExtra`);
					bool orly = Check().text(`orly`).checked;
				gui.close;
				if (orly) {
					gui.open(`leftExtra`);
						Label().text = "yarly";
					gui.close;
				}
			}
			
			{
				auto tlist = TextList(`tlist`);
				if (Button(`tlistbtn`).text(`add an item`).clicked) {
					tlist.addItem("item :P");
				}
			}
			
			if (Check(`showExtras`).text("show sub-group").checked) {
				Group(`extras`);
				gui.open;
					HBox();
					gui.open;
						Button().text = "foo";		// child of the HBox above
						Button().text = "bar";
						Button().text = "baz";
						Button().text = "blah";
						Button().text = "zomg";
						Button().text = "ham";
					gui.close;
					
					XorSelector grp;
					DefaultOption = XCheck().text("option 1").group(grp);
					XCheck().text("option 2").group(grp);
					XCheck().text("option 3").group(grp);
					
					{
						static int spamCount = 0;
						static bool spamming = false;
						if (spamming) {
							static int cnt = 0;
							if (++cnt % 10 == 0) {
								++spamCount;
								if (6 == spamCount) {
									spamCount = 0;
									spamming = false;
								}
							}
						}
						char[] spamText = "spam";
						for (int i = 0; i < spamCount; ++i) {
							spamText ~= [" spam", " ham", " eggs"][grp.index];
						}
						
						if (Button().text(spamText).clicked) {
							spamming = true;
						}
					}
					
					auto moar = Check();
				gui.close;

				if (moar.text("can has moar?").checked) {
					Group(`moar`);
					gui.open;
						if (Button().text("oh hai!").clicked) {
							moar.checked = !moar.checked;
						}
						
						if (Check().text("even moar?").checked) {
							static int numExtraButtons = 0;
							
							if (numExtraButtons < 10) {
								if (Button().text(`yay \o/`).clicked) {
									++numExtraButtons;
								}
							} else {
								if (Button().text(`nay :F`).clicked) {
									numExtraButtons = 0;
								}
							}
							
							VBox();
							gui.open;
								for (int i = 0; i < numExtraButtons; ++i) {
									if (Button(i).text("Button" ~ to!(char[])(i)).clicked) {
										--numExtraButtons;
									}
								}
							gui.close;
						}
					gui.close;
				}
			}
			
			
			{
				auto tabView = TabView(`tabView`);
				gui.open(`button0.leftExtra`);
					Label().text(`:)`);
				gui.close();
			}
			
			{
				auto tabView = TabView();
				tabView.label[0] = "tab0";
				tabView.label[1] = "tab1";
				tabView.label[2] = "tab2";
				
				gui.open;
				switch (tabView.activeTab) {
					case 0: {
						for (int i = 0; i < 5; ++i) {
							Button(i).text("tab 0 contents");
						}
					} break;

					case 1: {
						for (int i = 0; i < 5; ++i) {
							Label(i).text("tab 1 contents");
						}
					} break;

					case 2: {
						for (int i = 0; i < 5; ++i) {
							Check(i).text("tab 2 contents");
						}
					} break;

					default: assert (false);
				}
				gui.close;
			}
			
			auto prog1 = Progressbar(`prog1`);
			auto prog2 = Progressbar(`prog2`);
			{
				static float prog = 0.f;
				prog += VSlider(`vslider`).position * 0.01f;
				prog1.position = prog;
				prog2.position = prog;
				if (prog > 1.f) prog = 0.f;
			}
			
		gui.pop();
		
		gui.end();
		gui.render(guiRenderer);
	}
}
