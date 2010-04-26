module xf.hybrid.Widget;

private {
	import xf.hybrid.model.Core;
	import xf.hybrid.Context;
	import xf.hybrid.Property;
	import xf.hybrid.Shape;
	import xf.hybrid.Event;
	import xf.hybrid.GuiRenderer;
	import xf.hybrid.Style;
	import xf.hybrid.WidgetProp;
	import xf.hybrid.Config : parseWidgetBody;
	import xf.hybrid.WidgetTree;
	import xf.hybrid.Math;
	
	import xf.utils.Meta;
	
	import tango.core.Traits : ParameterTupleOf, ReturnTypeOf;
	import tango.util.log.Trace;
	import tango.util.Convert;
}

public {
	import xf.hybrid.Misc;
	import xf.hybrid.WidgetFactory;
}



template MWidgetCfg() {
	import xf.hybrid.WidgetConfig : PropAssign, WidgetSpec;

	typeof(this) cfg(char[] data) {
		PropAssign[] props;
		WidgetSpec[] children;
		xf.hybrid.Config.parseWidgetBody(data, props, children);
		foreach (p; props) {
			if (!xf.hybrid.WidgetProp.handleWidgetPropAssign(this, getSub(null), p)) {
				//throw new Exception("can't handle prop '" ~ data ~ "'");
			}
		}
		return this;
	}
}


template MWidget() {
	private import tango.text.Util : split;
	//private import xf.utils.Meta : autoOverrideFlush, resolveAutoOverride, resolveAutoOverrideCodegen;
	
	
	static if (is(typeof(this.nameForWidgetRegistry) == char[])) {
		override char[] widgetTypeName() {
			return this.nameForWidgetRegistry;
		}

		static char[] staticWidgetTypeName() {
			return this.nameForWidgetRegistry;
		}
	} else {
		override char[] widgetTypeName() {
			return split(this.classinfo.name, ".")[$-1];
		}

		static char[] staticWidgetTypeName() {
			return split(this.classinfo.name, ".")[$-1];
		}
	}
	
	
	static this() {
		static if (is(typeof(this.nameForWidgetRegistry) == char[])) {
			registerWidget!(typeof(this))(this.nameForWidgetRegistry);
		} else {
			registerWidget!(typeof(this))();
		}
	}
	

	static typeof(this) opCall(size_t id = cast(size_t)NoId) {
		mixin(widgetIdCalcSM);
		widgetId.user = id;
		auto res = gui().getWidget!(typeof(this))(null, widgetId);
		assert (res !is null, "gui.getWidget returned null");
		return res;
	}

	
	static typeof(this) opCall(char[] name, size_t id = cast(size_t)NoId) {
		mixin(widgetIdCalcSM);
		widgetId.user = id;
		auto res = gui().getWidget!(typeof(this))(name, widgetId);
		assert (res !is null, "gui.getWidget returned null");
		return res;
	}
	

	static typeof(this) opCall(WidgetId widgetId) {
		auto res = gui().getWidget!(typeof(this))(null, widgetId);
		assert (res !is null, "gui.getWidget returned null");
		return res;
	}


	// --------------------------------------------------------


	/+override typeof(this) layoutAttribs(char[] attr) {
		super.layoutAttribs(attr);
		return this;
	}+/
	
	/+override char[] layoutAttribs() {
		return super.layoutAttribs();
	}+/


	// --------------------------------------------------------


	
	//mixin resolveAutoOverride;
	mixin MWidgetCfg;
	//mixin autoOverrideFlush;
}



/**
	Base of all widget classes
*/
class Widget : IWidget {
	mixin MPropertySupport;
	mixin MWidgetCfg;

	// ------------------------------------------------------------------------------------------------------------------------

	this() {
		addHandler(&handleMinimizeLayout);
		addHandler(&handleExpandLayout);
		addHandler(&handleCalcOffsets);
		addHandler(&handleRender);
		addHandler(&handleTimeUpdate);
		shape = new Rectangle;
	}
	
	
	/**
		Name for configs. Overriden automatically by the MWidget mixin template
		
		The name for configs may be overriden by declaring a const 'char[] nameForWidgetRegistry'
		before mixing in MWidget.
	*/
	char[] widgetTypeName() {
		return "Widget";
	}
	
	
	WidgetTree wtreeNode;	
	
	// ------------------------------------------------------------------------------------------------------------------------


	protected {
		bool _widgetEnabled = true;
		bool _widgetVisible = true;
	}
	
	
	/**
		Determines whether the widget should be hidden from events, rendering, etc
	*/
	bool widgetEnabled() {
		return _widgetEnabled;
	}
	
	/// ditto
	typeof(this) widgetEnabled(bool b) {
		_widgetEnabled = b;
		return this;
	}
	mixin autoOverride!("widgetEnabled");
	

	/**
		Determines whether the widget should be hidden from rendering
	*/
	typeof(this) widgetVisible(bool v) {
		_widgetVisible = v;
		return this;
	}
	mixin autoOverride!("widgetVisible");
	
	/// ditto
	bool widgetVisible() {
		return _widgetVisible;
	}


	// ------------------------------------------------------------------------------------------------------------------------
	// Hierarchy

	Widget _parent;
	
	
	/**
		The direct parent of the widget or null if it's the root widget
	*/
	typeof(this) parent() {
		return _parent;
	}
	
	
	/**
		Sets the parent of this widget
	*/
	typeof(this) parent(IWidget p) {
		_parent = cast(Widget)p;
		return this;
	}
	mixin autoOverride!("parent", "IWidget");
	
	
	/**
		Convenience function. Returns true if parent !is null
	*/
	final bool hasParent() {
		return parent !is null;
	}
	
	
	/**
		Tells whether child widgets will be layered above this widget or under it.
		
		Most widgets will want to use the default version, putting children on top, yet some - e.g. fancy frames
		may want to put children below themselves.
	*/
	bool childrenGoAbove() {
		return true;
	}
	
	
	/**
		Foreachable child iterator. Will only access direct children of this widget
	*/
	int children(int delegate(ref IWidget)) {
		return 0;
	}
	
	
	/**
		Called on the widget in gui.end(); May be used to prepare widgets for events, rendering, etc
	*/
	void onGuiStructureBuilt() {
		_initialized = true;
	}
	
	
	/**
		Get a reference to a sub-widget called [name]. Accepts scoped names, e.g. "foo.bar.baz"
		
		If [name] is null, getLocalSub(null) will be returned.
	*/
	final IWidget getSub(char[] name) {
		if (name.length == 0) {
			//return this;
			return getLocalSub(null);
		} else {
			int dpos = tango.text.Util.locate(name, '.');
			if (dpos < name.length) {
				char[] a = name[0..dpos];
				char[] b = name[dpos+1..$];
				if (auto ap = getLocalSub(a)) {
					return ap.getSub(b);
				} else {
					return null;
				}
			} else {
				return getLocalSub(name);
			}
		}
	}
	
	
	/**
		Get a direct sub widget of this widget. Doesn't accept scoped names.
		
		A null name or "this" yields the default sub widget - 'return this;' for most widgets.
	*/
	protected IWidget getLocalSub(char[] name) {
		if (name is null || name == "this") {
			return this;
		} else if (auto namep = name in subWidgets) {
			return namep.getSub(null);
		} else {
			return null;
		}
	}
	
	
	/**
		Add a named sub-widget
		
		Note: removeTreeChildren will call removeChildren on all sub-widgets
	*/
	void addSub(IWidget w, char[] name) {
		assert (name.length > 0, "addSub : name.length == 0");
		subWidgets[name] = w;
	}
	
	
	/**
		Remove children of this widget and its descendants
	*/
	typeof(this) removeChildren() {
		removeTreeChildren();
		return this;
	}
	mixin autoOverride!("removeChildren");
	

	/**
		Remove a child from this widget
	*/
	typeof(this) removeChild(IWidget _w) {
		assert (false);
		return this;
	}
	mixin autoOverride!("removeChild");

	
	/**
		Remove chidren from this widget's descendants
	*/
	typeof(this) removeTreeChildren() {
		foreach (sub; subWidgets) {
			sub.removeChildren();
		}
		return this;
	}
	mixin autoOverride!("removeTreeChildren");
	
	
	/**
		Add a child widget to this widget
	*/
	typeof(this) addChild(IWidget _w) {
		assert (false, "can't add a child to " ~ this.classinfo.name);
		return this;
	}
	mixin autoOverride!("addChild");
	
	
	/**
		Returns true if this widget directly contains the given widget. False otherwise.
	*/
	bool containsChild(IWidget w) {
		foreach (c; &this.children) {
			if (c is w) return true;
		}
		
		return false;
	}
	
	
	/**
		Returns a textual representation of this widget and its descendants
	*/
	char[] toString() {
		return _toString("");
	}
	
	
	protected char[] _toString(char[] indent) {
		char[] res = indent ~ this.classinfo.name ~ " o" ~ to!(char[])(parentOffset) ~ " s" ~ to!(char[])(size);
		foreach (ref ch; &children) {
			auto c = cast(Widget)ch;
			res ~= "\n" ~ c._toString(indent ~ "  ");
		}
		return res;
	}
	
	
	/**
		Open a child slot with the provided name. The default slot is opened if no name is given.
		
		Note: remember to call gui.close()
	*/
	typeof(this) open(char[] name = null) {
		gui.open(wtreeNode, name);
		return this;
	}
	mixin autoOverride!("open");
	
	
	/**
		Opens the default child slot, calls the given delegate and closes the child slot by calling gui.close()
	*/
	Widget opIndex(void delegate() dg) {
		this.open();
		scope (exit) gui.close();
		dg();
		return this;
	}
	
	
	/**
		Gives access to a child slot without touching the gui context. Useful for some retained mode operations
	*/
	OpenWidgetProxy _open(char[] name = null) {
		return OpenWidgetProxy(getSub(name));
	}
	
	
	protected {
		IWidget[char[]]	subWidgets;
	}
	
	// ------------------------------------------------------------------------------------------------------------------------
	// Size and shape
	
	Shape	_shape;
	
	vec2		_size				= vec2.zero;
	//vec2		prevSize		= vec2.zero;
	vec2		_userSize		= vec2.zero;
	
	vec2		_parentOffset	= vec2.zero;
	vec2		_globalOffset		= vec2.zero;
	//vec2		prevGlobalOffset	= vec2.zero;
	
	
	/**
		Returns the rectangle that this widget and its descendants should be clipped to; Rect.init if no clipping should be done
	*/
	Rect		clipRect() {
		return Rect.init;
	}


	/**
		Overrides the widget's shape
	*/
	typeof(this) shape(Shape s) {
		_shape = s;
		return this;
	}
	mixin autoOverride!("shape");
	
	
	/**
		Returns the widget's shape
	*/
	Shape shape() {
		return _shape;
	}
	
	
	/**
		Set the widget's size to be used in the subsequent frame. Should only be used in layouts and widgets
		that explicitly lay out their children
	*/
	typeof(this) overrideSizeForFrame(vec2 s) {
		bool change = s != this._size;
		_size = s;
		if (change) {
			onSizeChanged();
		}
		return this;
	}
	mixin autoOverride!("overrideSizeForFrame");


	/**
		Returns the current size of the widget
	*/
	vec2		size() {
		return _size;
	}
	
	
	/**
		Sets the user-size of the widget. The widget may not shrink below it, but may expand beyond it.
	*/
	typeof(this) userSize(vec2 s) {
		_userSize = s;
		return this;
	}
	mixin autoOverride!("userSize");
	
	
	/**
		Returns the currently set user-size
	*/
	vec2 userSize() {
		return _userSize;
	}
	
	
	/**
		The offset of this widget from its parent
	*/
	typeof(this) parentOffset(vec2 o) {
		_parentOffset = o;
		return this;
	}
	mixin autoOverride!("parentOffset");
	
	/// ditto
	vec2 parentOffset() {
		return _parentOffset;
	}


	/**
		The offset of this widget from the origin
	*/
	typeof(this) globalOffset(vec2 o) {
		_globalOffset = o;
		return this;
	}
	mixin autoOverride!("globalOffset");
	
	/// ditto
	vec2 globalOffset() {
		return _globalOffset;
	}
	
	
	protected void onSizeChanged() {
	}
	
	
	/**
		Returns the minimal size that this widget may have to operate correctly.
		
		Meant to be overriden by sub widgets. E.g. a Label will return the size of the text to be rendered
	*/
	vec2		minSize() {
		return vec2.zero;
	}
	
	
	/**
		Returns the size this widget will request from layout mechanisms. Should consult userSize and minSize
	*/
	vec2		desiredSize() {
		vec2 m = minSize;
		vec2 u = userSize;
		return vec2(u.x < m.x ? m.x : u.x, u.y < m.y ? m.y : u.y);
	}
	
	
	/**
		Tells whether this widget contains a point specified in global coordinates
	*/
	bool containsGlobal(vec2 pt) {
		if (shape is null) {
			return Rect(globalOffset, globalOffset + size).contains(pt);
		} else {
			return shape.contains(size, pt - globalOffset);
		}
	}
	
	// ------------------------------------------------------------------------------------------------------------------------
	// Layout

	protected {
		ILayout	_layout;				// for laying out children
		char[]	_layoutAttribs;
	}
	
	
	/**
		The layout this widget uses for managing its children
	*/
	typeof(this) layout(ILayout l) {
		_layout = l;
		return this;
	}
	mixin autoOverride!("layout");

	/// ditto
	ILayout	layout() {
		return _layout;
	}
	
	
	/**
		Layout-specific attributes to be parsed by the concrete widget layout. Same as in configs
	*/
	typeof(this) layoutAttribs(char[] attr) {
		customLayoutAttribs = null;
		_layoutAttribs = attr;
		return this;
	}
	mixin autoOverride!("layoutAttribs");
	
	/// ditto
	char[] layoutAttribs() {
		return _layoutAttribs;
	}
	
	
	/**
		An object reference which may be used by the layout to store parsed attributes, etc
	*/
	Object	customLayoutAttribs;		// for the parent's layout


	/**
		
	*/
	EventHandling handleMinimizeLayout(MinimizeLayoutEvent e) {
		if (e.bubbling && layout !is null) {
			layout.minimize(this);
		}
		return EventHandling.Continue;
	}


	/**
	
	*/
	EventHandling handleExpandLayout(ExpandLayoutEvent e) {
		if (e.sinking && layout !is null) {
			layout.expand(this);
		}
		return EventHandling.Continue;
	}
	
	
	/**
	
	*/
	EventHandling handleCalcOffsets(CalcOffsetsEvent e) {
		if (e.sinking) {
			if (parent !is null) {
				this.globalOffset = parent.globalOffset + this.parentOffset;
			} else {
				this.globalOffset = vec2.zero;
			}
		}
		return EventHandling.Continue;
	}


	// ------------------------------------------------------------------------------------------------------------------------
	// Rendering


	/**
	
	*/
	EventHandling handleRender(RenderEvent e) {
		if (!widgetVisible) {
			return EventHandling.Stop;
		}		
		
		assert (e.renderer !is null);
		auto r = e.renderer;
		
		void doRender() {
			r.applyStyle(this.style);
			r.setOffset(this.globalOffset);
			
			if (!r.special(this)) {
				this.render(r);
			}
		}
		
		if (e.sinking) {
			r.pushClipRect();
			r.clip(this.clipRect);
		}
		
		if (!r.fullyClipped(globalOffset, size)) {
			if (this.childrenGoAbove) {
				if (e.sinking) {
					doRender();
				}
			} else {
				if (e.bubbling) {
					doRender();
				}
			}
		} else {
			/+if (e.bubbling) {
				r.popClipRect();
			}
			
			return EventHandling.Stop;+/
		}

		if (e.bubbling) {
			r.popClipRect();
		}

		return EventHandling.Continue;
	}
	
	
	/**
		Does the actual rendering of this widget using the GuiRenderer given as a parameter
	*/
	protected void render(GuiRenderer r) {
		if (this.shape !is null) {
			r.flushStyleSettings();
			r.shape(this.shape, this.size);
		}
	}
	
	
	// ------------------------------------------------------------------------------------------------------------------------
	// Events

	protected {
		EventHandling delegate(Event)[][ClassInfo]	eventHandlers;
	}
	

	/**
		Add an event handler delegate. It must return the EventHandling enum. The parameter should be
		an Event subclass.
	*/
	typeof(this) addHandler(T)(T h) {
		alias ParameterTupleOf!(T)[0] EventT;
		//Trace.formatln(`Registering an event handler for {}`, EventT.classinfo.name);
		
		// do not explicitly cast the return type, so we get an error if it's invalid in the delegate declaration
		eventHandlers[EventT.classinfo] ~= cast(ReturnTypeOf!(T) delegate(Event))h;
		return this;
	}


	/**
		Call handlers for the event and return EventHandling.Stop if any of them returned it.
		EventHandling.Continue is returned otherwise
	*/
	EventHandling handleEvent(Event e) {
		for (auto ci = e.classinfo; ci !is Object.classinfo; ci = ci.base) {
			auto handlers = ci in eventHandlers;
			if (handlers !is null) {
				bool stop = false;
				foreach (h; *handlers) {
					stop |= EventHandling.Stop == h(e);
				}
				return stop ? EventHandling.Stop : EventHandling.Continue;
				//return (*handler)(e);
			}
		}
		return EventHandling.Continue;
	}
	
	
	/**
		Push the event down the widget tree defined by this widget and its descendants. Call handleEvent in the
		sinking & bubbling fashion.
	*/
	EventHandling treeHandleEvent(Event e) {
		e.sinking = true;
		if (EventHandling.Stop == handleEvent(e)) {
			return EventHandling.Stop;
		}

		bool done = false;
		foreach (ch; &this.children) {
			e.sinking = true;
			done |= (ch.treeHandleEvent(e) == EventHandling.Stop);
		}
		
		e.bubbling = true;
		return ((handleEvent(e) == EventHandling.Stop) || done)
					? EventHandling.Stop
					: EventHandling.Continue;
	}
	
	
	/**
		Returns true if the widget wants to block the event from going to its children
	*/
	bool blockEventProcessing(Event e) {
		return false;
	}
	

	// ------------------------------------------------------------------------------------------------------------------------
	// Style
	
	protected void onStyleEnabled(char[] name) {
		foreach (subname, sub; subWidgets) {
			sub.enableStyle(name);
		}
	}
	

	protected void onStyleDisabled(char[] name) {
		foreach (subname, sub; subWidgets) {
			sub.disableStyle(name);
		}
	}
	
	
	mixin MStyleSupport;


	/**
	
	*/
	EventHandling handleTimeUpdate(TimeUpdateEvent e) {
		if (e.bubbling) {
			updateStyle(e.delta);
		}
		return EventHandling.Continue;
	}

	// ------------------------------------------------------------------------------------------------------------------------
	
	/**
		Tells whether this widget has existed for at least one gui.begin .. gui.end pair
	*/
	bool initialized() {
		return _initialized;
	}

	// ------------------------------------------------------------------------------------------------------------------------


	/**
		Finds a subwidget named [name] and sets the reference to it, removing it from the subWidgets set
	*/
	void getAndRemoveSub(T)(char[] name, T* res) {
		assert (res !is null);
		*res = cast(T)subWidgets[name];
		assert (*res !is null);
		subWidgets.remove(name);
	}
	
	private {
		bool _initialized = false;
	}


	// ------------------------------------------------------------------------------------------------------------------------
	// Focus
	
	/**
		Takes keyboard focus away from other widgets and gives it to this widget
	*/
	typeof(this) grabKeyboardFocus() {
		gui.giveKeyboardFocus(this);
		return this;
	}
	
	
	//mixin autoOverrideFlush;
}


class Dummy : Widget {
	mixin MWidget;
}
