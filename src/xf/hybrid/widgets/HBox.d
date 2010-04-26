module xf.hybrid.widgets.HBox;

private {
	import xf.hybrid.Common;
	import xf.hybrid.Layout;
	import xf.hybrid.widgets.Group;
	import tango.io.Stdout;
}



class HBox : Group {
	this() {
		this.layout = new HBoxLayout;
	}
	
	
	HBox spacing(float val) {
		(cast(HBoxLayout)this.layout).spacing = val;
		return this;
	}
	float spacing() {
		return (cast(HBoxLayout)this.layout).spacing;
	}
	
	
	HBox padding(vec2 val) {
		(cast(HBoxLayout)this.layout).padding = val;
		return this;
	}
	vec2 padding() {
		return (cast(HBoxLayout)this.layout).padding;
	}



	mixin(defineProperties("float spacing, vec2 padding"));
	mixin MWidget;
}
