module xf.hybrid.widgets.TabView;

private {
	import xf.hybrid.Common;
	import xf.hybrid.CustomWidget;
	import xf.hybrid.model.Core;
	import xf.hybrid.widgets.TabButton;
	import xf.hybrid.widgets.Group;
	import tango.util.Convert : to;
	import tango.util.log.Trace;
}



private {
	struct TabViewLabelProxy2 {
		TabView tv;
		int i;
		
		void opAssign(char[] t) {
			tv._tabButtons[i].text = t;
		}
		
		char[] opCast() {
			return tv._tabButtons[i].text;
		}
	}


	struct TabViewLabelProxy {
		TabView tv;
		
		TabViewLabelProxy2 opIndex(uint i) {
			tv.assurePanePresent(i);
			return TabViewLabelProxy2(tv, i);
		}
	}


	struct TabViewButtonProxy {
		TabView tv;
		
		TabButton opIndex(uint i) {
			tv.assurePanePresent(i);
			return tv._tabButtons[i];
		}
	}
}


/**
	A container which uses a set of TabButtons to switch between multiple display panes
	
	Tab pane contents can be accessed directly as 'tab[0-9]+' sub-widgets / child slots
	
	Tab buttons can likewise be accessed as 'button[0-9]+' sub-widgets
	
	Instead of adding children to the tab panes directly, the application may simply switch on the 'activeTab'
	property which yields a number from 0 to the number of tabs managed by the TabView; Then it may simply
	add child widgets
	
	This is a consequence of the fact that the default child slot of the TabView is the currently active tab pane.
	
	Properties:
	---
	// The index of the currently selected tab
	int activeTab
	---
*/
class TabView : CustomWidget {
	/**
		Returns a proxy object for opIndexAssign - like tab button label changing / access
		
		Example:
---
tabView.label[0] = "tab0";
char[] foo = cast(char[])tabView.label[0];
---
		
		Accessing an index of a non-existent tab will create it along with all indices below it
	*/
	TabViewLabelProxy label() {
		return TabViewLabelProxy(this);
	}


	/**
		Returns a proxy object for opIndexAssign - like tab button access
		
		Example:
---
TabButton = tabView.button[0];
---
		
		Accessing an index of a non-existent tab will create it along with all indices below it
	*/
	TabViewButtonProxy button() {
		return TabViewButtonProxy(this);
	}


	protected Widget createTabWidget() {
		auto res = (new Group).layoutAttribs("hexpand vexpand hfill vfill");
		res.widgetEnabled = false;
		return res;
	}
	
	
	protected TabButton createTabButton() {
		auto res = new TabButton;
		res.addHandler(&this.handleButtonClicked);
		return res;
	}
	
	
	protected void assurePanePresent(int i) {
		if (_tabPanes.length <= i) {
			_tabPanes.length = i + 1;
			_tabButtons.length = i + 1;
		}
		
		if (_tabPanes[i] is null) {
			_tabPanes[i] = createTabWidget();
		}
		
		foreach (ref tb; _tabButtons) {
			if (tb is null) {
				tb = createTabButton();
			}
		}
	}
	

	/**
		Set the active tab index to i
	*/
	void switchTab(int i) {
		if (_activeTab == i) {
			return;
		}

		if (_tabPanes.length > _activeTab && _tabPanes[_activeTab] !is null) {
			_clientArea.getSub(null).removeChild(_tabPanes[_activeTab]);
			_tabPanes[_activeTab].widgetEnabled = false;
		}
		
		_activeTab = i;
		assurePanePresent(i);
		
		_tabPanes[_activeTab].widgetEnabled = true;
		_clientArea.getSub(null).addChild(_tabPanes[_activeTab]);
	}


	override IWidget getLocalSub(char[] name) {
		if ("children" == name || name.length == 0) {
			return getPaneSub(_activeTab);
		}
		
		if (name.length > 3 && name[0..3] == "tab") {
			bool digitsOnly = true;
			foreach (c; name[3..$]) {
				if (c < '0' || c > '9') {
					digitsOnly = false;
					break;
				}
			}
			
			if (digitsOnly) {
				return getPaneSub(to!(int)(name[3..$]));
			}
		}

		if (name.length > 6 && name[0..6] == "button") {
			bool digitsOnly = true;
			foreach (c; name[6..$]) {
				if (c < '0' || c > '9') {
					digitsOnly = false;
					break;
				}
			}
			
			if (digitsOnly) {
				int i = to!(int)(name[6..$]);
				assurePanePresent(i);
				return _tabButtons[i];
			}
		}
		
		return super.getLocalSub(name);
	}
	
	
	protected Widget getPaneSub(int i) {
		if (-1 == i) {
			return null;
		}
		assurePanePresent(i);
		return _tabPanes[i];
	}
	
	
	protected EventHandling handleButtonClicked(ClickEvent e) {
		foreach (i, tb; _tabButtons) {
			if (tb.clicked) {
				switchTab(i);
				break;
			}
		}
		return EventHandling.Continue;
	}
	

	override void onGuiStructureBuilt() {
		foreach (i, tb; _tabButtons) {
			if (0 == i) {
				tb.edgeType = 0;
			} else if (i+1 == _tabButtons.length) {
				tb.edgeType = 2;
			} else {
				tb.edgeType = 1;
			}
			
			_tabList.addChild(tb);
		}
		
		foreach (i, tb; _tabButtons) {
			if (_activeTab == i) {
				tb.active = true;
				//tb.enableStyle("active");
			} else {
				tb.active = false;
				//tb.disableStyle("active");
			}
		}
	}
	
	
	protected TabButton activeTabWidget() {
		if (_activeTab < _tabButtons.length) {
			return _tabButtons[_activeTab];
		} else {
			return null;
		}
	}


	override typeof(this) removeTreeChildren() {
		super.removeTreeChildren();
		foreach (tp; _tabPanes) {
			if (tp !is null) {
				tp.removeChildren();
			}
		}
		foreach (tb; _tabButtons) {
			if (tb !is null) {
				tb.removeChildren();
			}
		}
		return this;
	}


	override EventHandling handleRender(RenderEvent e) {
		if (!widgetVisible) {
			return EventHandling.Stop;
		}
		
		if (e.sinking) {
			if (auto at = activeTabWidget()) {
				at.widgetVisible = false;
			}
		}

		super.handleRender(e);

		if (e.bubbling) {
			if (auto at = activeTabWidget()) {
				at.widgetVisible = true;
				e.sinking = true;
				at.treeHandleEvent(e);
				e.sinking = false;
			}
		}
		
		return EventHandling.Continue;
	}
	
	
	int activeTab() {
		return _activeTab;
	}
	
	
	typeof(this) activeTab(int i) {
		switchTab(i);
		return this;
	}
	
	
	int numTabs() {
		return _tabPanes.length;
	}
	

	this() {
		_tabList = cast(Widget)getLocalSub("tabList");
		assert (_tabList !is null);
		
		getAndRemoveSub("clientArea", &_clientArea);
		assert (_clientArea !is null);
		switchTab(0);
	}
	
	
	protected {
		Widget			_tabList;
		Widget			_clientArea;
		TabButton[]	_tabButtons;
		Widget[]		_tabPanes;
		int				_numTabs;
		int				_activeTab = -1;
	}
	
	
	mixin (defineProperties("int activeTab"));
	mixin MWidget;
}
