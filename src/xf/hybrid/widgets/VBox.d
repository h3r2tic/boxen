module xf.hybrid.widgets.VBox;

private {
	import xf.hybrid.Common;
	import xf.hybrid.Layout;
	import xf.hybrid.widgets.Group;
	import tango.io.Stdout;
}



class VBox : Group {
	this() {
		this.layout = new VBoxLayout;
	}

	
	VBox spacing(float val) {
		(cast(VBoxLayout)this.layout).spacing = val;
		return this;
	}
	float spacing() {
		return (cast(VBoxLayout)this.layout).spacing;
	}


	VBox padding(vec2 val) {
		(cast(VBoxLayout)this.layout).padding = val;
		return this;
	}
	vec2 padding() {
		return (cast(VBoxLayout)this.layout).padding;
	}



	mixin(defineProperties("float spacing, vec2 padding"));
	mixin MWidget;
}
