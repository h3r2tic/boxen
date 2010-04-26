module xf.hybrid.widgets.ClipView;

private {
	import xf.hybrid.Common;
	import xf.hybrid.Shape;
	import xf.hybrid.widgets.Group;
}



/**
	Clips children to its size, can be panned. Can inherit child size for one of axes
	Properties:
	---
	inline vec2 offset
	
	// Don't override size in one of the axes; 1 -> x, 2 -> y
	inline int useChildSize
	---
*/
class ClipView : Group {
	override bool childrenGoAbove() {
		return false;
	}


	override Rect clipRect() {
		return Rect(this.globalOffset, this.globalOffset + this.size);
	}
	

	override EventHandling handleMinimizeLayout(MinimizeLayoutEvent e) {
		auto res = super.handleMinimizeLayout(e);
		if (e.bubbling) {
			calculatedSize = this.size;
			vec2 ns = userSize;
			if (useChildSize & 1) {
				ns.x = this.size.x;
			}
			if (useChildSize & 2) {
				ns.y = this.size.y;
			}
			this.overrideSizeForFrame(ns);
		}
		return res;
	}
	

	override EventHandling handleExpandLayout(ExpandLayoutEvent e) {
		vec2 expandedSize = this.size;

		{
			vec2 ns = calculatedSize;
			if (useChildSize & 1) {
				ns.x = this.size.x;
			}
			if (useChildSize & 2) {
				ns.y = this.size.y;
			}
			this.overrideSizeForFrame(ns);
		}

		//this.size = calculatedSize;
		auto res = super.handleExpandLayout(e);
		
		if (e.bubbling) {
			foreach (ch; &this.children) {
				auto w = cast(Widget)ch;
				assert (w !is null);
				w.parentOffset = w.parentOffset + this._offset;
			}
		}
		
		//this.size = expandedSize;//userSize;
		
		{
			vec2 ns = expandedSize;
			if (useChildSize & 1) {
				ns.x = this.size.x;
			}
			if (useChildSize & 2) {
				ns.y = this.size.y;
			}
			this.overrideSizeForFrame(ns);
		}
		
		return res;
	}
	
	
	/**
		Returns the size that the children are currently using
	*/
	vec2 childrenSize() {
		return calculatedSize;
	}
	
	
	this() {
		_offset = vec2.zero;
		this.userSize = vec2(1, 1);
	}
	

	protected {
		vec2	calculatedSize = vec2.zero;
	}


	mixin(defineProperties("inline vec2 offset, inline int useChildSize"));
	mixin MWidget;
}
