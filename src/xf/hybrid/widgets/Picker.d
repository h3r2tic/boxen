module xf.hybrid.widgets.Picker;

private {
	import xf.hybrid.Common;
	import xf.hybrid.CustomWidget;
	import tango.io.Stdout;
}



class Picker : CustomWidget {
	override bool childrenGoAbove() {
		return false;
	}

	
	EventHandling handleClick(ClickEvent e) {
		_lastClick = e.pos;
		_justClicked = true;
		return EventHandling.Stop;
	}


	EventHandling handleMouseMove(MouseMoveEvent e) {
		_lastMousePos = e.pos;
		return EventHandling.Stop;
	}


	EventHandling handleMouseLeave(MouseLeaveEvent e) {
		_lastMousePos = vec2.init;
		return EventHandling.Stop;
	}
	

	EventHandling handleMouseButton(MouseButtonEvent e) {
		if (MouseButton.Left == e.button) {
			return EventHandling.Stop;
		} else {
			return EventHandling.Continue;
		}
	}
	
	
	override EventHandling handleMinimizeLayout(MinimizeLayoutEvent e) {
		if (e.sinking) {
			auto bg = cast(Widget)getSub("background");
			auto fg = cast(Widget)getSub("foreground");
			
			bg.userSize = vec2.zero;
			fg.userSize = vec2.zero;
			bg.parentOffset = vec2.zero;
			fg.parentOffset = vec2.zero;
		}
		
		return super.handleMinimizeLayout(e);
	}


	override EventHandling handleExpandLayout(ExpandLayoutEvent e) {
		if (e.bubbling) {
			if (_lastClick.isCorrect) {
				int i = 0;
				foreach (ch; &this.getSub(null).children) {
					if (ch.containsGlobal(_lastClick + this.globalOffset)) {
						auto w = cast(Widget)ch;
						_pickedIdx = i;
						break;
					}
					++i;
				}
			}

			int hlightIdx;
			vec2 pos, size;		
			bool found = false;
			
			if (_lastMousePos.isCorrect) {
				int i = 0;
				foreach (ch; &this.getSub(null).children) {
					if (ch.containsGlobal(_lastMousePos + this.globalOffset)) {
						auto w = cast(Widget)ch;
						pos = w.globalOffset;
						size = w.size;
						found = true;
						hlightIdx = i;
						break;
					}
					++i;
				}
			}

			if (found) {
				auto bg = cast(Widget)getSub("background");
				auto fg = cast(Widget)getSub("foreground");
				
				bg.userSize = size;
				fg.userSize = size;
				bg.parentOffset = pos - bg.parent.globalOffset;
				fg.parentOffset = pos - fg.parent.globalOffset;
				
				scope min	= new MinimizeLayoutEvent;
				scope exp	= new ExpandLayoutEvent;
				scope off	= new CalcOffsetsEvent;
				
				bg.treeHandleEvent(min);
				bg.treeHandleEvent(exp);
				bg.treeHandleEvent(off);

				fg.treeHandleEvent(min);
				fg.treeHandleEvent(exp);
				fg.treeHandleEvent(off);
			}
		}
		
		return super.handleExpandLayout(e);
	}
	
	
	void resetPick() {
		_pickedIdx = -1;
		_lastClick = vec2.init;
	}
	
	
	bool anythingPicked() {
		return _pickedIdx != -1;
	}

	
	this() {
		resetPick();
		addHandler(&handleClick);
		addHandler(&handleMouseButton);
		addHandler(&handleMouseMove);
		addHandler(&handleMouseLeave);
	}
	
	
	protected {
		vec2	_lastClick;
		vec2	_lastMousePos;
		bool	_justClicked = false;
	}
	
	
	mixin(defineProperties("inline out int pickedIdx"));
	mixin MWidget;
}
