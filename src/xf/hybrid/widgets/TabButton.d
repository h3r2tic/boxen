module xf.hybrid.widgets.TabButton;

private {
	import xf.hybrid.Common;
	import xf.hybrid.CustomWidget;
	import xf.hybrid.widgets.Button : Button;
}



/**
	A button widget used by TabView
	Properties:
	---
	// 0 -> left-most tab button
	// 1 -> inner tab button
	// 2 -> right-most tab button
	int edgeType
	
	// Tells whether this button is the currently selected one
	inline bool active
	---
*/
class TabButton : Button {
	this() {
		if ("leftEdge" in subWidgets) {
			getAndRemoveSub("leftEdge", &_leftEdge);
		}
		
		if ("rightEdge" in subWidgets) {
			getAndRemoveSub("rightEdge", &_rightEdge);
		}
	}
	
	
	int edgeType() {
		return _edgeType;
	}
	
	
	typeof(this) edgeType(int e) {
		if (_leftEdge) {
			_leftEdge.widgetEnabled = 0 == e;
		}
		
		if (_rightEdge) {
			_rightEdge.widgetEnabled = 2 == e;
		}
		
		_edgeType = e;
		return this;
	}
	

	override EventHandling handleMouseButton(MouseButtonEvent e) {
		return EventHandling.Continue;
	}


	override EventHandling handleRender(RenderEvent e) {
		if (!widgetVisible) {
			return EventHandling.Stop;
		}

		if (_active) {
			disableStyle("hover");
			enableStyle("active");
		} else {
			disableStyle("active");
		}

		if (e.sinking) {
			if (_leftEdge) {
				_leftEdge.widgetVisible = false;
			}
			if (_rightEdge) {
				_rightEdge.widgetVisible = false;
			}
		}

		super.handleRender(e);
		
		if (e.bubbling) {
			if (_leftEdge && _leftEdge.widgetEnabled) {
				_leftEdge.widgetVisible = true;
				e.sinking = true;
				_leftEdge.treeHandleEvent(e);
			}
			if (_rightEdge && _rightEdge.widgetEnabled) {
				_rightEdge.widgetVisible = true;
				e.sinking = true;
				_rightEdge.treeHandleEvent(e);
			}

			e.sinking = false;
		}
		
		return EventHandling.Continue;
	}
	
	protected {
		Widget	_leftEdge;
		Widget	_rightEdge;
		int		_edgeType;
	}
	

	mixin(defineProperties("int edgeType, inline bool active"));
	mixin MWidget;
}
