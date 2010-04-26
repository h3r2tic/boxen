module xf.hybrid.Test1;

private {
	import xf.hybrid.Hybrid;
	import xf.hybrid.backend.GL;
	import xf.dog.Dog;
	import xf.rt.BunnyData;
	
	import tango.io.Stdout;
	import tango.time.StopWatch;
	import tango.core.Thread;
	import tango.util.Convert;
	import tango.text.convert.Format;
	import tango.io.FilePath;
	
	import tango.io.vfs.ZipFolder;
}



void main() {
	version (distrib) {
		if (FilePath("Test1.zip").exists) {
			gui.vfs.mount(new ZipFolder("Test1.zip"));
		}
	}
	
	scope cfg = loadHybridConfig(`Test1.cfg`);
	
	scope renderer = new Renderer;
	WindowFrame frame;

	gui.begin(cfg).retained;
		Button(`foo.button1`).text = "button1";
		gui.open("leftExtra");
			Label().text("left").fontSize(10);
		gui.close().open("rightExtra");
			Label().text("right").fontSize(10);
		gui.close();

		auto glStuff1 = new GLStuff(.5f);
		GLViewport(`foo.glview1`).renderingHandler = &glStuff1.draw;
		GLViewport(`foo.tabView.glview2`).renderingHandler = &(new GLStuff(-1.f)).draw;
	gui.immediate;
		with (Combo(`.comboBox`)) {
			for (int i = 0; i < 20; ++i) {
				addItem("Combo item " ~ to!(char[])(i));
			}
		}	
	gui.end();
	

	bool programRunning = true;
	while (programRunning) {
		gui.begin(cfg);
			if (gui().getProperty!(bool)("foo.frame.closeClicked")) {
				programRunning = false;
			}
			
			Label(`.comboBoxSelection`).text = Format(
				"{} ({})",
				Combo(`.comboBox`).selected,
				Combo(`.comboBox`).selectedIdx
			);

			{
				HBox(`foo.glview1Control`) [{
					auto slider = HSlider().minValue(-3.f).maxValue(3.f).snapIncrement(0.25);
					slider.layoutAttribs("hexpand hfill");
					auto label = Label().text(to!(char[])(glStuff1.rotSpeed = slider.position));
					label.halign(2).fontSize(10).userSize = vec2(35.f, 0.f);
					gui().setProperty!(char[])("foo.glview1Rot.label.text", to!(char[])(glStuff1.angle = gui().getProperty!(float)("foo.glview1Rot.angle.angle")) ~ "\u00b0");
				}];
			}
			
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
						menuLeaf("Exit", programRunning = false)
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

			gui.push(`foo`);
				if (Button(`button1`).clicked) {
					Stdout.formatln("Button1 clicked!");
					static int fntSize = 13;
					fntSize ^= 2;
					(cast(Label)Button(`button1`).getSub("label")).fontSize(fntSize);
				}
				
				Button(`button1`);
				Button(`button2`).text = "button2";
				
				static bool btn2HasExtra = false;
				
				if (Button(`.foo.button2`).clicked) {
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
		gui.render(renderer);
		//Thread.yield();
	}
}



// ------------------------------------------------------------------------------------------------------------------------------------



class GLStuff {
	static class Light {
		this (vec3 from, vec3 col, int lightId) {
			this.lightId = lightId;
			this.col = vec4(col.x, col.y, col.z, 0);
			this.from = vec4(from.x, from.y, from.z, 1);
		}

		void use(GL gl) {
			int lightId = GL_LIGHT0 + this.lightId;
			gl.Lightfv(lightId, GL_DIFFUSE, &col.x);
			gl.Lightfv(lightId, GL_POSITION, &from.x);
			gl.Enable(lightId);
		}

		int	lightId;
		vec4	col, from;
	}

	
	float rot = 0.f;
	float rotSpeed;
	float angle = 0.f;
	Light[] lights;
	StopWatch watch;
	
	this (float rotSpeed) {
		this.rotSpeed = rotSpeed;
		lights ~= new Light(vec3(0, 1, 1),	vec3(0.4, 0.5, 0.4), 0);
		lights ~= new Light(vec3(1, 1, 0),	vec3(0.4, 0.4, 0.7), 1);
		lights ~= new Light(vec3(-1, 1, -1),	vec3(0.8, 0.8, 0.4), 2);
		lights ~= new Light(vec3(0, -1, 0),	vec3(0.2, 0.5, 0.2), 3);
		watch.start();
	}
	
	void draw(vec2i size, GL gl) {
		gl.MatrixMode(GL_PROJECTION);
		gl.LoadIdentity();
		gl.gluPerspective(60.f, cast(float)size.x / size.y, 0.1f, 100.f);
		gl.MatrixMode(GL_MODELVIEW);		
		gl.LoadIdentity();
		
		foreach (l; lights) {
			l.use(gl);
		}

		gl.Clear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		
		gl.withState(GL_DEPTH_TEST).withState(GL_LIGHTING) in {
			rot += rotSpeed * watch.stop() * 100.f;
			watch.start();
			gl.Translatef(0, 0, -2);
			gl.Rotatef(angle, 1, 0, 0);
			gl.Rotatef(rot, 0, 1, 0);

			gl.immediate(GL_TRIANGLES, {
				gl.Color4f(1f, 1f, 1f, 1f);
				
				for (int i = 0; i < bunnyTriangles.length; i += 3) {
					vec3 v0 = *cast(vec3*)&bunnyVertices[bunnyTriangles[i+0]*3];
					vec3 v1 = *cast(vec3*)&bunnyVertices[bunnyTriangles[i+1]*3];
					vec3 v2 = *cast(vec3*)&bunnyVertices[bunnyTriangles[i+2]*3];
					vec3 n = cross(v1 - v0, v2 - v0).normalized;
					
					gl.Normal3fv(n.ptr);
					gl.Vertex3fv(v0.ptr);
					gl.Vertex3fv(v1.ptr);
					gl.Vertex3fv(v2.ptr);
				}
			});
		};
	}
}
