module xf.hybrid.widgets.ScrollView;

private {
	import xf.hybrid.Common;
	import xf.hybrid.CustomWidget;
	import xf.hybrid.widgets.Scrollbar : HScrollbar, VScrollbar;
	import xf.hybrid.widgets.ClipView : ClipView;
	import xf.input.KeySym;
	
	import tango.util.log.Trace;
}



/**
	A container that holds its children in a ClipView whose contents can be moved using a horizontal
	and a vertical scrollbar displayed next to and below it.
	
	The scrollbars appear only when the space of the children area would overflow the size of the ClipView
*/
class ScrollView : CustomWidget {
	this() {
		getAndRemoveSub("hscroll", &_hscroll);
		getAndRemoveSub("vscroll", &_vscroll);
		getAndRemoveSub("clipView", &_clipView);
		getAndRemoveSub("corner", &_corner);
		addHandler(&handleKey);
		addHandler(&handleMouseButton);
		
		_hscroll.widgetEnabled = false;
		_vscroll.widgetEnabled = false;
		_corner.widgetEnabled = false;
	}


	override bool childrenGoAbove() {
		return false;
	}
	
	
	void overrideHScroll(HScrollbar h) {
		_hscroll = h;
	}


	void overrideVScroll(VScrollbar v) {
		_vscroll = v;
	}


	override EventHandling handleMinimizeLayout(MinimizeLayoutEvent e) {
		if (e.sinking) {
			vec2 contentSize = _clipView.childrenSize;
			vec2 viewSize = _clipView.size;
			
			vec2 cvoff = vec2.zero;
			
			bool enableCorner = true;
			
			if (contentSize.x > viewSize.x) {
				_hscroll.widgetEnabled = true;
				_hscroll.handleSize = viewSize.x / contentSize.x;
				cvoff.x = contentSize.x * -_hscroll.position;
			} else {
				_hscroll.widgetEnabled = false;
				_hscroll.position = 0;
				enableCorner = false;
			}

			if (contentSize.y > viewSize.y) {
				_vscroll.widgetEnabled = true;
				_vscroll.handleSize = viewSize.y / contentSize.y;
				cvoff.y = contentSize.y * -_vscroll.position;
			} else {
				_vscroll.widgetEnabled = false;
				_vscroll.position = 0;
				enableCorner = false;
			}
			
			_corner.widgetEnabled = enableCorner;
			
			//Trace.formatln("{}, {}, {}, {}", contentSize, cvoff, _hscroll.position, _vscroll.position);
			
			// HACK: we're explicitly thinking 'pixels' here.
			cvoff.x = rndint(cvoff.x);
			cvoff.y = rndint(cvoff.y);
			
			_clipView.offset = cvoff;
		}
		
		return super.handleMinimizeLayout(e);
	}
	
	
	protected EventHandling handleMouseButton(MouseButtonEvent e) {
		if (!e.bubbling || e.handled) {
			return EventHandling.Continue;
		}
		
		switch (e.button) {
			case MouseButton.WheelUp: {
				_vscroll.position = _vscroll.position - _vscroll.smallSkipSize;
				return EventHandling.Stop;
			} break;

			case MouseButton.WheelDown: {
				_vscroll.position = _vscroll.position + _vscroll.smallSkipSize;
				return EventHandling.Stop;
			} break;
			
			default: {
				return EventHandling.Continue;
			}
		}
	}
	
	
	protected EventHandling handleKey(KeyboardEvent e) {
		if (!e.bubbling || e.handled) {
			return EventHandling.Continue;
		}
		
		switch (e.keySym) {
			case KeySym.Page_Up: {
				if (_vscroll.widgetEnabled && e.down) {
					_vscroll.position = _vscroll.position - _vscroll.skipSize;
				}
			} return EventHandling.Stop;

			case KeySym.Page_Down: {
				if (_vscroll.widgetEnabled && e.down) {
					_vscroll.position = _vscroll.position + _vscroll.skipSize;
				}
			} return EventHandling.Stop;
			
			case KeySym.Up: {
				if (_vscroll.widgetEnabled && e.down) {
					_vscroll.position = _vscroll.position - _vscroll.smallSkipSize;
				}
			} return EventHandling.Stop;

			case KeySym.Down: {
				if (_vscroll.widgetEnabled && e.down) {
					_vscroll.position = _vscroll.position + _vscroll.smallSkipSize;
				}
			} return EventHandling.Stop;

			case KeySym.Left: {
				if (_hscroll.widgetEnabled && e.down) {
					_hscroll.position = _hscroll.position - _hscroll.smallSkipSize;
				}
			} return EventHandling.Stop;

			case KeySym.Right: {
				if (_hscroll.widgetEnabled && e.down) {
					_hscroll.position = _hscroll.position + _hscroll.smallSkipSize;
				}
			} return EventHandling.Stop;

			default: return EventHandling.Continue;
		}
	}
	
	
	protected {
		HScrollbar	_hscroll;
		VScrollbar	_vscroll;
		ClipView	_clipView;
		Widget		_corner;
	}


	mixin(defineProperties("int useChildSize, float hFraction, float vFraction"));
	mixin MWidget;
}
