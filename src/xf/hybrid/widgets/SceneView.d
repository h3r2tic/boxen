module xf.hybrid.widgets.SceneView;

private {
	import xf.hybrid.Common;
	import xf.hybrid.CustomWidget;
	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.CoordSys;
	import xf.omg.util.ViewSettings;
	import xf.omg.rt.Common;
	import xf.input.Input : isWheelInput;
	import xf.input.KeySym : KeySym;
	import tango.util.container.HashSet;
	import tango.text.convert.Format;
	
	version (HybridSceneViewSpam) {
		import tango.util.log.Trace;
	}
}



alias xf.hybrid.Event.EventHandling HybridEventHandling;


// needs to be here due to forward reference bullshit in dmd <= 1.036
enum DisplayMode {
	Wireframe,
	Solid,
	Shaded
}


struct SceneProxy {
	typedef void* SceneObject;

	struct ChildrenFruct {
		SceneObject	root;
		CoordSys		coordSys;
		int delegate(ref ChildrenFruct, int delegate(ref SceneObject, ref CoordSys) dg)	iterChildren;
		size_t[2]		reserved;
		
		int opApply(int delegate(ref SceneObject, ref CoordSys) dg) {
			return iterChildren(*this, dg);
		}
	}
	
	SceneObject		delegate()									getRoot;
	ChildrenFruct	delegate(SceneObject, CoordSys)				iterChildren;
	CoordSys		delegate(SceneObject)						getTransform;		// local transform
	void			delegate(SceneObject, CoordSys, CoordSys)	setTransform;		// local transform, world transform
	void			delegate(Ray, void delegate(SceneObject))	intersect;
	void			delegate(vec2i, ViewSettings, DisplayMode)	draw;
	
	bool isValid() {
		return
			getRoot !is null &&
			iterChildren !is null &&
			getTransform !is null &&
			setTransform !is null &&
			intersect !is null &&
			draw !is null;
	}
}


class SceneView : Widget {
	alias xf.hybrid.widgets.SceneView.DisplayMode DisplayMode;
	
	enum ViewType {
		Ortho,
		Perspective
	}
	
	enum CameraMode {
		Distant,
		FirstPerson
	}
	
	alias HashSet!(SceneProxy.SceneObject)	Selection;
	
	//vec4				clearColor = {r: 0.08, g: 0.08, b: 0.08, a: 0};
	
	CameraMode	camMode;
	ViewType	viewType;
	CoordSys	coordSys = CoordSys.identity;		// read only
	float		fov = 90;
	float		scale = 1;
	vec2		windowSize = vec2.zero;
	SceneProxy*	scene;
	DisplayMode	displayMode;
	Selection	selection;
	float		nearPlane = 0.1f;
	float		farPlane = 1000.f;
	mat4		viewMatrix;
	float		yaw = 0, pitch = 0, roll = 0;
	vec3		viewOffset = vec3.zero;
	
	// vec3 offset, float yaw, float pitch, float roll, bool ortho, bool wireframe
	
	
	vec3 rightAxis() {
		return coordSys.rotation.xform(vec3.unitX);
	}

	vec3 upAxis() {
		return coordSys.rotation.xform(vec3.unitY);
	}
	
	vec3 forwardAxis() {
		return coordSys.rotation.xform(-vec3.unitZ);
	}
	
	
	void shiftView(vec3 v) {
		switch (camMode) {
			case CameraMode.Distant: {
				viewOffset += v;
			} break;
			default: assert (false, "TODO");
		}

		deriveCoordSys;
	}
	
	void rotateYaw(float a) {
		yaw += a;
		deriveCoordSys;
	}
	
	void rotatePitch(float a) {
		pitch += a;
		deriveCoordSys;
	}

	void rotateRoll(float a) {
		roll += a;
		deriveCoordSys;
	}

	void deriveCoordSys() {
		switch (camMode) {
			case CameraMode.Distant: {
				coordSys.rotation = quat.yRotation(yaw) * quat.xRotation(pitch) * quat.zRotation(roll);
				coordSys.origin = vec3fi.from(coordSys.rotation.xform(this.viewOffset));
			} break;
			default: assert (false, "TODO");
		}
	}
	
	
	enum EventModifiers {
		XAxis	= 0b1,
		YAxis	= 0b10,
		ZAxis	= 0b100,
		Shift	= 0b1000,
		Ctrl	= 0b10000,
		Alt		= 0b100000,
		
		RestrictAxis	= XAxis | YAxis | ZAxis
	}
	
	enum EventType {
		Click,
		DragStart,
		Drag,
		DragEnd
	}
	
	
	void delegate(SceneView, EventType, EventModifiers, MouseButton buttons, Selection, vec2, vec2) eventHandler;

	
	this() {
		addHandler(&this.mouseHandler);
		addHandler(&this.keyboardHandler);
		gui.addGlobalHandler(&this.globalKeyboardHandler);
		
		selection = new Selection;
	}
	

	private {
		struct iterSceneNodes {
			alias SceneProxy.SceneObject SceneObject;
			SceneProxy* scene;
			
			int iter(SceneObject node, CoordSys cs, int delegate(ref SceneObject, ref CoordSys) dg) {
				if (auto r = dg(node, cs)) {
					return r;
				}
				
				foreach (n, ccs; scene.iterChildren(node, cs)) {
					if (auto r = iter(n, ccs, dg)) {
						return r;
					}
				}
				
				return 0;
			}
			
			int opApply(int delegate(ref SceneObject, ref CoordSys) dg) {
				if (scene) foreach (n, cs; scene.iterChildren(scene.getRoot(), CoordSys.identity)) {
					if (auto r = iter(n, cs, dg)) {
						return r;
					}
				}
				return 0;
			}
		}
		
		
		struct InputState {
			bool xAxis, yAxis, zAxis;
			bool shift, ctrl, alt;
			MouseButton buttons = cast(MouseButton)0;
			vec2 cursorPos = vec2.zero;
			vec2 dragFrom;
			bool dragging;
			
			char[] toString() {
				char[] res;
				if (xAxis) res ~= "x";
				if (yAxis) res ~= "y";
				if (zAxis) res ~= "z";
				if (shift) res ~= " shift";
				if (ctrl) res ~= " ctrl";
				if (alt) res ~= " alt";
				res ~= Format(" bttn:{}", cast(int)buttons);
				res ~= Format(" cursor:{}", cursorPos);
				if (dragging) res ~= Format("dragging:{}", dragFrom);
				return res;
			}
			
			EventModifiers toModifiers() {
				EventModifiers res = cast(EventModifiers)0;
				if (xAxis) res |= EventModifiers.XAxis;
				if (yAxis) res |= EventModifiers.YAxis;
				if (zAxis) res |= EventModifiers.ZAxis;
				if (shift) res |= EventModifiers.Shift;
				if (ctrl) res |= EventModifiers.Ctrl;
				if (alt) res |= EventModifiers.Alt;
				return res;
			}
		}
		InputState istate;
	}
	
	
	bool globalKeyboardHandler(KeyboardEvent e) {
		switch (e.keySym) {
			case KeySym.x: istate.xAxis = e.down; break;
			case KeySym.z: istate.zAxis = e.down; break;
			case KeySym.s: istate.yAxis = e.down; break;
			
			case KeySym.Shift_L:
			case KeySym.Shift_R:
				istate.shift = e.down;
				break;
				
			case KeySym.Control_L:
			case KeySym.Control_R:
				istate.ctrl = e.down;
				break;
				
			case KeySym.Alt_L:
			case KeySym.Alt_R:
				istate.alt = e.down;
				break;
								
			default: break;
		}
		
		//Trace.formatln("istate: {}", istate);
		return false;		// so Hybrid will not remove this handler
	}


	HybridEventHandling keyboardHandler(KeyboardEvent e) {
		return HybridEventHandling.Continue;
	}
	
	
	bool shouldStartDrag(vec2 pos) {
		return (pos - istate.dragFrom).length >= 3;
	}
	
	
	void defaultEventHandler(SceneView sv, EventType et, EventModifiers em, MouseButton buttons, Selection sel, vec2 pos, vec2 delta) {
		version (HybridSceneViewSpam) {
			if (sel.isEmpty) {
				Trace.formatln("sel is empty");
			} else {
				Trace.formatln("sel is not empty");
			}
		}
		
		float aspect = sv.windowSize.x / sv.windowSize.y;
		vec2 moveScale = vec2(aspect * sv.scale * 2 / sv.windowSize.x, sv.scale * 2 / sv.windowSize.y);

		switch (et) {
			case et.Drag: {
				if ((buttons & MouseButton.Left) && !sel.isEmpty) {
					vec3 shift = delta.x * sv.rightAxis * moveScale.x - delta.y * sv.upAxis * moveScale.y;
					float shiftDistance = shift.length;
					if (em & em.RestrictAxis) {
						if (0 == (em & em.XAxis)) shift.x = 0;
						if (0 == (em & em.YAxis)) shift.y = 0;
						if (0 == (em & em.ZAxis)) shift.z = 0;
					}
					
					{
						float tmpDist = shift.length;
						if (tmpDist > float.epsilon) {
							shift *= shiftDistance / tmpDist;
						}
					}
					
					//Trace.formatln("shift: {}", shift);
					
					foreach (node, cs; iterSceneNodes(scene)) {
						version (HybridSceneViewSpam) Trace.formatln("iterSceneNodes");
						
						if (sel.contains(node)) {
							auto rot = cs.rotation.inverse;
							vec3 localShift = rot.xform(shift);
							auto nodeCs = scene.getTransform(node);
							nodeCs.origin += vec3fi.from(localShift);
							auto nodeWorldCs = cs;
							nodeWorldCs.origin += vec3fi.from(shift);
							scene.setTransform(node, nodeCs, nodeWorldCs);
						}
					}
				}

				if (buttons & MouseButton.Right) {
					if (em & em.Shift) {
						vec3 shift = -delta.x * vec3.unitX * moveScale.x + delta.y * vec3.unitZ * moveScale.y;
						sv.shiftView(shift);
					}
					
					if (em & em.Ctrl) {
						sv.rotateYaw(delta.x * moveScale.x * -90);
						sv.rotatePitch(delta.y * moveScale.y * -90);
					}

					if (0 == (em & (em.Ctrl | em.Shift))) {
						vec3 shift = -delta.x * vec3.unitX * moveScale.x + delta.y * vec3.unitY * moveScale.y;
						sv.shiftView(shift);
					}
				}
			} break;
			
			case et.DragStart:
			case et.Click: {
				{
					scope newSel = new SceneView.Selection;
					
					auto ray = sv.windowPosToRay(pos);
					scene.intersect(ray, (SceneProxy.SceneObject obj) {
						newSel.add(obj);
						version (HybridSceneViewSpam) Trace.formatln("node picked!");
					});
					
					bool unionEmpty = true;
					foreach (obj; newSel) {
						if (sel.contains(obj)) {
							unionEmpty = false;
							break;
						}
					}
					
					if (0 == (em & em.Ctrl) && (unionEmpty || (et.Click == et && (buttons & MouseButton.Left)))) {
						version (HybridSceneViewSpam) Trace.formatln("clearing selection");
						sel.clear();
					}
					
					foreach (obj; newSel) {
						sel.add(obj);
					}
				}
			} break;
				
			default: {
			} break;
		}
	}
	
	
	void handleEvent(EventType type, EventModifiers mod, MouseButton butt, Selection sel, vec2 pos, vec2 rel) {
		if (eventHandler) {
			eventHandler(this, type, mod, butt, sel, pos, rel);
		} else {
			defaultEventHandler(this, type, mod, butt, sel, pos, rel);
		}
	}
	
	
	bool globalMouseButtonHandler(MouseButtonEvent bttn) {
		if (!bttn.down && !isWheelInput(bttn.button)) {
			auto buttonsBefore = istate.buttons;
			istate.buttons &= ~bttn.button;
			//Trace.formatln("prev={}, evt={}, cur={}", buttonsBefore, bttn.button, istate.buttons);
			
			if (0 == istate.buttons) {
				auto buttonsClicked = buttonsBefore & ~istate.buttons;
				if (buttonsClicked != 0) {
					if (!istate.dragging) {
						version (HybridSceneViewSpam) Trace.formatln("click");
						handleEvent(EventType.Click, istate.toModifiers, buttonsClicked, this.selection, istate.cursorPos, vec2.zero);
					} else {
						version (HybridSceneViewSpam) Trace.formatln("drag end");
						istate.dragging = false;
						istate.dragFrom = istate.dragFrom.init;
						handleEvent(EventType.DragEnd, istate.toModifiers, buttonsBefore, this.selection, istate.cursorPos, vec2.zero);
					}
				}
			}
		}
		
		return istate.buttons == 0;
	}
	
	
	HybridEventHandling mouseHandler(MouseEvent e) {
		if (!e.handled && e.sinking) {
			if (auto move = cast(MouseMoveEvent)e) {
				vec2 delta = move.pos - istate.cursorPos;
				istate.cursorPos = move.pos;
				
				if (!istate.dragging && istate.buttons != 0) {
					if (shouldStartDrag(istate.cursorPos)) {
						version (HybridSceneViewSpam) Trace.formatln("drag start");
						istate.dragging = true;
						handleEvent(EventType.DragStart, istate.toModifiers, istate.buttons, this.selection, istate.dragFrom, vec2.zero);
						handleEvent(EventType.Drag, istate.toModifiers, istate.buttons, this.selection, istate.cursorPos, delta);
					}
				}
				
				if (istate.dragging) {
					//Trace.formatln("drag");
					handleEvent(EventType.Drag, istate.toModifiers, istate.buttons, this.selection, istate.cursorPos, delta);
				}
			} else if (auto bttn = cast(MouseButtonEvent)e) {
				if (!isWheelInput(bttn.button)) {
					if (0 == istate.buttons) {
						if (bttn.down) {
							istate.buttons |= bttn.button;
							istate.dragging = false;
							istate.dragFrom = bttn.pos;
							gui.addGlobalHandler(&this.globalMouseButtonHandler);
						}
					} else {
						if (bttn.down) {
							istate.buttons |= bttn.button;
						}
					}
				}
			}
			
			return HybridEventHandling.Stop;
		}
		return HybridEventHandling.Continue;
	}


	Ray windowPosToRay(vec2 wpos) {
		version (HybridSceneViewSpam) Trace.formatln("Converting window pos {} to a ray", wpos);
		wpos.x /= windowSize.x;
		wpos.y /= windowSize.y;
		wpos *= 2.f;
		wpos -= vec2.one;
		wpos.y *= -1;
		version (HybridSceneViewSpam) Trace.formatln("wpos: {}", wpos);
		
		switch (this.viewType) {
			case ViewType.Ortho: {
				float aspect = cast(float)windowSize.x / windowSize.y;
				Ray res = void;
				res.direction = coordSys.rotation.xform(-vec3.unitZ);
				res.origin = vec3.from(coordSys.origin) + coordSys.rotation.xform(vec3(wpos.x * aspect, wpos.y, farPlane));
				
				version (HybridSceneViewSpam) Trace.formatln("Result: {} -> {}", res.origin, res.direction);
				return res;
			}
				
			case ViewType.Perspective: {
				auto mat = this.viewMatrix;
				mat.invert;
				
				vec4 near = mat * vec4(wpos.x, wpos.y, -this.nearPlane, 1);
				near *= near.w;
				version (HybridSceneViewSpam) Trace.formatln("near: {}", near);
				
				vec4 far = mat * vec4(wpos.x, wpos.y, -this.farPlane, 1);
				far *= far.w;
				version (HybridSceneViewSpam) Trace.formatln("far: {}", far);
				
				vec3 dir = vec3.from(far - near).normalized;
				dir = coordSys.rotation.xform(dir);
				
				Ray res = void;
				res.direction = dir;
				res.origin = vec3.from(coordSys.origin);
				
				version (HybridSceneViewSpam) Trace.formatln("Result: {} -> {}", res.origin, res.direction);
				return res;
			}

			default: assert (false);
		}
	}


	override EventHandling handleRender(RenderEvent e) {
		if (!widgetVisible) {
			return EventHandling.Stop;
		}
		
		if (e.sinking && scene && scene.isValid) {
			if (auto r = e.renderer) {
				r.pushClipRect();
				vec2 offBefore = r.getOffset();
				scope (exit) {
					r.setOffset(offBefore);
					r.popClipRect();
				}

				r.clip(Rect(this.globalOffset, this.globalOffset + this.size));
				r.setOffset(this.globalOffset);
				draw(vec2i.from(this.size));
				//r.direct(&this.handleRender_, Rect(this.globalOffset, this.globalOffset + this.size));
			}
		}

		return EventHandling.Continue;
	}

	
	void draw(vec2i size) {
		ViewSettings vs;
		vs.eyeCS = this.coordSys;
		vs.verticalFOV = this.fov;		// in Degrees; _not_ half of the FOV
		vs.aspectRatio = cast(float)size.x / size.y;
		vs.nearPlaneDistance = this.nearPlane;
		vs.farPlaneDistance = this.farPlane;

		scene.draw(size, vs, this.displayMode);

		/+this.windowSize = vec2.from(size);
		
		gl.MatrixMode(GL_PROJECTION);
		gl.LoadIdentity();
		float aspect = cast(float)size.x / size.y;
		
		switch (this.viewType) {
			case ViewType.Ortho:
				this.viewMatrix = mat4.ortho(scale*-aspect, scale*aspect, scale*-1, scale, -farPlane, farPlane);
				break;
				
			case ViewType.Perspective:
				this.viewMatrix = mat4.perspective(fov, aspect, this.nearPlane, this.farPlane);
				break;
		}
		
		gl.LoadMatrixf(this.viewMatrix.ptr);
		gl.MatrixMode(GL_MODELVIEW);
		gl.LoadIdentity();
		
		/+gl.ClearColor(clearColor.r, clearColor.g, clearColor.b, clearColor.a);
		gl.Clear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);+/

		CoordSys viewCS = coordSys.inverse;
		gl.LoadMatrixf(viewCS.toMatrix.ptr);
		
		if (scene && scene.isValid) {
			scene.draw(size, gl, this.displayMode);
		}+/
	}
	
	
	mixin MWidget;
}
