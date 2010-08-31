module xf.nucled.Viewport;

private {
	import xf.Common;
	import xf.hybrid.Hybrid;
	import xf.nucled.Intersect;
	import xf.nucleus.Nucleus;
	import xf.nucleus.Scene;
	/+import xf.dog.Dog;
	import xf.nucleus.model.INucleusWorld;
	import xf.nucleus.model.INucleus;
	import xf.nucleus.model.IRenderable;+/
	//import xf.nucleus.model.KernelProvider;
	/+import xf.nucleus.SceneRenderer;
	import xf.nucleus.Context;
	import xf.nucleus.rg.Node : RgGroup;
	import xf.nucleus.cpu.Reflection;+/
	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.CoordSys;
	import xf.omg.core.Misc;
	import xf.omg.util.ViewSettings;
	import xf.omg.rt.Common;
	import xf.omg.geom.Plane;
	import xf.omg.geom.Triangle;
	import xf.vsd.VSD;
	import xf.mem.Array;
	//import xf.rt.Misc;
	
	import tango.math.random.Kiss;
	import tango.util.log.Trace;		// TMP
}



/+class VeryFancyDataInspector : IDataInspector {
	void inspect(char[] funcName, char[] paramName, Param.Direction dir, void* ptr, TypeInfo ti) {
		Trace.formatln("inspect({}, {}, {:x}, {})", funcName, paramName, ptr, ti);
	}
}+/



/+void renderScene(RgGroup scene, IRenderable viewRenderable, INucleus nucleus, vec2i size, GL gl) {
	scope context = new Context;
	
	mat4 projectionMat = void;
	/+gl.ClearColor(0, 0, 0, 0);
	gl.Clear(GL_COLOR_BUFFER_BIT);+/

	gl.MatrixMode(GL_PROJECTION);
	gl.LoadIdentity();
	gl.gluPerspective(90.f, cast(float)size.x / size.y, 0.1f, 100.f);
	gl.MatrixMode(GL_MODELVIEW);
	//gl.LoadIdentity();

	mat4 modelViewMat = void;
	gl.GetFloatv(GL_PROJECTION_MATRIX, projectionMat.ptr);
	gl.GetFloatv(GL_MODELVIEW_MATRIX, modelViewMat.ptr);
	
	auto viewCS = CoordSys(vec3fi.from(modelViewMat.getTranslation()), quat(modelViewMat.getRotation()).normalized).inverse;
	
	vec3	viewCoords = vec3.from(viewCS.origin);//vec3(0, 2, 2);
	quat	rot = viewCS.rotation;//quat.xRotation(-35);
	
	context.gl = gl;
	context.scene = scene;
	//context.viewCoords = CoordSys(vec3fi.from(viewCoords), rot);
	context.viewProjection = projectionMat;
	context.farPlaneDist = 100.f;
	context.nucleus = nucleus;
	
	//scope inspector = new VeryFancyDataInspector;
	
	if (viewRenderable.prepare()) {
		/+Trace.format("viewport cpu quarks:");
		foreach (quarkName, cpuQuark; &viewRenderable.linkedKernel.iterCPUQuarks) {
			Trace.format(" {}(label={})", cpuQuark.classinfo.name, quarkName);
			cpuQuark.dataInspector = inspector;
		}
		Trace.formatln("");+/
		
		viewRenderable.linkedKernel.setRequiredParamValue("pos", viewCoords);
		viewRenderable.linkedKernel.setRequiredParamValue("rot", rot);
		viewRenderable.prepareRender(context);
		viewRenderable.render(context);
	}
}+/



class Viewport {
	alias SceneProxy.SceneObject	SceneObject;
	alias SceneProxy.ChildrenFruct	ChildrenFruct;

	public bool delegate(
		int delegate(int delegate(ref RenderableId))
	) contextMenuHandler;


	this(Renderer r, VSDRoot* vsd, Array!(TrayRacer)* trayRacers) {
		assert (vsd !is null);
		_vsd = vsd;
		_renderer = r;
		_trayRacers = trayRacers;
	}
	
	
	void refresh() {
		//_renderable.markKernelDirty;
	}
	
	
	void draw(vec2i size, ViewSettings vs, SceneView.DisplayMode dm) {
		//try {
			if (enabled) {
				final rlist = _renderer.createRenderList();
				scope (exit) _renderer.disposeRenderList(rlist);

				// The various arrays for VSD must be updated as they may have been
				// resized externally and VSD now holds the old reference.
				// The VSD does not have a copy of the various data associated with
				// Renderables as to reduce allocations and unnecessary copies of dta.
				_vsd.transforms = renderables.transform[0..renderables.length];
				_vsd.localHalfSizes = renderables.localHalfSize[0..renderables.length];
				
				// update vsd.enabledFlags
				// update vsd.invalidationFlags
				//vsd.enableObject(rid);
				//vsd.invalidateObject(rid);
				
				_vsd.update();

				buildRenderList(_vsd, vs, rlist);

				with (*rendererBackend.state) {
					depth.enabled = true;
					blend.enabled = false;
					sRGB = true;
					with (cullFace) {
						enabled = true;
						front = false;
						back = true;
					}
				}

				rendererBackend.framebuffer.settings.clearColorValue[0] = vec4.one * 0.01;
				rendererBackend.framebuffer.settings.clearColorEnabled[0] = true;
				rendererBackend.clearBuffers();
				
				_renderer.render(vs, _vsd, rlist);
			}
			
			/+drawingException = null;
		} catch (Exception e) {
			drawingException = e;
		}+/
	}
	
	
	private {
		SceneObject getRoot() {
			return cast(SceneObject)_vsd;
		}
		
		int iterChildrenWorker(ref ChildrenFruct fruct, int delegate(ref SceneObject, ref CoordSys) dg) {
			if (fruct.root is cast(SceneObject)_vsd) {
				foreach (i, ref cs; _vsd.transforms) {
					if (_vsd.enabledFlags.isSet(i)) {
						auto obj = cast(SceneObject)&cs;
						if (int r = dg(obj, cs in fruct.coordSys)) {
							return r;
						}
					}
				}
			}
			return 0;
		}
			
		ChildrenFruct iterChildren(SceneObject so, CoordSys cs) {
			return ChildrenFruct(so, cs, &this.iterChildrenWorker);
		}


		void setTransform(SceneObject so, CoordSys cs, CoordSys worldCs) {
			if (so !is cast(SceneObject)_vsd) {
				uword idx = cast(CoordSys*)so - _vsd.transforms.ptr;
				assert (idx < _vsd.transforms.length);
				if (_vsd.enabledFlags.isSet(idx)) {
					_vsd.transforms[idx] = cs;
				}
			}
		}
		
		
		CoordSys getTransform(SceneObject so) {
			if (so !is cast(SceneObject)_vsd) {
				uword idx = cast(CoordSys*)so - _vsd.transforms.ptr;
				assert (idx < _vsd.transforms.length);
				return _vsd.transforms[idx];
			} else {
				return CoordSys.identity;
			}
		}
		
		
		void intersect(Ray r, void delegate(SceneObject) dg) {
			SceneObject closestNode;

			/+Trace.formatln(
				"Intersecting the scene with {}->{}",
				r.origin.toString,
				r.direction.toString
			);+/
			
			Hit hit;
			hit.distance = float.max;

			foreach (i, o; *_trayRacers) {
				if (o) {
					Ray tr = r * renderables.transform[i].inverse;
					if (o.intersect(tr, &hit)) {
						closestNode = cast(SceneObject)&renderables.transform[i];
					}
				}
			}

			if (closestNode !is null) {
				final cs = cast(CoordSys*)closestNode;
				
/+				Trace.formatln(
					"Picked {} @ {} (cs: {})",
					cs - renderables.transform,
					hit.distance,
					cs.toString
				);+/
				dg(closestNode);
			}
		}


		void popupHandler(
				SceneView sv,
				SceneView.EventType et,
				SceneView.EventModifiers em,
				MouseButton buttons,
				SceneView.Selection sel,
				vec2 pos,
				vec2 delta
		) {
			sv.defaultEventHandler(sv, et, em, buttons, sel, pos, delta);
			
			if (et.Click == et && (buttons & MouseButton.Right) && !sel.isEmpty && contextMenuHandler) {
				gui().popup!(VBox)(sel, this) = (SceneView.Selection sel, Viewport _this) {
					int selIter(int delegate(ref RenderableId) sink) {
						foreach (so; sel) {
							if (so !is cast(SceneObject)_this._vsd) {
								uword idx = cast(CoordSys*)so - _this._vsd.transforms.ptr;
								if (int r = sink(cast(RenderableId)idx)) {
									return r;
								}
							}
						}

						return 0;
					}

					return _this.contextMenuHandler(&selIter);
				};
			}
		}
	}
	

    void initView(SceneView view) {
		SceneProxy* sceneProxy = new SceneProxy;
		sceneProxy.getRoot = &this.getRoot;		
		sceneProxy.iterChildren = &this.iterChildren;		
		sceneProxy.setTransform = &this.setTransform;		
		sceneProxy.getTransform = &this.getTransform;		
		sceneProxy.intersect = &this.intersect;
		sceneProxy.draw = &this.draw;

		view.scene = sceneProxy;
		view.eventHandler = &this.popupHandler;
	}

	
	void doGUI(SceneView view) {
		initView(view);
	}
	
	
	public {
		bool		enabled = true;
		Exception	drawingException;
	}
	
	private {
		VSDRoot*	_vsd;
		Renderer	_renderer;
		Array!(TrayRacer)*	_trayRacers;
	}
}



/+void intersectSceneNodes(XNode root, Ray r, void delegate(XWorldEntity) dg) {
	XWorldEntity closestNode;
	
	Hit hit;
	hit.distance = float.max;

	foreach (node, cs; &root.iterWorldEntityTree) {
		Ray tr = r * cs.inverse;
		if (node.intersect(tr, &hit)) {
			closestNode = node;
		}
	}

	if (closestNode !is null) {
		Trace.formatln("Picked a {}", closestNode.classinfo.name);
		dg(closestNode);
	}
}
+/
