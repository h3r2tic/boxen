module xf.hybrid.widgets.TickBox;

private {
	import xf.hybrid.Common;
	import xf.hybrid.CustomWidget;
	import tango.io.Stdout;
}



class TickBox : CustomWidget {
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
		}
		return EventHandling.Continue;
	}
	
	EventHandling handleMouseEnter(MouseEnterEvent e) {
		enableStyle("hover");
		return EventHandling.Continue;
	}
	
	EventHandling handleMouseLeave(MouseLeaveEvent e) {
		disableStyle("hover");
		return EventHandling.Continue;
	}

	void onGuiStructureBuilt() {
		super.onGuiStructureBuilt();
	}
	
	this() {
		this.addHandler(&this.handleClick);
		this.addHandler(&this.handleMouseEnter);
		this.addHandler(&this.handleMouseLeave);
	}


	mixin(defineProperties("inline bool checked"));
	mixin MWidget;
}
