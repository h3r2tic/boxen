module xf.hybrid.CustomWidget;

private {
	import xf.hybrid.Common;
	import xf.hybrid.WidgetFactory;
	import xf.hybrid.WidgetConfig;
	import xf.hybrid.WidgetProp;
	import xf.hybrid.widgets.Group;
	
	import tango.util.log.Trace;
}



/**
	A widget composed of multiple other widgets defined in configs
*/
interface ICustomWidget : IWidget {
	/**
		Directly opens this widget, circumventing any getLocalSub overrides
	*/
	OpenWidgetProxy custom_open();
	
	
	/**
		Adds a widget to the sub-widget list; That list is separate from Widget's subWidgets list and is not
		affected by removeSub, etc
	*/
	void custom_add(IWidget w);
	
	
	/**
		Allows for widget templates to use other widget templates in configs. For instance,
		InputSpinner's config may be shared between all concrete instances, such as FloatInputSpinner,
		IntInputSpinner, etc; its config may use Spinner, which is a widget template on its own, but
		InputSpinner has to be able to map "Spinner" to "FloatSpinner", "IntSpinner", etc through the
		getTypeForAlias function.
		
		Note: getTypeForAlias will be called for all widget types used in a given custom widget, thus it
		must return the parameter unchanged if it's not a widget template or other custom name alias.
		
		Example:
---
override char[] getTypeForAlias(char[] name) {
	if ("Spinner" == name) {
		return toUpper(T.stringof[0]) ~ T.stringof[1..$] ~ "Spinner";
	}
	return super.getTypeForAlias(name);
}
---
	*/
	char[] getTypeForAlias(char[]);
}



/**
	Provides an implementation of ICustomWidget for any widget class.
	Can be used as a base class instead of e.g. Widget or Group
*/
class CustomWidgetT(Base) : Base, ICustomWidget {
	private import xf.hybrid.model.Core : IWidget, OpenWidgetProxy;
	
	
	char[] getTypeForAlias(char[] name) {
		return name;
	}


	override typeof(this) removeChildren() {
		removeTreeChildren();
		return this;
	}
	
	
	protected char[] configCustomWidgetName() {
		return this.widgetTypeName;
	}


	override IWidget getLocalSub(char[] name) {
		if (name is null) {
			if (auto c = (`children` in subWidgets)) {
				return *c;
			} else {
				return null;
			}
		} else {
			return super.getLocalSub(name);
		}
	}


	OpenWidgetProxy custom_open() {
		return OpenWidgetProxy(this);
	}
	
	
	override protected void onStyleEnabled(char[] name) {
		foreach (sub; customSubWidgets) {
			sub.enableStyle(name);
		}
	}
	

	override protected void onStyleDisabled(char[] name) {
		foreach (sub; customSubWidgets) {
			sub.disableStyle(name);
		}
	}
	
	
	void custom_add(IWidget w) {
		customSubWidgets ~= w;
	}

	
	protected {
		IWidget[]	customSubWidgets;
	}

	
	this() {
		auto spec = gui.getWigdetTypeSpec(configCustomWidgetName);
		buildCustomWidget(this, spec);
	}
}
/// ditto
alias CustomWidgetT!(Group) CustomWidget;


private struct NameTree {
	NameTree*[char[]]	children;
	IWidget						widget;
}


void buildCustomWidget(ICustomWidget w, WidgetTypeSpec cfg) {
	assert (w !is null);
	
	NameTree ntree;
	
	//Trace.formatln("buildCustomWidget1");
	itemIteration: foreach (item; cfg.items) {
		switch (item.type) {
			case item.type.Child: {
				//Trace.formatln("child");
				buildCustomWidget(w, item.Child, w.custom_open(), &ntree);		// TODO: other slot names
				//Trace.formatln("child/");
			} break;

			case item.type.Prop: {
				//Trace.formatln("prop");

				auto name = item.Prop.name;
				auto value = item.Prop.value;
				
				switch (value.type) {
					case Value.Type.FuncCall: {
						auto c = value.FuncCall;
						//if (2 == c.args.length && Value.Type.String == c.args[0].type && Value.Type.Complex == c.args[1].type) {
							// func call
						resolveCustomWidgetFunction(w, &ntree, name, c.name, c.args);
						/+} else {		// not a func call
						}+/
					} continue itemIteration;
					
					default: break;
				}

				if (xf.hybrid.WidgetProp.handleWidgetPropAssign(w, w, item.Prop)) {
					continue itemIteration;
				}
				
				//Trace.formatln("prop/");
			} break;

			default: assert (false, "Unhandled prop: '" ~ item.Prop.name ~ "'");
		}
	}
	//Trace.formatln("buildCustomWidget1/");
}


private NameTree* findParent(NameTree* ntree, char[] name, ref char[] lastName) {
	int dpos = tango.text.Util.locate(name, '.');
	if (dpos < name.length) {
		char[] a = name[0..dpos];
		char[] b = name[dpos+1..$];
		//Trace.formatln("ntree accessing '{}.{}', got {}", a, b, ntree.children.keys);
		assert (a in ntree.children, a);
		return findParent(ntree.children[a], b, lastName);
	} else {
		//Trace.formatln("ntree accessing '{}', got {}", name, ntree.children.keys);
		lastName = name;
		return ntree;
	}
}


private void resolveCustomWidgetFunction(ICustomWidget w, NameTree* ntree, char[] vname, char[] fname, Value[] params) {
	switch (fname) {
		case "sub": {
			assert (1 == params.length && params[0].type == Value.Type.String);
			char[] remoteName = params[0].String;
			
			//Trace.formatln("binding remote widget '{}' to local subwidget '{}'", remoteName, vname);
			char[] lastName;
			auto node = findParent(ntree, remoteName, lastName);
			w.addSub(node.children[lastName].widget, vname);
		} break;
		
		case "prop": {
			assert (1 == params.length && params[0].type == Value.Type.String);
			char[] remotePropName = params[0].String;
			
			//Trace.formatln("binding remote prop '{}' to local prop '{}'", remotePropName, vname);
			char[] lastName;
			auto node = findParent(ntree, remotePropName, lastName);
			w.bindPropertyToRemote(vname, node.widget, lastName);
		} break;
		
		default: {
			return;
			//assert (false, "Unknown function: '" ~ fname ~ "'");
		}
	}
}


private void buildCustomWidget(ICustomWidget root, WidgetSpec wspec, OpenWidgetProxy parent, NameTree* ntree) {
	//Trace.formatln("buildCustomWidget2");
	auto child = cast(Widget)createWidget(root.getTypeForAlias(wspec.type));
	assert (child !is null, "root is null");
	
	root.custom_add(child);
	parent.addChild(child);
	
	NameTree* nnode;

	if (wspec.name) {
		nnode = new NameTree;
		nnode.widget = child;
		ntree.children[wspec.name] = nnode;
	} else {
		nnode = ntree;
	}
	
	child.layoutAttribs = wspec.layoutAttr;

	foreach (ch; wspec.children) {
		buildCustomWidget(root, ch, child._open(null), nnode);		// TODO: other slot names
	}
	
	foreach (prop; wspec.props) {
		if (!xf.hybrid.WidgetProp.handleWidgetPropAssign(child, child.getSub(null), prop)) {
			assert (false, "Unhandled prop: '" ~ prop.name ~ "' in " ~ (cast(Object)child).classinfo.name);
		}
	}

	foreach (ename, ref extra; wspec.extraParts) {
		foreach (ch; extra.children) {
			buildCustomWidget(root, ch, child._open(ename), nnode);
		}
		
		foreach (prop; extra.props) {
			auto sub = child.getSub(ename);

			if (!xf.hybrid.WidgetProp.handleWidgetPropAssign(sub, sub.getSub(null), prop)) {
				assert (false, "Unhandled prop: '" ~ prop.name ~ "'");
			}
		}
	}
	
	//Trace.formatln("buildCustomWidget2/");
}
