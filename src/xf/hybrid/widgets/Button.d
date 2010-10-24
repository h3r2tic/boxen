module xf.hybrid.widgets.Button;

private {
	import xf.hybrid.Common;
	import xf.hybrid.CustomWidget;
	import tango.io.Stdout;
}



/**
	A basic clickable widget
	
	Properties:
	---
	inline out bool clicked
	inline out bool active
	inline out bool hover
	---
*/
class GenericButton : CustomWidget {
	EventHandling handleClick(ClickEvent e) {
		if (e.bubbling && !e.handled) {
			this._clicked = true;
			return EventHandling.Stop;
		}
		return EventHandling.Continue;
	}
	
	EventHandling handleMouseButton(MouseButtonEvent e) {
		if (MouseButton.Left == e.button && e.bubbling && !e.handled) {
			if (e.down) {
				gui.addGlobalHandler(&this.globalHandleMouseButton);
				enableStyle("active");
				_active = true;
			}

			return EventHandling.Stop;
		} else {
			return EventHandling.Continue;
		}
	}

	bool globalHandleMouseButton(MouseButtonEvent e) {
		if (MouseButton.Left == e.button) {
			if (!e.down) {
				disableStyle("active");
				_active = false;
				return true;
			}
		}
		
		return false;
	}

	EventHandling handleMouseEnter(MouseEnterEvent e) {
		_hover = true;
		enableStyle("hover");
		return EventHandling.Continue;
	}
	
	EventHandling handleMouseLeave(MouseLeaveEvent e) {
		_hover = false;
		disableStyle("hover");
		return EventHandling.Continue;
	}

	override void onGuiStructureBuilt() {
		this._clicked = false;
		super.onGuiStructureBuilt();
	}
	
	this() {
		this.addHandler(&this.handleClick);
		this.addHandler(&this.handleMouseButton);
		this.addHandler(&this.handleMouseEnter);
		this.addHandler(&this.handleMouseLeave);
	}


	mixin(defineProperties("inline out bool clicked, inline out bool active, inline out bool hover"));
	mixin MWidget;
}


/**
	The common button with a label
	Properties:
	----
	char[] text
	----
*/
class Button : GenericButton {
	mixin(defineProperties("char[] text"));
	mixin MWidget;
}
