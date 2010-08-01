module xf.hybrid.widgets.Graphic;

private {
	import xf.hybrid.Common;
	import xf.hybrid.GuiRenderer;
	import xf.hybrid.Shape;
	import xf.hybrid.widgets.Group;
	import tango.io.Stdout;
}



/**
	Properties:
	---
	// Makes the rendered shape larger or smaller
	inline vec2 renderOversize
	
	// Offsets the rendered shape
	inline vec2 renderOffset
	---
*/
class Graphic : Group {
	override void render(GuiRenderer r) {
		r.flushStyleSettings();
		final offBefore = r.getOffset;
		scope (exit) r.setOffset(offBefore);
		r.offset(this.renderOffset);
		r.shape(this.shape, this.size + this.renderOversize);
	}
	
	
	this() {
		_renderOversize = vec2.zero;
		_renderOffset = vec2.zero;
	}
	
	
	mixin(defineProperties("inline vec2 renderOversize, inline vec2 renderOffset"));
	mixin MWidget;
}
