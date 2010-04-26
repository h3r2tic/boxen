module xf.hybrid.Layout;

private {
	import xf.hybrid.Widget;
	import xf.hybrid.model.Core;
	import xf.hybrid.WidgetConfig;
	import xf.hybrid.Math;
	import xf.hybrid.HybridException;
	
	import tango.util.log.Trace;
	import tango.util.Convert;
	import tango.text.Util;
}



/**
	Base class for widget layouts
*/
abstract class Layout : ILayout {
	final void minimize(IWidget parent_) {
		auto parent = cast(Widget)parent_;
		assert (parent !is null);
		minimize(parent);
	}


	final void expand(IWidget parent_) {
		auto parent = cast(Widget)parent_;
		assert (parent !is null);
		expand(parent);
	}
	
	
	/**
		Sets layout attribs that apply to all widgets managed by this layout
	*/
	void attribs(char[] attr) {
	}


	/**
		Configures the layout using config data, e.g. sets its padding and spacing properties
	*/
	void configure(PropAssign[] cfg) {
	}


	/**
		This method must calculate the minimal size for the given widget. Minimize is called
		bottom-up, thus the layout may assume that all of the widget's descendants have already
		been minimized by layout mechanisms.
		
		minimize should call 'overrideSizeForFrame' on the given wigdet to set the minimal size.
	*/
	abstract void minimize(Widget);
	
	/**
		Once the 'minimize' step has finished, space allocation is expanded. For instance,
		a widget may get more space than it initially asked for and was given by the 'minimize'
		function of its layout. In such a case, it may be desired to allocate the space somehow
		for child widgets.
		
		Expand is called top-bottom, so it should assume that the given widget's 'size' property
		is the already-expanded size, and that the descendants' sizes will be minimal sizes.
		
		expand may call 'overrideSizeForFrame' on child widgets of the given widget.
	*/
	abstract void expand(Widget);
}


///
class BinLayout : Layout {
	public vec2 padding = vec2.zero;
	
	
	this() {
	}
	

	this (vec2 padding) {
		this.padding = padding;
	}


	override void configure(PropAssign[] cfg) {
		foreach (p; cfg) {
			switch (p.name) {
				case "padding": {
					this.padding = parseVec2(p.value);
				} break; default: break;
			}
		}
	}
	
	
	Widget getChild(Widget parent) {
		// it's not an in contract because DMD is a dipshit.
		assert({
			Widget child;
			foreach (ch; &parent.children) {
				if (child !is null) {
					hybridThrow("Attempting to add more than one child to a bin layout; have {{{}}, adding {{{}}", child, ch);
				}
				assert (child is null);		// a bin cannot have more than one child
				child = cast(Widget)ch;
				assert (child !is null);
			}
			return true;
		}());

		foreach (ch; &parent.children) {
			return cast(Widget)ch;
		}
		return null;
	}


	override void minimize(Widget parent) {
		//Trace.formatln(`BinLayout.minimize`);

		auto child = getChild(parent);
		if (child is null) {
			vec2 newSize = padding * 2;
			//if (newSize.x < parent.size.x && child.hexpand) newSize.x = parent.size.x;
			//if (newSize.y < parent.size.y && child.vexpand) newSize.y = parent.size.y;
			parent.overrideSizeForFrame(newSize);
			return;
		}

		child.parentOffset = padding;
		child.overrideSizeForFrame(child.desiredSize);

		vec2 newSize = child.size + padding * 2;
		//if (newSize.x < parent.size.x && child.hexpand) newSize.x = parent.size.x;
		//if (newSize.y < parent.size.y && child.vexpand) newSize.y = parent.size.y;
		if (newSize.x < parent.userSize.x) newSize.x = parent.userSize.x;
		if (newSize.y < parent.userSize.y) newSize.y = parent.userSize.y;
		parent.overrideSizeForFrame(newSize);
	}
	
	
	override void expand(Widget parent) {
		//Trace.formatln(`BinLayout.expand`);

		auto child = getChild(parent);
		if (child !is null) {
			child.parentOffset = padding;
				//writefln(`(bin) filling a %s from %s to %s (parent size: %s)`, child.classinfo.name, child.size, parent.size - padding * 2, parent.size);
			child.overrideSizeForFrame(parent.size - padding * 2);
				//Stdout.formatln(`child size = {} ; expand result = {}`, child.size.toString, parent.size.toString);
		}
	}
}


///
class BoxLayout(bool horizontal)  : Layout {
	static class Attribs {
		bool hexpand;
		bool hfill;
		bool vexpand;
		bool vfill;
	}
	
	
	const bool vertical = !horizontal;
	const int axis = horizontal ? 0 : 1;

	public vec2 padding	= vec2.zero;
	public float spacing		= 0.f;
	
	private Attribs _attribs = null;


	override void attribs(char[] attr) {
		_attribs = parseLayoutAttribs(attr);
	}


	override void configure(PropAssign[] cfg) {
		foreach (p; cfg) {
			switch (p.name) {
				case "padding": {
					this.padding = parseVec2(p.value);
				} break;
				
				case "spacing": {
					this.spacing = parseFloat(p.value);
				} break;
				
				case "attribs": {
					assert (Value.Type.String == p.value.type);
					this.attribs = p.value.String;
				} break;
			default:
				break;
			}
		}
	}


	private {
		float* a1(ref vec2 v)		{ return &v.cell[axis]; }
		float* a2(ref vec2 v)		{ return &v.cell[axis^1]; }
		
		byte shouldExpand(Widget w) {
			static if (0 == axis) return attr(w).hexpand || _attribs.hexpand;
			else return attr(w).vexpand || _attribs.vexpand;
		}
		
		byte shouldFill(Widget w) {
			static if (0 == axis) return attr(w).hfill || _attribs.hfill;
			else return attr(w).vfill || _attribs.vfill;
		}
			
		byte shouldExpand2(Widget w) {
			static if (0 == axis) return attr(w).vexpand || _attribs.vexpand;
			else return attr(w).hexpand || _attribs.hexpand;
		}
		
		byte shouldFill2(Widget w) {
			static if (0 == axis) return attr(w).vfill || _attribs.vfill;
			else return attr(w).hfill || _attribs.hfill;
		}
	}
	
	
	this() {
		attribs = null;
	}
	

	this (vec2 padding) {
		this.padding = padding;
	}
	
	
	private Attribs parseLayoutAttribs(char[] str) {
		//Trace.formatln("parseLayoutAttribs("~str~")");
		auto a = new Attribs;
		foreach (s; str.split(" ")) {
			switch (s) {
				case "hexpand": a.hexpand = true; break;
				case "hfill": a.hfill = true; break;
				case "vexpand": a.vexpand = true; break;
				case "vfill": a.vfill = true; break;
				default: {
					if (s.length > 0) {
						Trace.formatln("BoxLayout: unknown layout attrib: '" ~ s ~ "'");
					}
					break;
				}
			}
		}
		return a;
	}
	
	
	private Attribs attr(Widget w) {
		assert (w !is null);
		return cast(Attribs)w.customLayoutAttribs;
	}
	
	
	override void minimize(Widget parent) {
		//Trace.formatln(`BoxLayout.minimize`);

		vec2 minSize = vec2.zero;
		
		foreach (ch_; &parent.children) {
			auto ch = cast(Widget)ch_;
			assert(ch !is null);
			
			if (attr(ch) is null) {
				ch.customLayoutAttribs = parseLayoutAttribs(ch.layoutAttribs);
			}
			
			vec2 chSize = ch.desiredSize;
			ch.overrideSizeForFrame(chSize);
			*a1(minSize) += *a1(chSize);
			*a2(minSize) = max(*a2(minSize), *a2(chSize));
		}
		
		float curA1 = 0;
		int i = 0;
		foreach (ch_; &parent.children) {
			auto ch = cast(Widget)ch_;
			assert(ch !is null);
			
			if (i != 0) curA1 += spacing;
			
			vec2 chSize = ch.desiredSize;
			
			vec2 po = void;
			*a1(po) = curA1 + *a1(padding);
			*a2(po) = *a2(padding);
			ch.parentOffset = po;
			
			//writefln(`parent offset: `, ch.parentOffset);
			
			curA1 += *a1(chSize);
			++i;
		}
		
		*a1(minSize) = curA1;

		vec2 curSize = parent.userSize;//minSize - padding * 2;
		
		if (minSize.x < curSize.x) {
			minSize.x = curSize.x;
		}
		if (minSize.y < curSize.y) {
			minSize.y = curSize.y;
		}
		
		vec2 res = minSize + padding * 2;
		vec2 parentMin = parent.minSize;
		
		if (res.x < parentMin.x) res.x = parentMin.x;
		if (res.y < parentMin.y) res.y = parentMin.y;
		
		//return res;
		//Trace.formatln("Setting parent " ~ to!(char[])(cast(size_t)cast(void*)parent) ~ " size to " ~ to!(char[])(res));
		parent.overrideSizeForFrame(res);
	}
	
	
	override void expand(Widget parent) {
		//Trace.formatln(`BoxLayout.expand`);

		float minChildSize = 0;
		int numExpandable = 0;
		int numChildren = 0;
		
		foreach (ch_; &parent.children) {
			auto ch = cast(Widget)ch_;
			assert (ch !is null);
			
			minChildSize += *a1(ch.size);
			if (shouldExpand(ch)) {
				++numExpandable;
			}
			++numChildren;
		}
		
		float freeSize = *a1(parent.size) - minChildSize - *a1(padding)*2 - spacing * (numChildren - 1);
		
		// if this fails, the resizing has been used incorrectly
		//assert (freeSize >= 0.f, "parent" ~ to!(char[])(cast(size_t)cast(void*)parent) ~ ".size: " ~ to!(char[])(parent.size) ~ " freeSize: " ~ to!(char[])(freeSize));
		
		float extraSizePerWidget = freeSize / numExpandable;
		float inc = extraSizePerWidget - floor(extraSizePerWidget);
		extraSizePerWidget -= inc;
		float extra = 0;
		
		float curPos = *a1(padding);
		
		foreach (c_; &parent.children) {
			auto c = cast(Widget)c_;
			assert (c !is null);
			
			float size = *a1(c.size);
			if (shouldExpand(c)) {
				size += extraSizePerWidget + extra;
				//if (extra >= 1) extra -= 1;
				extra += inc;
			}
			
			float size2 = *a2(parent.size) - *a2(padding) * 2;
			

			// got the slot size. now distinguish slots that shouldFill that space from these which don't

			vec2 po = c.parentOffset;
			
			if (shouldExpand(c)) {
				if (shouldFill(c)) {
					*a1(po) = curPos;
					vec2 s = c.size;
					*a1(s) = size;
					c.overrideSizeForFrame(s);
					//writefln(`filling a %s from %s to %s (parent size: %s)`, c.classinfo.name, c.size, size_, parent.size);
				} else {
					*a1(po) = cast(int)(curPos + (size - *a1(c.size)) / 2);
					// TODO: anything else?
				}
			} else {
				if (shouldFill(c)) {
					*a1(po) = curPos;
					vec2 s = c.size;
					*a1(s) = size;
					c.overrideSizeForFrame(s);
				} else {
					float offset = cast(int)((size - *a1(c.size)) / 2);
					*a1(po) = curPos + offset;
				}
					//writefln(`filling a %s from %s to %s (parent size: %s)`, c.classinfo.name, c.size, size_, parent.size);
					//*a1(c.parentOffset) = curPos;
			}

			if (shouldExpand2(c)) {
				if (shouldFill2(c)) {
					*a2(po) = *a2(padding);
					vec2 s = c.size;
					*a2(s) = size2;
					c.overrideSizeForFrame(s);
					//writefln(`filling a %s from %s to %s (parent size: %s)`, c.classinfo.name, c.size, size_, parent.size);
				} else {
					float offset = cast(int)((size2 - *a2(c.size)) / 2);
					
					*a2(po) = *a2(padding) + offset;
					
					// TODO: wth?
					//*a2(c.size) = *a2(c.size);
				}
			
			}
			c.parentOffset = po;			
			curPos += size + spacing;
		}
	}
}



///
class LayeredLayout : Layout {
	static class Attribs {
		bool hfill;
		bool vfill;
	}
	

	private Attribs _attribs = null;


	override void configure(PropAssign[] cfg) {
		foreach (p; cfg) {
			switch (p.name) {
				case "attribs": {
					assert (Value.Type.String == p.value.type);
					this.attribs = p.value.String;
				} break; default: break;
			}
		}
	}


	override void attribs(char[] attr) {
		_attribs = parseLayoutAttribs(attr);
	}

	
	this() {
		attribs = null;
	}
		
	
	private Attribs parseLayoutAttribs(char[] str) {
		auto a = new Attribs;
		foreach (s; str.split(" ")) {
			switch (s) {
				case "hfill": a.hfill = true; break;
				case "vfill": a.vfill = true; break;
				default: {
					if (s.length > 0) {
						Trace.formatln("LayeredLayout: unknown layout attrib: '" ~ s ~ "'");
					}
					break;
				}
			}
		}
		return a;
	}
	
	
	private Attribs attr(Widget w) {
		assert (w !is null);
		return cast(Attribs)w.customLayoutAttribs;
	}
	
	
	override void minimize(Widget parent) {
		vec2 minSize = parent.userSize;
		
		foreach (ch_; &parent.children) {
			auto ch = cast(Widget)ch_;
			assert(ch !is null);
			
			if (attr(ch) is null) {
				ch.customLayoutAttribs = parseLayoutAttribs(ch.layoutAttribs);
			}
			
			vec2 chSize = ch.desiredSize;
			ch.overrideSizeForFrame(chSize);
			
			minSize.x = max(minSize.x, chSize.x);
			minSize.y = max(minSize.y, chSize.y);
		}
		
		parent.overrideSizeForFrame(minSize);
	}
	
	
	override void expand(Widget parent) {
		foreach (ch_; &parent.children) {
			auto ch = cast(Widget)ch_;
			assert (ch !is null);
			
			vec2 po = void;
			
			if (attr(ch).hfill || _attribs.hfill) {
				po.x = 0.f;
				ch.overrideSizeForFrame(vec2(parent.size.x, ch.size.y));
			} else {
				po.x = cast(int)((parent.size.x - ch.size.x) / 2);
			}

			if (attr(ch).vfill || _attribs.vfill) {
				po.y = 0.f;
				ch.overrideSizeForFrame(vec2(ch.size.x, parent.size.y));
			} else {
				po.y = cast(int)((parent.size.y - ch.size.y) / 2);
			}
			
			ch.parentOffset = po;
		}
	}
}


///
class FreeLayout : Layout {
	override void minimize(Widget parent) {
		vec2 ms = vec2.zero;
		
		foreach (ch_; &parent.children) {
			auto ch = cast(Widget)ch_;
			assert(ch !is null);
			
			vec2 s = ch.minSize;
			if (s.x > ms.x) {
				ms.x = s.x;
			}
			if (s.y > ms.y) {
				ms.y = s.y;
			}
		}
		
		parent.overrideSizeForFrame(ms);
	}
	
	override void expand(Widget parent) {
	}
}


///
class GhostLayout : Layout {
	override void minimize(Widget parent) {
		foreach (ch_; &parent.children) {
			auto ch = cast(Widget)ch_;
			assert(ch !is null);
			
			ch.overrideSizeForFrame(ch.desiredSize);
		}
		
		parent.overrideSizeForFrame(parent.userSize);//vec2.zero;
	}
	
	override void expand(Widget parent) {
	}
}



///
alias BoxLayout!(true)	HBoxLayout;

///
alias BoxLayout!(false)	VBoxLayout;



///
class VFlowLayout : Layout {
	public vec2 padding	= vec2.zero;
	public float spacing		= 0.f;
	
	override void configure(PropAssign[] cfg) {
		foreach (p; cfg) {
			switch (p.name) {
				case "padding": {
					this.padding = parseVec2(p.value);
				} break;
				
				case "spacing": {
					this.spacing = parseFloat(p.value);
				} break;
			default:
				break;
			}
		}
	}


	override void minimize(Widget parent) {
		float minHeight = padding.y * 2;
		float width = parent.size.x - padding.x * 2;

		float curX = 0;
		float curY = 0;
		float rowHeight = 0;
		
		foreach (ch_; &parent.children) {
			auto ch = cast(Widget)ch_;
			assert(ch !is null);

			vec2 chSize = ch.desiredSize;
			ch.overrideSizeForFrame(chSize);
			
			if (curX + chSize.x > width) {
				curY += rowHeight + spacing;
				curX = 0;
				rowHeight = 0;
			}
			
			rowHeight = max(rowHeight, chSize.y);
			ch.parentOffset = vec2(curX+padding.x, curY+padding.y);
			curX += chSize.x;
			curX += spacing;
		}
		
		vec2 curSize = parent.userSize;
		vec2 minSize = vec2(width, curY+rowHeight);
		//vec2 minSize = vec2(width, 0);
		minSize += padding * 2;
		
		if (minSize.x < curSize.x) {
			minSize.x = curSize.x;
		}
		if (minSize.y < curSize.y) {
			minSize.y = curSize.y;
		}
		
		vec2 res = minSize;
		vec2 parentMin = parent.minSize;
		
		if (res.x < parentMin.x) res.x = parentMin.x;
		if (res.y < parentMin.y) res.y = parentMin.y;
		
		parent.overrideSizeForFrame(res);
	}
	
	
	override void expand(Widget parent) {
		float minHeight = padding.y * 2;
		float width = parent.size.x - padding.x * 2;

		float curX = 0;
		float curY = 0;
		float rowHeight = 0;
		
		foreach (ch_; &parent.children) {
			auto ch = cast(Widget)ch_;
			assert(ch !is null);

			vec2 chSize = ch.size;
			
			if (curX + chSize.x > width) {
				curY += rowHeight + spacing;
				curX = 0;
				rowHeight = 0;
			}
			
			rowHeight = max(rowHeight, chSize.y);
			ch.parentOffset = vec2(curX+padding.x, curY+padding.y);
			curX += chSize.x;
			curX += spacing;
		}
		
		/+vec2 curSize = parent.userSize;
		//vec2 minSize = vec2(width, curY+rowHeight);
		vec2 minSize = vec2(width, 0);
		minSize += padding * 2;
		
		if (minSize.x < curSize.x) {
			minSize.x = curSize.x;
		}
		if (minSize.y < curSize.y) {
			minSize.y = curSize.y;
		}
		
		vec2 res = minSize;
		vec2 parentMin = parent.minSize;
		
		if (res.x < parentMin.x) res.x = parentMin.x;
		if (res.y < parentMin.y) res.y = parentMin.y;+/
	}
}



static this() {
	registerLayout("Bin", function ILayout() {
		return new BinLayout;
	});

	registerLayout("VBox", function ILayout() {
		return new VBoxLayout;
	});

	registerLayout("HBox", function ILayout() {
		return new HBoxLayout;
	});

	registerLayout("Layered", function ILayout() {
		return new LayeredLayout;
	});

	registerLayout("Free", function ILayout() {
		return new FreeLayout;
	});

	registerLayout("Ghost", function ILayout() {
		return new GhostLayout;
	});

	registerLayout("VFlow", function ILayout() {
		return new VFlowLayout;
	});
}
