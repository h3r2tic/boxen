module xf.hybrid.widgets.Check;

private {
	import xf.hybrid.Common;
	import xf.hybrid.CustomWidget;
	import tango.io.Stdout;
}



/**
	A checkbox

	Properties:
	---
	bool checked
	char[] text
	---
*/
class Check : CustomWidget {
	override EventHandling handleRender(RenderEvent e) {
		if (this.checked) {
			enableStyle("active");
		} else {
			disableStyle("active");
		}
		return super.handleRender(e);
	}
	
	EventHandling handleClick(ClickEvent e) {
		if (MouseButton.Left == e.button) {
			this.checked = !this.checked;
			return EventHandling.Stop;
		} else {
			return EventHandling.Continue;
		}
	}
	
	EventHandling handleMouseEnter(MouseEnterEvent e) {
		enableStyle("hover");
		return EventHandling.Stop;
	}
	
	EventHandling handleMouseLeave(MouseLeaveEvent e) {
		disableStyle("hover");
		return EventHandling.Stop;
	}

	void onGuiStructureBuilt() {
		super.onGuiStructureBuilt();
	}
	
	this() {
		this.addHandler(&this.handleClick);
		this.addHandler(&this.handleMouseEnter);
		this.addHandler(&this.handleMouseLeave);
	}

	mixin(defineProperties("bool checked, char[] text"));
	mixin MWidget;
}
