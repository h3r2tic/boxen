module xf.hybrid.widgets.Workspace;

private {
	import xf.hybrid.model.Core;
	import xf.hybrid.Common;
	import xf.hybrid.widgets.Group;
}



/**
	Container which z-orders its children and allows the z-order to be changed by clicking them	
	Properties:
	---
	// Sets the offset used for cascading newly added widgets
	// cascading is not currently implemented
	inline vec2 spawnSpacing
	---
*/
class Workspace : Widget {
	static class Attribs {
		Workspace	w;
		int				z;
		
		this(Workspace w, int z) {
			this.w = w;
			this.z = z;
		}
	}
	

	override typeof(this) removeChildren() {
		super.removeChildren();
		
		foreach (ch; _sortedChildren) {
			if (ch !is null) {
				ch.parent = null;
			}
		}

		_sortedChildren[] = null;
		
		return this;
	}

	
	override typeof(this) removeChild(IWidget _w) {
		int i = attr(_w).z;
		_sortedChildren[i].parent = null;
		_sortedChildren[i] = null;
		return this;
	}
	
	
	override typeof(this) addChild(IWidget _w) {
		auto w = cast(Widget)_w;
		assert (w !is null);
		
		if (w.customLayoutAttribs !is null) {
			if (auto la = cast(Attribs)w.customLayoutAttribs) {
				if (la.w is this) {
					// nothing
				} else w.customLayoutAttribs = null;
			} else w.customLayoutAttribs = null;
		}
		
		if (w.customLayoutAttribs is null) {
			w.customLayoutAttribs = new Attribs(this, _sortedChildren.length);
		}
		
		int z = attr(w).z;
		if (z >= _sortedChildren.length) {
			_sortedChildren.length = z + 1;
		} else if (_sortedChildren[z] !is null) {
			z = _sortedChildren.length;
			_sortedChildren.length = z + 1;
		}
		
		w.parent = this;
		attr(w).z = z;
		_sortedChildren[z] = w;
		
		return this;
	}
	
	
	override int children(int delegate(ref IWidget) dg) {
		foreach (ref ch; _sortedChildren) {
			if (ch !is null && ch.widgetEnabled) {
				IWidget w = ch;
				if (auto res = dg(w)) return res;
			}
		}
		return 0;
	}


	protected Attribs attr(IWidget foo) {
		return cast(Attribs)((cast(Widget)foo).customLayoutAttribs);
	}

	
	/**
		Makes the specified widget top-most
	*/
	void bringToTop(IWidget w) {
		int curZ = attr(w).z;
		
		int maxZ = 0;
		foreach (ch; &children) {
			auto a = attr(ch);
			
			if (a.z > maxZ) {
				maxZ = a.z;
			}
			
			if (a.z >= curZ) {
				--a.z;
			}
		}
		
		attr(w).z = maxZ;
	}


	protected EventHandling handleMouseButton(MouseButtonEvent e) {
		if (MouseButton.Left == e.button && e.down && e.sinking) {
			
			foreach_reverse (ch; _sortedChildren) {
				if (ch is null) {
					continue;
				}
				
				if (ch.containsGlobal(e.pos + this.globalOffset)) {
					bringToTop(ch);
					break;
				}
			}
		}
		
		return EventHandling.Continue;
	}
	

	override bool containsGlobal(vec2 pt) {
		if (_infinite) {
			return true;
		} else {
			return super.containsGlobal(pt);
		}
	}

	
	this() {
		_spawnSpacing = vec2(10, 10);
		layout = new GhostLayout;
		this.addHandler(&this.handleMouseButton);
	}
	
	
	override vec2 desiredSize() {
		return size;
	}

		
	protected {
		int			_nextChildZ = 0;
		Widget[]	_sortedChildren;
	}
	

	mixin(defineProperties("inline vec2 spawnSpacing, inline bool infinite"));
	mixin MWidget;
}
