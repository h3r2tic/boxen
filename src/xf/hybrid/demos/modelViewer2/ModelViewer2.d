module ModelViewer;

private {
	import tango.core.stacktrace.TraceExceptions;
	
	import xf.hybrid.Hybrid;
	import xf.hybrid.backend.GL;

	import xf.loader.scene.Hme;
	import xf.loader.scene.model.Node;
	import xf.loader.scene.model.Mesh;
	import xf.loader.scene.model.Scene;
	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.CoordSys;
	import xf.omg.core.Misc;
	import xf.omg.geom.Plane;
	import xf.omg.geom.Triangle;
	import xf.rt.Misc;
	import xf.dog.Dog;
	import xf.utils.Bind;
	
	import tango.core.Thread;
	import tango.util.log.Trace;
}




void main() {
	version (DontMountExtra) {} else gui.vfsMountDir(`../../`);
	scope cfg = loadHybridConfig(`./ModelViewer2.cfg`);
    scope renderer = new Renderer;
    
	Light[] lights;
	lights ~= new Light(vec3(0, 1, 1),	vec3(0.4, 0.5, 0.4), 0);
	lights ~= new Light(vec3(1, 1, 0),	vec3(0.4, 0.4, 0.7), 1);
	lights ~= new Light(vec3(-1, 1, -1),	vec3(0.8, 0.8, 0.4), 2);
	lights ~= new Light(vec3(0, -1, 0),	vec3(0.2, 0.5, 0.2), 3);
	
	Scene scene;
	
	alias SceneProxy.SceneObject	SceneObject;
	alias SceneProxy.ChildrenFruct	ChildrenFruct;
	SceneProxy* sceneProxy = new SceneProxy;

	sceneProxy.getRoot = {
		return cast(SceneObject)scene;
	};
	
	sceneProxy.iterChildren = (SceneObject so, CoordSys cs){
		return ChildrenFruct(so, cs, (ref ChildrenFruct fruct, int delegate(ref SceneObject, ref CoordSys) dg) {
			if (auto scene = cast(Scene)cast(Object)fruct.root) {
				foreach (ref node; scene.nodes) {
					SceneObject obj = cast(SceneObject)node;
					if (auto r = dg(obj, fruct.coordSys)) {
						return r;
					}
				}
			} else if (auto node = cast(Node)cast(Object)fruct.root) {
				foreach (ref child; node.children) {
					SceneObject obj = cast(SceneObject)child;
					auto transform = child.parentOffset in fruct.coordSys;
					if (auto r = dg(obj, transform)) {
						return r;
					}
				}
			}		
			return 0;
		});
	};
	
	sceneProxy.setTransform = (SceneObject so, CoordSys cs, CoordSys) {
		if (auto node = cast(Node)cast(Object)so) {
			node.setTransform(cs);
		}
	};
	
	sceneProxy.getTransform = (SceneObject so) {
		if (auto node = cast(Node)cast(Object)so) {
			return node.parentOffset;
		} else {
			return CoordSys.identity;
		}
	};
	
	sceneProxy.intersect = (Ray r, void delegate(SceneObject) dg) {
		intersectSceneNodes(scene, r, (Node n) {
			dg(cast(SceneObject)n);
		});
	};

	sceneProxy.draw = delegate(vec2i, GL gl, SceneView.DisplayMode dm) {
		gl.ClearColor(0.08, 0.08, 0.08, 0);
		gl.Clear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

		if (scene !is null) {
			if (SceneView.DisplayMode.Wireframe == dm) {
				gl.PolygonMode(GL_FRONT_AND_BACK, GL_LINE);
			} else {
				gl.PolygonMode(GL_FRONT_AND_BACK, GL_FILL);
			}

			foreach (l; lights) {
				l.use(gl);
			}
			
			gl.withState(GL_DEPTH_TEST).withState(GL_LIGHTING).withState(GL_CULL_FACE) in {
				renderSceneNodes(gl, scene);
			};
		}
	};
	
    SceneView[4]	views;
    int					focusedView = -1;
    
    void initView(SceneView view, int i) {
    	if (view.initialized) return;
    	view.layoutAttribs(`hexpand hfill vexpand vfill`);
    	
		view.selection = views[0].selection;
		view.scene = sceneProxy;
		
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
				displayMode = DisplayMode.Wireframe;
				viewType = ViewType.Ortho;
			} break;

			case 1: {
				rotateYaw(90);
				displayMode = DisplayMode.Wireframe;
				viewType = ViewType.Ortho;
			} break;

			case 2: {
				rotatePitch(-90);
				displayMode = DisplayMode.Wireframe;
				viewType = ViewType.Ortho;
			} break;

			case 3: {
				shiftView(vec3(0, .2, 1.2));
				rotatePitch(-45);
				displayMode = DisplayMode.Solid;
				viewType = ViewType.Perspective;
			} break;
		}

		view.eventHandler = (
				SceneView sv,
				SceneView.EventType et,
				SceneView.EventModifiers em,
				MouseButton buttons,
				SceneView.Selection sel,
				vec2 pos,
				vec2 delta
		) {
			sv.defaultEventHandler(sv, et, em, buttons, sel, pos, delta);
			
			if (et.Click == et && (buttons & MouseButton.Right) && !sel.isEmpty) {
				gui().popup!(VBox)(sel) = (SceneView.Selection sel) {
					return contextMenu(
						menuLeaf("lol", Trace.formatln("Doing lol with sel. isEmpty={}", sel.isEmpty)),
						menuGroup("stuff",
							menuLeaf("stuff1", Trace.formatln("stuff1")),
							menuLeaf("stuff2", Trace.formatln("stuff2")),
							menuLeaf("stuff3", Trace.formatln("stuff3"))
						),
						menuLeaf("heh"),
						menuLeaf("lul")
					).isOpen;
				};
			}
		};
	}


    bool programRunning = true;
    while (programRunning) {
        gui.begin(cfg).push(`main`);
            if (gui().getProperty!(bool)("frame.closeClicked")) {
                programRunning = false;
            }
            
            if (Button(`loadButton`).clicked) {
            	char[] path = Input(`pathInput`).text;
            	try {
					scope loader = new HmeLoader;
					loader.load(path);
					if (scene !is null) {
						scene.nodes ~= loader.scene.nodes;
					} else {
						scene = loader.scene;
					}
				} catch (Exception e) {
					Trace.formatln("Cannot load the scene: {}", e.toString);
				}
            }
            
            if (Button(`unloadButton`).clicked) {
				scene = null;
            }
            
			VBox(`sceneViewArea`).cfg(`layout={spacing=2;}`) [{
				if (-1 == focusedView) {
					HBox().layoutAttribs(`hexpand hfill vexpand vfill`).cfg(`layout={spacing=2;}`).open;
						initView(views[0] = SceneView(0), 0);
						initView(views[1] = SceneView(1), 1);
					gui.close;
					
					HBox().layoutAttribs(`hexpand hfill vexpand vfill`).cfg(`layout={spacing=2;}`).open;
						initView(views[2] = SceneView(2), 2);
						initView(views[3] = SceneView(3), 3);
					gui.close;
				} else {
					initView(views[focusedView] = SceneView(focusedView), focusedView);
				}
			}];
        gui.pop.end();
        gui.render(renderer);
        Thread.yield();
    }
}


class Light {
	this (vec3 from, vec3 col, int lightId) {
		this.lightId = lightId;
		this.col = vec4(col.x, col.y, col.z, 0);
		this.from = vec4(from.x, from.y, from.z, 0);
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


void renderSceneNodes(GL gl, Scene scene) {
	foreach (node, cs; iterSceneNodes(scene)) {
		if (auto m = cast(Mesh)node) {
			renderMesh(gl, m, cs);
		}
	}
}

void renderMesh(GL gl, Mesh mesh, CoordSys cs) {
	gl.PushMatrix();
	gl.MultMatrixf(cs.toMatrix.ptr);
	
	gl.immediate(GL_TRIANGLES, {
		gl.Color4f(1, 1, 1, 1);
		
		foreach (i; mesh.indices) {
			if (mesh.normals.length > 0) {
				gl.Normal3fv(mesh.normals[i].ptr);
			}
			
			gl.Vertex(mesh.positions[i]);
		}
	});
	
	gl.PopMatrix();
}


void intersectSceneNodes(Scene scene, Ray r, void delegate(Node) dg) {
	foreach (node, cs; iterSceneNodes(scene)) {
		if (auto m = cast(Mesh)node) {
			if (intersectMesh(r, m, cs)) {
				dg(cast(Node)m.parent);
				break;
			}
		}
	}
}


bool intersectMesh(Ray r, Mesh mesh, CoordSys cs) {
	auto invCs = cs.inverse;
	Ray tr = r * invCs;
	
	Trace.formatln("intersecting a mesh against {} -> {}", tr.origin, tr.direction);
	
	float dist = float.max;

	for (int i = 0; i+2 < mesh.indices.length; i += 3) {
		vec3[3] verts = void;
		verts[0] = mesh.positions[mesh.indices[i+0]];
		verts[1] = mesh.positions[mesh.indices[i+1]];
		verts[2] = mesh.positions[mesh.indices[i+2]];
		
		if (intersectTriangle(verts[], tr.origin, tr.direction, dist)) {
			return true;
		}
	}
	
	return false;
}
