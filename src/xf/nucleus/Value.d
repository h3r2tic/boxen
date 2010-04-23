module xf.nucleus.Value;

private {
	import xf.Common;
	import xf.omg.core.LinearAlgebra;
	
	import tango.core.Variant;
	import Float = tango.text.convert.Float;
}



abstract class Value {
	Variant toVariant() {
		assert (false, this.classinfo.name);
	}
	
	
	T as(T)() {
		auto ret = cast(T)this;
		if (ret) {
			return ret;
		} else {
			throw new Exception(Format("This value is not a {}, it's a {} = {}", T.stringof, this.classinfo.name, this.toString));
		}
	}
}


struct VarDef {
	cstring	name;
	Value	value;
}


class NumberValue : Value {
	double value;
	
	this (double val) {
		this.value = val;
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
		this.value = val.dup;
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
		this.value = val.dup;
	}

	override cstring toString() {
		return value;
	}

	override Variant toVariant() {
		return Variant(value);
	}
}
