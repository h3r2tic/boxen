module xf.hybrid.WidgetTree;

private {
	import xf.hybrid.model.Core;
	import xf.hybrid.WidgetProp;
	import xf.hybrid.WidgetFactory;
	import xf.hybrid.Misc;
	import xf.hybrid.Property : Property;
	import xf.hybrid.WidgetConfig;
	import xf.hybrid.HybridException;
	import tango.text.Util;
	import tango.util.log.Trace;
}


///
class WidgetTree {
	char[]		name;
	bool			retained;
	bool			enabled;
	char[]		slot;
	
	WidgetTree					parent;
	WidgetTree					namespace;
	WidgetTree[]					children;
	WidgetTree[char[]]		nameToChild;
	WidgetTree[WidgetId]	idToChild;
	
	WidgetSpec	wspec;
	
	
	IWidget	widget() {
		return _widget;
	}
	
	
	void widget(IWidget w) {
		if (w !is _widget && wspec !is null && w !is null) {
			foreach (p; wspec.props) {
				handleWidgetPropAssign(w, w.getSub(null), p);
			}
			foreach (ename, ref extra; wspec.extraParts) {
				auto sub = w.getSub(ename);
				foreach (p; extra.props) {
					handleWidgetPropAssign(sub, sub.getSub(null), p);
				}
			}
			w.layoutAttribs = wspec.layoutAttr;
		}
		
		_widget = w;
	}	


	protected IWidget _widget;

	
	this (char[] name, WidgetTree parent) {
		assert (name is null || name.length > 0);

		this.parent = parent;
		this.name = name;
		
		if (name !is null || parent is null) {
			namespace = this;
		} else {
			namespace = parent.namespace;
		}
	}
	

	IWidget locateWidget(char[] name) {
		int dpos = tango.text.Util.locate(name, '.');
		if (dpos < name.length) {
			char[] a = name[0..dpos];
			char[] b = name[dpos+1..$];
			
			if (auto f = a in nameToChild) {
				return f.locateWidget(b);
			}
		} else {
			if (auto f = name in nameToChild) {
				return f.widget;
			}
		}
		
		return _widget.getSub(name);
	}
	

	WidgetTree locate(char[] name) {
		int dpos = tango.text.Util.locate(name, '.');
		if (dpos < name.length) {
			char[] a = name[0..dpos];
			char[] b = name[dpos+1..$];
			//Trace.formatln("accessing '{}.{}', got {}", a, b, nameToChild.keys);
			assert (a in nameToChild, a);
			return nameToChild[a].locate(b);
		} else {
			//Trace.formatln("accessing '{}', got {}", name, nameToChild.keys);
			if (!(name in nameToChild)) {
				hybridThrow("The name '{}' was not found in the '{}' namespace", name, this.name);
			}
			return nameToChild[name];
		}
	}


	WidgetTree locate(WidgetId id) {
		auto n = id in idToChild;
		if (n !is null) {
			return *n;
		} else {
			auto t = new WidgetTree(null, this);
			idToChild[id] = t;
			children ~= t;
			return t;
		}
	}
	
	
	WidgetTree root() {
		WidgetTree res = this, p = this.parent;
		while (p !is null) {
			res = p;
			p = p.parent;
		}
		return res;
	}
	
	
	void addChild(WidgetTree t) {
		assert (t !is null);
		children ~= t;

		if (t.name !is null) {
			assert (t.name.length > 0);
			
			char[] nameinScope = t.name;
			auto nscope = this.namespace;
			if (t.name[0] == '.') {
				assert (t.name.length > 1);
				
				int dpos = tango.text.Util.locate(t.name[1..$], '.');
				if (dpos != t.name.length - 1) {
					nscope = this.root.locate(t.name[0..$]).namespace;
					nameinScope = nameinScope[nscope.name.length+2..$];
				} else {
					nscope = this.root;
					nameinScope = nameinScope[1..$];
				}
			}
			
			assert (nscope !is null);
			if ((nameinScope in nscope.namespace.nameToChild) !is null) {
				hybridThrow("The name '{}' already exists in the '{}' namespace", nameinScope, nscope.namespace.name);
			}
			nscope.namespace.nameToChild[nameinScope] = t;
		}
	}
	
	
	void addChild(IWidget w) {
		auto t = new WidgetTree(null, this);
		t.widget = w;
		addChild(t);
	}
	
	
	void clearTemp() {
		if (widget !is null) {
			widget.removeChildren();
		}

		if (!retained) {
			enabled = false;
		}
		
		foreach (ch; children) {
			ch.clearTemp();
		}
	}
	
	
	private char[] toString_(char[] indent) {
		if (enabled) {
			char[] result;
			
			if (widget !is null) {
				result = indent.dup;
				
				if (retained) result ~= "retained ";
				result ~= (cast(Object)widget).classinfo.name ~ " '" ~ name ~ "'";
			}

			foreach (ch; children) {
				result ~= "\n" ~ ch.toString_(indent ~ "  ");
			}
			
			return result;
		} else return null;
	}
	
	
	char[] toString() {
		return toString_("");
	}
}



///
WidgetTree buildWidgetTree(Config cfg) {
	//Trace.formatln("buildWidgetTree1");
	auto root = new WidgetTree(null, null);
	root.retained = root.enabled = true;
	foreach (wspec; cfg.widgetSpecs) {
		buildWidgetTree(wspec, root);
	}
	//Trace.formatln("buildWidgetTree1/");
	return root;
}


private void buildWidgetTree(WidgetSpec wspec, WidgetTree parent, char[] slot = null) {
	//Trace.formatln("buildWidgetTree2");
	auto root = new WidgetTree(wspec.name, parent);
	root.slot = slot;
	parent.addChild(root);

	root.wspec = wspec;
	
	if (wspec.createNew) {
		root.retained = root.enabled = true;
		root.widget = createWidget(wspec.type);
	}

	foreach (ch; wspec.children) {
		buildWidgetTree(ch, root);
	}
	
	foreach (ename, ref extra; wspec.extraParts) {
		foreach (ch; extra.children) {
			buildWidgetTree(ch, root, ename);
		}
	}
	
	//Trace.formatln("buildWidgetTree2/");
}
