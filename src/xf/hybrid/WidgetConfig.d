module xf.hybrid.WidgetConfig;

private {
	//import hybrid.Style;
	import xf.utils.Union;
	import xf.hybrid.Math;
	
	alias char[] string;
}



///
mixin(makeTypedUnion(
	"Value",
	["string", "int", "float", "bool", "PropAssign[]", "ComplexValue", "FuncCallValue"],
	["String", "Int", "Float", "Bool", "Block", "Complex", "FuncCall"]
));


///
class ComplexValue {
	Value[]	items;
	
	int length() {
		return items.length;
	}
	
	Value opIndex(int i) {
		return items[i];
	}
}


///
struct FuncCallValue {
	char[]	name;
	Value[]	args;
}


///
struct PropAssign {
	string	name;
	Value	value;
}


///
class WidgetSpec {
	char[]	name;
	char[]	type;
	bool		createNew;
	char[]	layoutAttr;
	
	PropAssign[]	props;
	WidgetSpec[]	children;
	
	struct ExtraPart {
		PropAssign[]	props;
		WidgetSpec[]	children;
	}
	
	ExtraPart[char[]] extraParts;
}


///
class WidgetTypeSpec {
	mixin(makeTypedUnion("Item", ["PropAssign", "WidgetSpec"], ["Prop", "Child"]));

	char[]	name;
	Item[]	items;
	
	Item[][char[]] extraParts;
}


///
class Config {
	WidgetSpec[]			widgetSpecs;
	WidgetTypeSpec[]	widgetTypeSpecs;
	char[][]					imports;
}


///
vec2 parseVec2(Value val) {
	assert (Value.Type.Complex == val.type);
	assert (2 == val.Complex.length);
	
	vec2 res = void;
	foreach (i, ref c; res.cell) {
		auto v = val.Complex[i];
		switch (v.type) {
			case Value.Type.Int: {
				c = v.Int;
			} break;

			case Value.Type.Float: {
				c = v.Float;
			} break;
			
			default: assert (false);
		}
	}
	return res;
}


///
float parseFloat(Value val) {
	switch (val.type) {
		case Value.Type.Int: return val.Int;
		case Value.Type.Float: return val.Float;
		default: assert (false);
	}
}
