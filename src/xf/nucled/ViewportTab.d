module xf.nucled.ViewportTab;

private {
	import
		xf.Common,
		xf.nucled.Intersect,
		xf.nucled.Viewport,
		xf.nucleus.Nucleus,
		xf.hybrid.Hybrid,
		xf.vsd.VSD,
		xf.mem.Array,
		xf.utils.Bind;

	import
		xf.nucled.Log : log = nucledLog;
}



class ViewportTab {
	this (Renderer renderer, VSDRoot* vsd, Array!(TrayRacer)* trayRacers) {
		foreach (ref v; viewports) {
			v = new Viewport(renderer, vsd, trayRacers);
			//v = new Viewport(world);
		}
	}
	
	void refresh() {
		foreach (v; viewports) {
			v.refresh;
			v.enabled = true;
		}
	}

	void doGUI() {
		foreach (viewport; viewports) {
			if (viewport.drawingException !is null) {
				auto e = viewport.drawingException;
				cstring fullmsg;
				e.writeOut((char[] msg) { fullmsg ~= msg; });
				log.error(fullmsg);
				
				/+
				while (e) {
					printf("%.*s: %.*s (%.*s @ %d) {"\n, e.classinfo.name, e.toString, e.file, e.line);
					if (e.info) {
						foreach (char[] func, char[] file, int line, ptrdiff_t offset, size_t address; e.info) {
							printf("    at %.*s (%.*s:%d) +%d [%d]"\n, func, file, line, offset, address);
						}
					}
					printf("}"\n);
					e = e.next;
				}+/
				viewport.enabled = false;
			}
		}

		VBox().cfg(`layout={spacing=2;}`) [{
			bool f(int i) {
				return -1 == focusedView || i == focusedView;
			}
			
			if (f(0) || f(1)) {
				HBox().layoutAttribs(`hexpand hfill vexpand vfill`).cfg(`layout={spacing=2;}`).open;
					if (f(0)) viewports[0].doGUI(initView(views[0] = SceneView(0), 0));
					if (f(1)) viewports[1].doGUI(initView(views[1] = SceneView(1), 1));
				gui.close;
			}
			
			if (f(2) || f(3)) {
				HBox().layoutAttribs(`hexpand hfill vexpand vfill`).cfg(`layout={spacing=2;}`).open;
					if (f(2)) viewports[2].doGUI(initView(views[2] = SceneView(2), 2));
					if (f(3)) viewports[3].doGUI(initView(views[3] = SceneView(3), 3));
				gui.close;
			}
		}].layoutAttribs(`hfill vfill`);
	}

    SceneView initView(SceneView view, int i) {
    	if (view.initialized) return view;
    	view.layoutAttribs(`hexpand hfill vexpand vfill`);
    	
		view.selection = views[0].selection;
		
		view.addHandler(bind((int* focused, int i, KeyboardEvent e) {
			if (e.sinking && !e.handled && e.down && KeySym.Tab == e.keySym) {
				if (*focused != -1) {
					*focused = -1;
				} else {
					*focused = i;
				}
				return EventHandling.Stop;
			}
			return EventHandling.Continue;
		}, &focusedView, i, _0).ptr);

		with (view) switch (i) {
			case 0: {
				shiftView(vec3(0, 1, 2));
				displayMode = DisplayMode.Wireframe;
				viewType = ViewType.Perspective;
				rotationEnabled = false;
				//viewType = ViewType.Ortho;
			} break;

			case 1: {
				rotateYaw(90);
				shiftView(vec3(0, 1, 2));
				displayMode = DisplayMode.Wireframe;
				viewType = ViewType.Perspective;
				rotationEnabled = false;
				//viewType = ViewType.Ortho;
			} break;

			case 2: {
				rotatePitch(-90);
				shiftView(vec3(0, 0, 3));
				displayMode = DisplayMode.Wireframe;
				viewType = ViewType.Perspective;
				rotationEnabled = false;
				//viewType = ViewType.Ortho;
			} break;

			case 3: {
				shiftView(vec3(0, 1.2, 2));
				rotatePitch(-30);
				rotateYaw(-30);
				displayMode = DisplayMode.Solid;
				viewType = ViewType.Perspective;
			} break;

			default: assert(false);
		}
		
		return view;
	}

	
	Viewport[4]		viewports;
	SceneView[4]	views;
	int				focusedView = -1;
}


struct GlobalMode {
	enum Mode {
		Normal,
		SelectingMaterial,
		SelectingSurface
	}

	Mode mode = Mode.Normal;

	struct SelectingMaterial {
		RenderableId[] rids;
	}

	struct SelectingSurface {
		RenderableId[] rids;
	}

	union {
		SelectingMaterial	selectingMaterial;
		SelectingSurface	selectingSurface;
	}
}
