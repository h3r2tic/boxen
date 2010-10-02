module xf.nucled.StandardDataProviders;

private {
	import
		xf.Common;
	import
		xf.nucleus.Value,
		xf.nucleus.Param,
		xf.nucleus.SamplerDef,
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
		xf.mem.ChunkQueue;
	import
		tango.core.Variant,
		tango.text.convert.Format,
		tango.io.stream.Format;
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

	override void setValue(Param* p) {
		// TODO
	}
	
	override void configure(VarDef[]) {
	}

	override void dumpConfig(FormatOutput!(char)) {
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

	override void setValue(Param* p) {
		p.getValue(&value);
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

	override void dumpConfig(FormatOutput!(char) f) {
		f.format("min = {}; max = {};", min, max);
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

		HSlider[2] sliders;
		
		for (int i = 0; i < 2; ++i) {
			auto s = sliders[i] = setup(HSlider(i), i);
			float v = s.position;
			if (v != value.cell[i]) {
				value.cell[i] = v;
				invalidate();
			}
		}

		if (Check().text("cfg").checked) {
			HBox() [{
				Label().text("min").icfg(`size = 40 0;`);
				for (int i = 0; i < 2; ++i) HBox(i) [{
					auto s = FloatInputSpinner();
					if (!s.initialized) {
						s.value = min.cell[i];
					}
					if (s.value != min.cell[i]) {
						sliders[i].minValue = min.cell[i] = s.value;
					}
				}];
			}].icfg(`layout = { spacing = 5; }`);
			HBox() [{
				Label().text("max").icfg(`size = 40 0;`);
				for (int i = 0; i < 2; ++i) HBox(i) [{
					auto s = FloatInputSpinner();
					if (!s.initialized) {
						s.value = max.cell[i];
					}
					if (s.value != max.cell[i]) {
						sliders[i].maxValue = max.cell[i] = s.value;
					}
				}];
			}].icfg(`layout = { spacing = 5; }`);
		}
	}
	
	override Variant getValue() {
		return Variant(value);
	}

	override void setValue(Param* p) {
		p.getValue(&value.x, &value.y);
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

	override void dumpConfig(FormatOutput!(char) f) {
		f.format("min = {} {}; max = {} {};", min.tuple, max.tuple);
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

	override void setValue(Param* p) {
		vec4 rgba;
		p.getValue(&rgba.x, &rgba.y, &rgba.z, &rgba.w);
		rgb2hsv(rgba.xyz.tuple, &hsv.x, &hsv.y, &hsv.z);
	}

	override void configure(VarDef[] params) {
		foreach (p; params) {
			if ("hsv" == p.name) {
				this.hsv = vec3.from((cast(Vector3Value)p.value).value);
			}
		}
	}


	override void dumpConfig(FormatOutput!(char) f) {
	}
}


class SamplerProvider : DataProvider {
	mixin MDataProvider!("sampler2D", "bitmap");

	this() {
		_mem.initialize();
		sampler = new SamplerDef(&_mem.pushBack);
	}
	
	protected override void _doGUI() {
		HBox() [{
			final input = Input();
			input.userSize(vec2(100, 0));
			if (resetGUI) {
				input.text = this.path;
			} else {
				if (input.text != this.path) {
					_changed = true;
					final p = sampler.params.get("texture");
					p.setValue(input.text);
					this.path = input.text;
				}
			}
			Button().text = "Browse";
		}].icfg(`layout = { spacing = 5; }`);

		resetGUI = false;
	}
	
	override Variant getValue() {
		return Variant(cast(Object)sampler);
	}

	override void setValue(Param* p) {
		Object val;
		p.getValue(&val);
		sampler = cast(SamplerDef)val;
		sampler.params.get("texture").getValue(&path);
		resetGUI = true;
	}
	
	override void configure(VarDef[]) {}

	override void dumpConfig(FormatOutput!(char)) {}


	SamplerDef	sampler;
	ScratchFIFO	_mem;
	cstring		path;
	bool		resetGUI = true;
}
