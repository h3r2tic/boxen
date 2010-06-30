module xf.nucleus.kdef.ParamUtils;

private {
	import xf.nucleus.Param;
	import xf.nucleus.Value;
	import xf.nucleus.Log;
	import xf.omg.core.LinearAlgebra;
}



// TODO: verify that the param type matches if it has a type constraint
void setParamValue(Param* p, Value v) {
	if (v is null) {
		p.value = null;
	} else if (auto v = cast(NumberValue)v) {
		p.setValue(cast(float)v.value);
	} else if (auto v = cast(Vector2Value)v) {
		p.setValue(cast(float)v.value.x, cast(float)v.value.y);
	} else if (auto v = cast(Vector3Value)v) {
		p.setValue(cast(float)v.value.x, cast(float)v.value.y, cast(float)v.value.z);
	} else if (auto v = cast(Vector4Value)v) {
		p.setValue(cast(float)v.value.x, cast(float)v.value.y, cast(float)v.value.z, cast(float)v.value.w);
	} else if (auto v = cast(StringValue)v) {
		p.setValue(v.value);
	} else {
		nucleusError("{} (={}) is not a valid default value for a parameter.", v.classinfo.name, v);
	}
}
