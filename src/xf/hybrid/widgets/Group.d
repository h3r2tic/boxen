module xf.hybrid.widgets.Group;

private {
	import xf.hybrid.Common;
	import xf.hybrid.Layout;
	import xf.hybrid.model.Core;
	import tango.io.Stdout;
	import tango.stdc.string : memmove;
}



/**
	A minimal container. Children are stored in an array
*/
class Group : Widget {
	this() {
		this.layout = new VBoxLayout;
	}
	
	
	override int children(int delegate(ref IWidget) dg) {
		foreach (ref ch; _children) {
			if (ch.widgetEnabled) {
				IWidget w = ch;
				if (auto res = dg(w)) return res;
			}
		}
		return 0;
	}


	override typeof(this) removeChildren() {
		super.removeChildren();
		
		foreach (ch; _children) {
			ch.parent = null;
		}
		_children.length = 0;
		
		return this;
	}
	
	
	override typeof(this) removeChild(IWidget _w) {
		auto w = cast(Widget)_w;
		assert (w !is null);
		foreach (i, ref c; _children) {
			if (c is w) {
				c.parent = null;
				if (i+1 < _children.length) {
					memmove(&_children[i], &_children[i+1], Widget.sizeof * (_children.length - i - 1));
				}
				//_children[i .. $-1] = _children[i+1 .. $];
				_children = _children[0..$-1];
				return this;
			}
		}
		assert (false, "no such child");
		
		return this;
	}


	override /+protected +/typeof(this) addChild(IWidget _w) {
		auto w = cast(Widget)_w;
		assert (w !is null);
		assert (!w.hasParent);
		_children ~= w;
		w.parent = this;
		return this;
	}


	override vec2 desiredSize() {
		return size;
	}

	
	protected {
		Widget[] _children;
	}

	mixin MWidget;
}
