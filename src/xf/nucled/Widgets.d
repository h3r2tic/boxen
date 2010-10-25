module xf.nucled.Widgets;

private {
	import xf.hybrid.Hybrid;
	import xf.hybrid.Common;
	import xf.hybrid.CustomWidget;
	import xf.omg.core.LinearAlgebra;
	import tango.time.StopWatch;

	//import tango.io.Stdout;
}



private {
	StopWatch	g_stopWatch;
	static this() {
		g_stopWatch.start;
	}
}



class GraphNodeDeleteButton : GenericButton {
	mixin MWidget;
}


class DraggableView : ClipView {
	override bool childrenGoAbove() {
		return true;
	}


	protected EventHandling handleMouseButton(MouseButtonEvent e) {
		if (MouseButton.Right == e.button && e.down && e.bubbling && !e.handled) {
			this._dragging = true;
			
			//Stdout.formatln("DraggableView: drag start");
			gui.addGlobalHandler(&this.globalHandleMouseButton);
			
			return EventHandling.Stop;
		}
		
		return EventHandling.Continue;
	}


	protected bool globalHandleMouseButton(MouseButtonEvent e) {
		if (MouseButton.Right == e.button && !e.down) {
			this._dragging = false;
			//Stdout.formatln("DraggableView: drag end");
			return true;
		}
		
		return false;
	}


	protected EventHandling handleMouseMove(MouseMoveEvent e) {
		if (!_dragging) {
			return EventHandling.Continue;
		}
		//Stdout.formatln("DraggableView: mouse move: {}", e.delta);
		
		this.offset = this.offset + e.delta;
		
		return EventHandling.Continue;
	}
	
	
	this() {
		this.addHandler(&this.handleMouseButton);
		this.addHandler(&this.handleMouseMove);
	}


	protected {
		bool	_dragging;
	}

	mixin MWidget;
}


class GraphNodeBox : CustomWidgetT!(Draggable) {
	EventHandling handleClick(ClickEvent e) {
		if (e.bubbling && !e.handled && MouseButton.Left == e.button) {
			ulong time = g_stopWatch.microsec;
			if (lastClicked != ulong.max && time - lastClicked < doubleClickTime) {
				_doubleClicked = true;
			}
			lastClicked = time;
			return EventHandling.Stop;
		} else {
			return EventHandling.Continue;
		}
	}
	
	
	override void onGuiStructureBuilt() {
		super.onGuiStructureBuilt();
		_doubleClicked = false;
	}


	this() {
		this.addHandler(&this.handleClick);
	}
	
	
	protected {
		ulong lastClicked = ulong.max;
		const ulong doubleClickTime = 300_000;
	}

	mixin(defineProperties("char[] label, inline out bool doubleClicked, out bool deleteClicked"));
	mixin MWidget;
}



class DismissableOverlay : Group {
	override void onGuiStructureBuilt() {
		this._dismissed = false;
		super.onGuiStructureBuilt();
	}
	

	this() {
		this.addHandler(&this.handleMouseButton);
	}
	
	
	static bool anyVisibleChildContains(IWidget w, vec2 gp) {
		if (!w.containsGlobal(gp)) {
			return false;
		}
		
		if (w.style.background.available) {
			return true;
		}
		
		foreach (ch; &w.children) {
			if (auto r = anyVisibleChildContains(ch, gp)) {
				return r;
			}
		}
		
		return false;
	}

	
	EventHandling handleMouseButton(MouseButtonEvent e) {
		if (e.down && e.bubbling && !e.handled) {
			if (!anyVisibleChildContains(this, e.pos + this.globalOffset)) {
				_dismissed = true;
			}
			return EventHandling.Stop;
		} else {
			return EventHandling.Continue;
		}
	}
	
	
	override typeof(this) opIndex(void delegate() dg) {
		return cast(typeof(this))super.opIndex(dg);
	}


	mixin(defineProperties("inline out bool dismissed"));
	mixin MWidget;
}



class FloatingWindow : CustomWidgetT!(Draggable) {
	this() {
		addHandler(&this.keyHandler);
	}


	protected EventHandling keyHandler(KeyboardEvent e) {
		switch (e.keySym) {
			case KeySym.Escape: {
				if (e.sinking && e.down) {
					_escapeHit = true;
				}
			} return EventHandling.Stop;
			
			default: return EventHandling.Continue;
		}
	}


	override void onGuiStructureBuilt() {
		super.onGuiStructureBuilt();
		_escapeHit = false;
	}
	
	
	bool wantsToClose() {
		return closeClicked || _escapeHit;
	}
	
	
	protected {
		bool _escapeHit = false;
	}
	
	mixin(defineProperties("out bool minimizeClicked, out bool maximizeClicked, out bool closeClicked, out bool wantsToClose, char[] text"));
	mixin MWidget;
}


class ConnectionBreaker : GenericButton {
	mixin MWidget;
}


class CustomDrawWidget : Widget {
	override EventHandling handleRender(RenderEvent e) {
		if (!widgetVisible) {
			return EventHandling.Stop;
		}
		
		if (e.sinking && renderingHandler) {
			if (auto r = e.renderer) {
				r.pushClipRect();
				r.clip(Rect(this.globalOffset, this.globalOffset + this.size));
				r.direct(&this._handleRender, Rect(this.globalOffset, this.globalOffset + this.size));
				r.popClipRect();
			}
		}

		return EventHandling.Continue;
	}

	void _handleRender(GuiRenderer r) {
		renderingHandler(vec2i.from(this.size));
	}

	void delegate(vec2i) renderingHandler;

	mixin MWidget;
}


class MaterialBrowserWindow : CustomWidget {
	mixin MWidget;
}

class MaterialMiniatureBox : GenericButton {
	mixin MWidget;
}
