module xf.hybrid.widgets.Draggable;

private {
	import xf.hybrid.Common;
	import xf.hybrid.widgets.Group;
	
	import tango.util.log.Trace;
}



/**
	A very simple container which may be dragged using the mouse
	Properties:
	---
	// If true, overrides children's EventHandling.Stop
	// for mouse events; false by default
	inline bool alwaysDrag
	---
*/
class Draggable : Group {
	protected EventHandling handleMouseButton(MouseButtonEvent e) {
		if (MouseButton.Left == e.button && e.down && ((e.sinking && alwaysDrag) || (e.bubbling && !e.handled))) {
			this._dragging = true;
			
			Trace.formatln("drag start");
			gui.addGlobalHandler(&this.globalHandleMouseButton);
			
			if (e.bubbling) {
				return EventHandling.Stop;
			}
		}
		
		return EventHandling.Continue;
	}


	protected bool globalHandleMouseButton(MouseButtonEvent e) {
		if (MouseButton.Left == e.button && !e.down) {
			this._dragging = false;
			Trace.formatln("drag end");
			return true;
		}
		
		return false;
	}


	protected EventHandling handleMouseMove(MouseMoveEvent e) {
		if (!_dragging) {
			return EventHandling.Continue;
		}
		
		this.parentOffset = this.parentOffset + e.delta;
		
		return EventHandling.Continue;
	}
	
	
	this() {
		this.addHandler(&this.handleMouseButton);
		this.addHandler(&this.handleMouseMove);
	}


	protected {
		bool	_dragging;
	}
	

	mixin(defineProperties("inline bool alwaysDrag"));
	mixin MWidget;
}
