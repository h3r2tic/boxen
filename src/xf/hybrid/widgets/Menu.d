module xf.hybrid.widgets.Menu;

private {
	import xf.hybrid.Common;
	import xf.hybrid.CustomWidget;
	import xf.hybrid.model.Core;
	import xf.hybrid.Misc;
	import tango.util.log.Trace;
}



class MenuOverlaySlot : Widget {
	override typeof(this) removeChild(IWidget _w) {
		gui.getOverlayWidget().removeChild(_w);
		return this;
	}

	override typeof(this) addChild(IWidget _w) {
		gui.getOverlayWidget().addChild(_w);
		auto m = cast(GenericMenu)_w;
		assert (m !is null);
		_menuItem.placeChildMenu(m);
		_child = m;
		return this;
	}
	
	protected override IWidget getLocalSub(char[] name) {
		assert (name is null, name);
		return this;
	}
	
	bool menuTreeContainsGlobal(vec2 p) {
		if (_child) {
			return _child.menuTreeContainsGlobal(p);
		} else {
			return false;
		}
	}
	
	protected {
		GenericMenuItem	_menuItem;
		GenericMenu			_child;
	}


	mixin MWidget;
}


/**
	A base class for HMenu and VMenu
	Properties:
	---
	inline bool topLevel
	---
*/
class GenericMenu : CustomWidget {
	/+protected void makeInactive() {
		foreach (ch; &this.getSub(null).children) {
			if (auto item = cast(GenericMenuItem)ch) {
				item.makeInactive();
			}
		}
	}+/


	/**
		Tells whether this menu or any of its descendants contains a point specified in global coordinates
	*/
	bool menuTreeContainsGlobal(vec2 p) {
		if (this.containsGlobal(p)) {
			return true;
		} else {
			foreach (ch; &this.getSub(null).children) {
				if (auto item = cast(GenericMenuItem)ch) {
					if (item.menuTreeContainsGlobal(p)) {
						return true;
					}
				}
			}
			
			return false;
		}
	}
	
	
	protected EventHandling handleMouseButton(MouseButtonEvent e) {
		if (MouseButton.Left == e.button && e.down && e.bubbling) {
			//Trace.formatln("Menu : mouse button 0");
			_isOpen ^= true;
			if (_isOpen) {
				installGlobalButtonHandler();
			} else {
				_contextJustClosed = false;
			}

			return EventHandling.Stop;
		} else {
			return EventHandling.Continue;
		}
	}
	

	override bool blockEventProcessing(Event e) {
		return true;
	}


	protected EventHandling handleClick(ClickEvent e) {
		if (e.bubbling && !e.handled) {
			return EventHandling.Stop;
		} else {
			return EventHandling.Continue;
		}
	}
	
	
	override void onGuiStructureBuilt() {
		super.onGuiStructureBuilt();
		
		_contextJustClosed = false;

		bool anyHover = false;
		bool anyOpen = false;
		foreach (ch; &this.getSub(null).children) {
			if (auto item = cast(GenericMenuItem)ch) {
				item.openable = this.isOpen || !this.topLevel;
				anyHover |= item._hover;
				anyOpen |= item.isOpen;
			}
		}
		
		if (anyHover) {
			foreach (ch; &this.getSub(null).children) {
				if (auto item = cast(GenericMenuItem)ch) {
					if (!item._hover) {
						item.makeInactive();
					}
				}
			}
		} 
		
		if (!anyHover && !anyOpen) {
			foreach (ch; &this.getSub(null).children) {
				if (auto item = cast(GenericMenuItem)ch) {
					item.makeInactive();
				}
			}
		}
	}
	
	
	void makeContextMenu() {
		_isOpen = true;
		installGlobalButtonHandler();
		if (_contextJustClosed) {
			Trace.formatln("closing context menu");
			_isOpen = false;
			_contextJustClosed = false;
		}
	}
	
	
	/**
		Tells whether this menu is open and its sub-menus can be selected
	*/
	bool isOpen() {
		return _isOpen;
	}
	
	
	this() {
		addHandler(&handleMouseButton);
		addHandler(&handleClick);
	}
	
	
	void close() {
		_isOpen = false;
	}
	
	
	protected bool globalButtonHandler(MouseButtonEvent e) {
		if (_isOpen && e.down && !menuTreeContainsGlobal(e.pos)) {
			_isOpen = false;
			_globalButtonHandlerInstalled = false;
			_contextJustClosed = true;
			return true;
		} else {
			return false;
		}
	}
	
	
	protected void installGlobalButtonHandler() {
		if (!_globalButtonHandlerInstalled && _isOpen) {
			_globalButtonHandlerInstalled = true;
			gui.addGlobalHandler(&this.globalButtonHandler);
			Trace.formatln("installGlobalButtonHandler");
		}
	}


	protected {
		bool	_contextJustClosed = false;
		bool	_isOpen;
		bool	_globalButtonHandlerInstalled = false;
	}
	
	mixin (defineProperties("inline bool topLevel"));
	mixin MWidget;
}



/**
	Horizontal menu
*/
class HMenu : GenericMenu {
	mixin MWidget;
}



/**
	Vertical menu
*/
class VMenu : GenericMenu {
	mixin MWidget;
}



/**
	A base class for HMenu and VMenu
	Properties:
	---
	// Tells whether this menu be opened.
	// Set by the parent Menu widget when its state changes
	inline bool openable
	
	// Tells whether this menu item is active, e.g. hovered upon by the cursor
	inline out bool active
	
	char[] text
	
	// The direction at which a sub-menu should be spawned
	// 0 -> right
	// 1 -> up
	// 2 -> left
	// 3 -> down
	inline int childDir
	
	// Tells whether this item was clicked in the previous frame
	inline out bool clicked
	---
*/
class GenericMenuItem : CustomWidget {
	bool menuTreeContainsGlobal(vec2 p) {
		if (this.containsGlobal(p)) {
			return true;
		} else {
			return _overlaySlot.menuTreeContainsGlobal(p);
		}
	}

	
	protected void makeInactive() {
		_active = false;
		disableStyle("active");
	}
	

	override void onGuiStructureBuilt() {
		this._clicked = false;
		super.onGuiStructureBuilt();
	}

	
	protected EventHandling handleMouseEnter(MouseEnterEvent e) {
		enableStyle("hover");
		enableStyle("active");
		_hover = true;
		_active = true;
		Trace.formatln("MenuItem : mouse enter");
		installGlobalButtonHandler();
		return EventHandling.Continue;
	}
	
	
	protected EventHandling handleMouseLeave(MouseLeaveEvent e) {
		disableStyle("hover");
		_hover = false;
		return EventHandling.Continue;
	}


	protected EventHandling handleClick(ClickEvent e) {
		if (e.bubbling && !e.handled) {
			//this._clicked = true;
			return EventHandling.Stop;
		}
		//return EventHandling.Stop;
		return EventHandling.Continue;
	}
	

	protected EventHandling handleMouseButton(MouseButtonEvent e) {
		if (MouseButton.Left == e.button) {
			if (!e.down && !e.handled) {
				this._clicked = true;
			}
		}
		
		return EventHandling.Continue;
	}

	
	bool isOpen() {
		return openable && _active;
	}
	
	
	void placeChildMenu(Widget ch) {
		.placeChildMenu(this, ch, childDir);
	}
	
	
	protected override IWidget getLocalSub(char[] name) {
		if (name is null) {
			return _overlaySlot;
		} else {
			return super.getLocalSub(name);
		}		
	}

	
	this() {
		_openable = true;
		addHandler(&handleMouseEnter);
		addHandler(&handleMouseLeave);
		addHandler(&handleClick);
		addHandler(&handleMouseButton);
		_overlaySlot = new MenuOverlaySlot;
		_overlaySlot._menuItem = this;
	}


	protected bool globalButtonHandler(MouseButtonEvent e) {
		if (e.down && !menuTreeContainsGlobal(e.pos)) {
			_globalButtonHandlerInstalled = false;
			makeInactive();
			return true;
		} else {
			return false;
		}
	}
	
	
	protected void installGlobalButtonHandler() {
		if (!_globalButtonHandlerInstalled && isOpen) {
			_globalButtonHandlerInstalled = true;
			gui.addGlobalHandler(&this.globalButtonHandler);
			Trace.formatln("installGlobalButtonHandler");
		}
	}
	
	
	protected {
		bool	_globalButtonHandlerInstalled = false;
	}


	override Widget opIndex(void delegate() dg) {
		if (this.isOpen) {
			this.open();
			scope (exit) gui.close();
			dg();
		}
		return this;
	}
	
	
	protected {
		bool						_hover;
		MenuOverlaySlot	_overlaySlot;
	}	


	mixin(defineProperties("inline bool openable, inline out bool active, char[] text, inline int childDir, inline out bool clicked"));
	mixin MWidget;
}


/**
	Horizontal menu item
*/
class HMenuItem : GenericMenuItem {
	mixin MWidget;
}


/**
	Vertical menu item
*/
class VMenuItem : GenericMenuItem {
	mixin MWidget;
}



void placeChildMenu(Widget parent, Widget child, int dir) {
	// make sure we have the size of the child menu
	{
		scope evt = new MinimizeLayoutEvent;
		child.treeHandleEvent(evt);
	}
	{
		scope evt = new ExpandLayoutEvent;
		child.treeHandleEvent(evt);
	}
	
	void swap(ref float a, ref float b) {
		float t = a;
		a = b;
		b = t;
	}

	float[4] xorig = void;
	float[4] yorig = void;
	
	xorig[1] = parent.globalOffset.x;
	xorig[0] = xorig[1] - child.size.x;
	xorig[3] = xorig[1] + parent.size.x;
	xorig[2] = xorig[3] - child.size.x;
	int xi1 = 1;
	if (xorig[1] > xorig[2]) {
		swap(xorig[1], xorig[2]);
		xi1 = 2;
	}
	
	yorig[1] = parent.globalOffset.y;
	yorig[0] = yorig[1] - child.size.y;
	yorig[3] = yorig[1] + parent.size.y;
	yorig[2] = yorig[3] - child.size.y;
	int yi1 = 1;
	if (yorig[1] > yorig[2]) {
		swap(yorig[1], yorig[2]);
		yi1 = 2;
	}
	
	// child origins per coordinate per direction
	int[2][4] origs = void;
	origs[0][0] = 3;
	origs[0][1] = yi1;
	origs[1][0] = xi1;
	origs[1][1] = 0;
	origs[2][0] = 0;
	origs[2][1] = yi1;
	origs[3][0] = xi1;
	origs[3][1] = 3;
	
	int xi = origs[dir][0];
	int yi = origs[dir][1];
	
	vec2 availableSize = vec2(800, 450);		// HACK
	vec2 origin = vec2(xorig[xi], yorig[yi]);

	bool parentCovered() {
		return xi >= 1 && xi <= 2 && yi >= 1 && yi <= 2;
	}
	
	while (origin.x < 0 && xi < 3) {
		do ++xi; while (parentCovered);
		origin.x = xorig[xi];
	}
	while (origin.y < 0 && yi < 3) {
		do ++yi; while (parentCovered);
		origin.y = yorig[yi];
	}
	while (origin.x + child.size.x > availableSize.x && xi > 0) {
		do --xi; while (parentCovered);
		origin.x = xorig[xi];
	}
	while (origin.y + child.size.y > availableSize.y && yi > 0) {
		do --yi; while (parentCovered);
		origin.y = yorig[yi];
	}
	
	child.parentOffset = origin;
}


/**
	Builds a horizontal menu using MenuItems generated by menuGroup and menuLeaf calls
*/
void horizontalMenu(MenuItem[] _items ...) {
	mixin(widgetIdCalcSM);		// yields 'widgetId'
	size_t menuItemIdx;
	WidgetId nextId() {
		WidgetId res = widgetId;
		res.user = menuItemIdx++;
		return res;
	}


	auto root = HMenu(nextId);
	root.topLevel = true;
	
	void skipMenuItems(MenuItem[] items, ref size_t menuItemIdx) {
		foreach (item; items) {
			nextId();			
			if (!item.leaf) {
				nextId();
				skipMenuItems(item.children, menuItemIdx);
			}
		}
	}
	
	void menuItems(MenuItem[] items, ref size_t menuItemIdx, bool horizontal) {
		foreach (item; items) {
			GenericMenuItem w;
			if (horizontal) {
				w = HMenuItem(nextId).text(item.name);
			} else {
				w = VMenuItem(nextId).text(item.name);
			}
			if (item.leaf) {
				if (w.clicked) {
					foreach (a; item.actions) {
						a();
						root.close();
					}
				}
			} else {
				if (w.isOpen) {
					w.open;
						VMenu(nextId).open;
							menuItems(item.children, menuItemIdx, false);
						gui.close;
					gui.close;
				} else {
					nextId();
					skipMenuItems(item.children, menuItemIdx);
				}
			}
		}
	}
	
	root.open;
		menuItems(_items, menuItemIdx, true);
	gui.close;
}


/**
	Builds a horizontal menu using MenuItems generated by menuGroup and menuLeaf calls
*/
GenericMenu contextMenu(MenuItem[] _items ...) {
	mixin(widgetIdCalcSM);		// yields 'widgetId'
	size_t menuItemIdx;
	WidgetId nextId() {
		WidgetId res = widgetId;
		res.user = menuItemIdx++;
		return res;
	}


	auto root = VMenu(nextId);
	root.topLevel = true;
	root.makeContextMenu;
	
	void skipMenuItems(MenuItem[] items, ref size_t menuItemIdx) {
		foreach (item; items) {
			nextId();			
			if (!item.leaf) {
				nextId();
				skipMenuItems(item.children, menuItemIdx);
			}
		}
	}
	
	void menuItems(MenuItem[] items, ref size_t menuItemIdx, bool horizontal) {
		foreach (item; items) {
			GenericMenuItem w;
			if (horizontal) {
				w = HMenuItem(nextId).text(item.name);
			} else {
				w = VMenuItem(nextId).text(item.name);
			}
			if (item.leaf) {
				if (w.clicked) {
					foreach (a; item.actions) {
						a();
						root.close();
					}
				}
			} else {
				if (w.isOpen) {
					w.open;
						VMenu(nextId).open;
							menuItems(item.children, menuItemIdx, false);
						gui.close;
					gui.close;
				} else {
					nextId();
					skipMenuItems(item.children, menuItemIdx);
				}
			}
		}
	}
	
	root.open;
		menuItems(_items, menuItemIdx, false);
	gui.close;
	
	return root;
}



struct MenuItem {
	bool leaf;
	char[] name;
	void delegate()[] actions;
	
	// dmd bug workaround
	MenuItem* _children;
	uint _numChildren;
	// ----
	
	MenuItem[] children() {
		return _children[0.._numChildren];
	}
}


/**
	Create a menu group (HMenu or VMenu) containing more MenuItems
*/
MenuItem menuGroup(char[] name, MenuItem[] items ...) {
	return MenuItem(false, name, null, items.ptr, items.length);
}


/**
	Create a menu leaf (HMenuItem or VMenuItem) which performs the actions upon being activated
*/
MenuItem menuLeaf(char[] name, void delegate()[] actions ...) {
	return MenuItem(true, name, actions, null, 0);
}
