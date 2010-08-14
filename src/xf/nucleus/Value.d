module xf.nucleus.Value;

private {
	import xf.Common;
	import xf.omg.core.LinearAlgebra;
	
	import tango.core.Variant;
	import Float = tango.text.convert.Float;

	import xf.nucleus.Log;
}



abstract class Value {
	Variant toVariant() {
		assert (false, this.classinfo.name);
	}


	abstract bool opEquals(Value other);
	
	
	T as(T)() {
		auto ret = cast(T)this;
		if (ret) {
			return ret;
		} else {
			nucleusError("This value is not a {}, it's a {} = {}", T.stringof, this.classinfo.name, this.toString);
			assert (false);	// shtupid dmd
		}
	}
}


struct VarDef {
	cstring	name;
	Value	value;


	bool opEquals(ref VarDef other) {
		return name == other.name && equal(value, other.value);
	}
}


final class NumberValue : Value {
	double value;
	
	this (double val) {
		this.value = val;
	}

	override bool opEquals(Value other) {
		if (auto o = cast(NumberValue)other) {
			return value == o.value;
		} else {
			return false;
		}
	}
	
	override cstring toString() {
		return Float.toString(value);
	}

	override Variant toVariant() {
		return Variant(value);
	}
}


class BooleanValue : Value {
	bool value;
	
	this (cstring val) {
		switch (val) {
			case "true": {
				this.value = true;
			} break;

			case "false": {
				this.value = false;
			} break;
			
			default: assert (false, val);
		}
	}
	
	override bool opEquals(Value other) {
		if (auto o = cast(BooleanValue)other) {
			return value == o.value;
		} else {
			return false;
		}
	}

	override cstring toString() {
		return value ? "true" : "false";
	}

	override Variant toVariant() {
		return Variant(value);
	}
}


class Vector2Value : Value {
	vec2d value;
	
	this (double x, double y) {
		this.value = vec2d(x, y);
	}

	override bool opEquals(Value other) {
		if (auto o = cast(Vector2Value)other) {
			return value == o.value;
		} else {
			return false;
		}
	}

	override cstring toString() {
		return value.toString;
	}

	override Variant toVariant() {
		return Variant(value);
	}
}


class Vector3Value : Value {
	vec3d value;
	
	this (double x, double y, double z) {
		this.value = vec3d(x, y, z);
	}

	override bool opEquals(Value other) {
		if (auto o = cast(Vector3Value)other) {
			return value == o.value;
		} else {
			return false;
		}
	}

	override cstring toString() {
		return value.toString;
	}

	override Variant toVariant() {
		return Variant(value);
	}
}


class Vector4Value : Value {
	vec4d value;
	
	this (double x, double y, double z, double w) {
		this.value = vec4d(x, y, z, w);
	}

	override bool opEquals(Value other) {
		if (auto o = cast(Vector4Value)other) {
			return value == o.value;
		} else {
			return false;
		}
	}

	override cstring toString() {
		return value.toString;
	}

	override Variant toVariant() {
		return Variant(value);
	}
}


class StringValue : Value {
	cstring value;
	
	this (cstring val) {
		this.value = val;
	}

	override bool opEquals(Value other) {
		if (auto o = cast(StringValue)other) {
			return value == o.value;
		} else {
			return false;
		}
	}

	override cstring toString() {
		return '"' ~ value ~ '"';
	}

	override Variant toVariant() {
		return Variant(value);
	}
}


class IdentifierValue : Value {
	cstring value;
	
	this (cstring val) {
		this.value = val;
	}

	override bool opEquals(Value other) {
		if (auto o = cast(IdentifierValue)other) {
			return value == o.value;
		} else {
			return false;
		}
	}

	override cstring toString() {
		return value;
	}

	override Variant toVariant() {
		return Variant(value);
	}
}
