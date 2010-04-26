module xf.hybrid.widgets.XCheck;

private {
	import xf.hybrid.Common;
	import xf.hybrid.CustomWidget;
	import xf.hybrid.Selectable;
	import tango.io.Stdout;
}



/**
	eXclusive Check, a.k.a. Radio Button
	
	Properties:
	---
	inline bool selected
	char[] text
	---
	
	To be used with XorSelector and DefaultOption
*/
class XCheck : CustomWidget, ISelectable {
	mixin MXorSelectable;


	override EventHandling handleRender(RenderEvent e) {
		if (this.selected) {
			disableStyle("hover");
			enableStyle("active");
		} else {
			disableStyle("active");
		}
		return super.handleRender(e);
	}
	
	
	protected void onSelected() {
		_selected = true;
	}
	
	
	protected void onDeselected() {
		_selected = false;
	}
	
	
	override bool initialized() {
		return super.initialized();
	}
	
	
	protected EventHandling handleClick(ClickEvent e) {
		this.select();
		return EventHandling.Stop;
	}
	
	
	protected EventHandling handleMouseEnter(MouseEnterEvent e) {
		enableStyle("hover");
		return EventHandling.Stop;
	}
	
	
	protected EventHandling handleMouseLeave(MouseLeaveEvent e) {
		disableStyle("hover");
		return EventHandling.Stop;
	}
	

	protected void onGuiStructureBuilt() {
		super.onGuiStructureBuilt();
	}
	
	
	this() {
		this.addHandler(&this.handleClick);
		this.addHandler(&this.handleMouseEnter);
		this.addHandler(&this.handleMouseLeave);
	}


	mixin(defineProperties("inline bool selected, char[] text"));
	mixin MWidget;
}
