module xf.hybrid.WidgetProp;

private {
	import xf.hybrid.model.Core;
	import xf.hybrid.WidgetConfig;
	import xf.hybrid.Property : Property;
	import xf.hybrid.Style;
	import xf.hybrid.Shape;
	import xf.omg.core.LinearAlgebra : vec2;
	import tango.util.Convert : to;
	import tango.text.Util;
	import tango.util.log.Trace;
}


private {
	bool tryCallProp_(T, PT)(T t, Object obj, Property* wprop) {
		if (wprop.type is typeid(PT)) {
			auto getter = cast(void delegate(PT) function(Object, void delegate()))wprop.setterAccess;
			assert (getter !is null, "tryCallProp_: getter is null");
			
			auto dg = getter(obj, null);
			assert (dg !is null, "tryCallProp_: dg is null");
			
			//Trace.formatln("tryCallProp_ converting. Property type: {}, argument type: {}", wprop.type, typeid(PT));
			dg(to!(PT)(t));
			return true;
		} else {
			//Trace.formatln("tryCallProp_ failed: type mismatch. Property type: {}, argument type: {}", wprop.type, typeid(PT));
			return false;
		}
	}


	char[] tryCallPropCodegen(char[][] types) {
		char[] res;
		foreach (t; types) {
			res ~= "static if (is(typeof(tryCallProp_!(T, " ~ t ~ ")(t, obj, wprop)))) { if (tryCallProp_!(T, " ~ t ~ ")(t, obj, wprop)) return true; }"\n;
		}
		return res;
	}


	bool tryCallProp(T)(T t, Object obj, Property* wprop) {
		assert (obj !is null);
		mixin (tryCallPropCodegen([
			`char[]`, `wchar[]`, `dchar[]`, `int`, `uint`,
			`long`, `ulong`, `short`, `ushort`, `float`, `double`,
			`byte`, `ubyte`, `bool`,
			`vec2`
		]));
		return false;
	}
}


///
bool handleWidgetPropAssign(IWidget w, IWidget wc, PropAssign prop) {
	{
		//auto wc = w.getSub(null);
		if (wc is null) {
			wc = w;
		}
		
		auto name = prop.name;
		auto value = prop.value;
		
		{
			char[] styleName = name.chopl("style.");
			if (styleName.length != name.length) {
				assert (value.type == Value.Type.Block);
				//w.addRawStyle(styleName, value.Block);
				wc.registerStyle(styleName, parseStyle(value.Block));
				if ("normal" == styleName) {
					wc.enableStyle(styleName);
				}
				return true;
			}
		}
		
		switch (name) {
			case "size": {
				w.userSize = parseVec2(value);
				return true;
			} break;

			case "layout": {
				switch (value.type) {
					case Value.Type.String: {
						wc.layout = createLayout(value.String.dup);
					} return true;
					
					case Value.Type.Complex: {
						assert (Value.Type.String == value.Complex[0].type);
						assert (Value.Type.Block == value.Complex[1].type);
						wc.layout = createLayout(value.Complex[0].String.dup);
						wc.layout.configure(value.Complex[1].Block);
					} return true;
					
					case Value.Type.Block: {
						assert (wc.layout !is null);
						wc.layout.configure(value.Block);
					} return true;
					
					default: {
						assert (false, "Not supported yet");
					} return false;
				}
			} break;
			
			case "shape": {
				assert (Value.Type.String == value.type);
				switch (value.String) {
					case "Rectangle": {
						wc.shape = new Rectangle;
					} return true;
					
					default: assert (false, value.String);
				}
			}
			
			default: break;
		}
	}


	Property*	wprop;
	Object		propObj;
	if (!w.findProperty(prop.name, &wprop, &propObj)) {
		Trace.formatln("no prop '" ~ prop.name ~ "'");
		return false;
		//throw new Exception("handleWidgetPropAssign: prop not found: '" ~ prop.name ~ "'");
	}
	if (wprop.readOnly) {
		throw new Exception("handleWidgetPropAssign: prop : '" ~ prop.name ~ "' is read only");
	}
	
	auto val = prop.value;
	switch (val.type) {
		case Value.Type.String: {
			return tryCallProp(val.String.dup, propObj, wprop);
		}

		case Value.Type.Int: {
			return tryCallProp(val.Int, propObj, wprop);
		}

		case Value.Type.Float: {
			return tryCallProp(val.Float, propObj, wprop);
		}
		
		case Value.Type.Bool: {
			return tryCallProp(val.Bool, propObj, wprop);
		}
		
		case Value.Type.Complex: {
			if (2 == val.Complex.length) {
				return tryCallProp(parseVec2(val), propObj, wprop);
			} else {
				goto default;
			}
		}

		default: assert (false, prop.name);
	}
}
