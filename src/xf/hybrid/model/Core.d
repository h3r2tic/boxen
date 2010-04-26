module xf.hybrid.model.Core;

private {
	import xf.hybrid.WidgetConfig;
	import xf.hybrid.Property;
	import xf.hybrid.Event;
	import xf.hybrid.Style;
	import xf.hybrid.Shape;
	import xf.hybrid.Math;
	import xf.utils.StructClass : MSimpleStructCtor;
	import tango.stdc.stdlib : alloca;
}


/**
	Reduces coupling and helps avoid recursive imports. Please refer to the xf.hybrid.Widget documentation
*/
interface IWidget : IPropertySupport {
	bool		widgetEnabled();
	IWidget	widgetEnabled(bool b);

	bool hasParent();
	bool childrenGoAbove();
	int children(int delegate(ref IWidget));
	IWidget getSub(char[] name);
	void addSub(IWidget w, char[] name);
	IWidget removeChildren();
	IWidget addChild(IWidget);
	IWidget removeChild(IWidget);
	OpenWidgetProxy _open(char[] name = null);
	
	IWidget		parent();
	IWidget		parent(IWidget);
	
	IWidget		shape(Shape);
	Shape		shape();

	IWidget		overrideSizeForFrame(vec2);
	vec2			size();

	IWidget		userSize(vec2);
	vec2			userSize();

	IWidget		parentOffset(vec2);
	vec2			parentOffset();

	IWidget		globalOffset(vec2);
	vec2			globalOffset();
	
	vec2			desiredSize();

	void registerStyle(char[] name, Style st);
	void enableStyle(char[] name);
	void disableStyle(char[] name);
	Style	style();

	bool containsGlobal(vec2 pt);
	void onGuiStructureBuilt();

	IWidget layout(ILayout);
	ILayout	layout();
	IWidget layoutAttribs(char[] attr);
	char[]	layoutAttribs();

	// returns true if the event is consumed
	EventHandling handleEvent(Event);
	EventHandling treeHandleEvent(Event);
	bool blockEventProcessing(Event);
}


struct OpenWidgetProxy {
	IWidget widget;
	
	void addChild(IWidget w) {
		return widget.addChild(w);
	}
}


/**
	Reduces coupling and helps avoid recursive imports. Please refer to the xf.hybrid.Layout documentation
*/
interface ILayout {
	void minimize(IWidget);		// bottom-top
	void expand(IWidget);		// top-down
	void configure(PropAssign[]);
}


/**
	Create a new Layout instance from the name
*/
ILayout createLayout(char[] name) {
	assert (name in layoutRegister, "Unknown layout: '" ~ name ~ "'");
	return layoutRegister[name]();
}


private {
	ILayout function()[char[]]	layoutRegister;
}

public {
	/**
		Registers a layout factory under the name
	*/
	void registerLayout(char[] name, ILayout function() func) {
		layoutRegister[name] = func;
	}
}



private enum WidgetIterDir : int {
	TopBottom,
	BottomTop,
	InvDepthFirst
}


private struct WidgetIterator(WidgetIterDir direction) {
	private {
		IWidget	root;
		bool delegate(IWidget w) _filter;
		
		alias int delegate(ref IWidget) DgType;
	
		int iterChildren(IWidget w, DgType dg) {
			foreach (ref c; &w.children) {
				if (auto r = iterAll(c, dg)) return r;
			}
			return 0;
		}
		
		int revIterChildren(IWidget w, DgType dg) {
			int numChildren = 0;
			foreach (ref c; &w.children) {
				++numChildren;
			}
			
			IWidget[] children = (cast(IWidget*)alloca(numChildren * IWidget.sizeof))[0 .. numChildren];
			foreach (ref c; &w.children) {
				children[--numChildren] = c;
			}
			
			foreach (c; children) {
				if (auto r = iterAll(c, dg)) return r;
			}

			/+foreach_reverse (ref c; &w.children) {
				if (auto r = iterAll(c, dg)) return r;
			}+/
			return 0;
		}

		int iterAll(IWidget w, DgType dg) {
			if (_filter is null || _filter(w)) {
				static if (WidgetIterDir.InvDepthFirst == direction) {
					if (auto r = dg(w)) return r;
					if (auto r = iterChildren(w, dg)) return r;
				} else static if (WidgetIterDir.TopBottom == direction) {
					if (w.childrenGoAbove) {
						if (auto r = revIterChildren(w, dg)) return r;
						if (auto r = dg(w)) return r;
					} else {
						if (auto r = dg(w)) return r;
						if (auto r = revIterChildren(w, dg)) return r;
					}
				} else static if (WidgetIterDir.BottomTop == direction) {
					if (w.childrenGoAbove) {
						if (auto r = dg(w)) return r;
						if (auto r = iterChildren(w, dg)) return r;
					} else {
						if (auto r = iterChildren(w, dg)) return r;
						if (auto r = dg(w)) return r;
					}
				} else static assert (false);
			}
			
			return 0;
		}
	}
	
	
	int opApply(DgType dg) {
		assert (dg !is null);
		assert (root !is null);
		return iterAll(root, dg);
	}
	
	
	WidgetIterator filter(bool delegate(IWidget w) dg) {
		this._filter = dg;
		return *this;
	}
	

	static WidgetIterator opCall(IWidget root) {
		WidgetIterator res;
		res.root = root;
		return res;
	}
}


// These pretend to be functions :P
alias WidgetIterator!(WidgetIterDir.TopBottom)	iterTopBottom;
alias WidgetIterator!(WidgetIterDir.BottomTop)	iterBottomTop;
alias WidgetIterator!(WidgetIterDir.InvDepthFirst)	iterInvDepthFirst;
