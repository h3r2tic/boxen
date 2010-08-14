module xf.nucled.StandardDataProviders;

private {
	import
		xf.Common;
	import
		xf.nucleus.Value,
		xf.nucleus.Param,
		xf.nucleus.kdef.Common;
	import
		xf.nucled.DataProvider,
		xf.nucled.Log;
	import
		xf.hybrid.Hybrid;
	import
		xf.omg.core.LinearAlgebra,
		xf.omg.color.HSV;
	import
		tango.core.Variant,
		tango.text.convert.Format;
}


// TODO


class ColorTextureProvider : DataProvider {
	mixin MDataProvider!("Texture", "Color");
	
	protected override void _doGUI() {
		Label().text = "ColorTextureProvider";
	}
	
	override Variant getValue() {
		return Variant(null);
	}
	
	override void configure(VarDef[]) {
	}
	
	override void serialize(void delegate(char[])) {
	}
}



class FloatProvider : DataProvider {
	mixin MDataProvider!("float", "Slider");
	
	float value = 0.f;
	float min = 0.f;
	float max = 1.f;
	
	protected override void _doGUI() {
		HSlider setup(HSlider s) {
			if (!s.initialized) {
				s.minValue(this.min).maxValue(this.max).snapIncrement(0.25).position(this.value);
				s.layoutAttribs = "hexpand hfill";
			}
			return s;
		}
		auto s = setup(HSlider());
		float v = s.position;
		if (v != value) {
			value = v;
			invalidate();
		}
	}
	
	override Variant getValue() {
		return Variant(value);
	}

	override void configure(VarDef[] params) {
		foreach (p; params) {
			switch (p.name) {
				case "value":
					this.value = cast(float)(cast(NumberValue)p.value).value;
					break;
				case "min":
					this.min = cast(float)(cast(NumberValue)p.value).value;
					break;
				case "max":
					this.max = cast(float)(cast(NumberValue)p.value).value;
					break;
				default:
					nucledLog.warn("Unhandled param: '{}' for the Slider data provider.", p.name);
					break;
			}
		}
	}

	override void serialize(void delegate(char[]) sink) {
		sink(Format("float value={},float min={},float max={}", value, min, max));
	}
}


class Float2Provider : DataProvider {
	mixin MDataProvider!("float2", "Slider");
	
	vec2 value = vec2.zero;
	vec2 min = vec2.zero;
	vec2 max = vec2.one;
	
	protected override void _doGUI() {
		HSlider setup(HSlider s, int i) {
			if (!s.initialized) {
				s.minValue(this.min.cell[i]).maxValue(this.max.cell[i]).snapIncrement(0.25).position(this.value.cell[i]);
				s.layoutAttribs = "hexpand hfill";
			}
			return s;
		}
		for (int i = 0; i < 2; ++i) {
			auto s = setup(HSlider(i), i);
			float v = s.position;
			if (v != value.cell[i]) {
				value.cell[i] = v;
				invalidate();
			}
		}
	}
	
	override Variant getValue() {
		return Variant(value);
	}

	override void configure(VarDef[] params) {
		foreach (p; params) {
			switch (p.name) {
				case "value":
					this.value = vec2.from((cast(Vector2Value)p.value).value);
					break;
				case "min":
					this.min = vec2.from((cast(Vector2Value)p.value).value);
					break;
				case "max":
					this.max = vec2.from((cast(Vector2Value)p.value).value);
					break;
				default:
					nucledLog.warn("Unhandled param: '{}' for the Slider data provider.", p.name);
					break;
			}
		}
	}

	override void serialize(void delegate(char[]) sink) {
		//sink(Format("float value={},float min={},float max={}", value, min, max));
	}
}


class ColorProvider : DataProvider {
	mixin MDataProvider!("float4", "Color");
	
	vec3 hsv = vec3.unitZ;
	
	protected override void _doGUI() {
		auto wheel = ColorWheel();
		if (!wheel.initialized) {
			wheel.setHSV(hsv);
		} else {
			vec3 col = wheel.getHSV();
			if (col != hsv) {
				hsv = col;
				invalidate();
			}
		}
	}
	
	override Variant getValue() {
		vec4 val;
		hsv2rgb(hsv.tuple, &val.r, &val.g, &val.b);
		val.a = 1.0;
		return Variant(val);
	}

	override void configure(VarDef[] params) {
		foreach (p; params) {
			if ("hsv" == p.name) {
				this.hsv = vec3.from((cast(Vector3Value)p.value).value);
			}
		}
	}

	override void serialize(void delegate(char[]) sink) {
		sink(Format("vec3 hsv={} {} {}", hsv.tuple));
	}
}
