module xf.hybrid.Style;

private {
	import xf.hybrid.Shape;
	import xf.hybrid.WidgetConfig;
	import xf.hybrid.Texture;
	import xf.hybrid.HybridException;

	import xf.utils.Union;
	import xf.utils.Optional : Opt = Optional;
	import xf.hybrid.Math;
	import xf.omg.color.RGB;
	
	import tango.util.log.Trace;
}



struct BorderStyle {
	float	width = 1.f;
	vec4	color = {r:0, g: 0, b:0, a:1};
}


struct FontStyle {
	char[]	fontFace = "verdana.ttf";
	int		fontSize = 12;
}


class ImageStyle {
	char[]		path;
	Texture		texture;
	vec2[2]		texCoords;
	
	vec2i		size;
	ushort[2]	hlines = ushort.max;
	ushort[2]	vlines = ushort.max;
	
	this(char[] path) {
		assert (path.length > 0);
		this.path = path;
	}
}


struct GradientStyle {
	enum Type {
		Horizontal,
		Vertical
	}
	
	Type	type;
	vec4	color0;
	vec4	color1;
}


struct TextInputStyle {
	vec4	caretColor				= { r:1, g:0, b:0, a:1 };
	vec4	selectionBgColor	= { r:1, g:1, b:1, a:.5f };
	vec4	selectionFgColor	= { r:0, g:0, b:0, a:1 };
	float	caretBlinkFreq		= 1.3f;
}


mixin(makeTypedUnion("BackgroundStyle", ["vec4", "GradientStyle"], ["Solid", "Gradient"]));



BorderStyle combineStyle(BorderStyle src, BorderStyle *dst, float weight) {
	return BorderStyle(
		src.width * weight + (dst is null ? 0.f : dst.width) * (1.f - weight),
		src.color * weight + (dst is null ? vec4(src.color.r, src.color.g, src.color.b, 0) : dst.color) * (1.f - weight)
	);
}


TextInputStyle combineStyle(TextInputStyle src, TextInputStyle* dst, float weight) {
	TextInputStyle res = void;
	foreach (i, srcv; src.tupleof) {
		if (dst is null) {
			res.tupleof[i] = srcv;
		} else {
			res.tupleof[i] = srcv * weight + ((*dst).tupleof[i]) * (1.f - weight);
		}
	}
	return res;
}


FontStyle combineStyle(FontStyle src, FontStyle *dst, float weight) {
	return FontStyle(
		(weight > .5f ? src.fontFace : (dst is null ? src.fontFace : dst.fontFace)),
		cast(int)(src.fontSize * weight + (dst is null ? src.fontSize : dst.fontSize) * (1.f - weight))
	);
}


ImageStyle combineStyle(ImageStyle src, ImageStyle dst, float weight) {
	if (weight >= .5f || dst is null) {
		return src;
	} else {
		return dst;
	}
}


BackgroundStyle combineStyle(BackgroundStyle src, BackgroundStyle *dst, float weight) {
	if (weight >= 0.999f) {
		return src;
	}
	
	if (dst is null) {
		switch (src.type) {
			case BackgroundStyle.Type.Gradient: {
				auto res = src;
				res.Gradient.color0.a *= weight;
				res.Gradient.color1.a *= weight;
				return res;
			}

			case BackgroundStyle.Type.Solid: {
				auto res = src;
				res.Solid.a *= weight;
				return res;
			}

			default: assert (false);
		}
	} else {
		if (src.type == dst.type) {
			switch (src.type) {
				case BackgroundStyle.Type.Gradient: {
					auto res = src;
					res.Gradient.color0 = src.Gradient.color0 * weight + dst.Gradient.color0 * (1.f - weight);
					res.Gradient.color1 = src.Gradient.color1 * weight + dst.Gradient.color1 * (1.f - weight);
					return res;
				}

				case BackgroundStyle.Type.Solid: {
					auto res = src;
					res.Solid = src.Solid * weight + dst.Solid * (1.f - weight);
					return res;
				}

				default: assert (false);
			}
		} else {
			assert (false, "TODO");
			
			/+if (weight <= .5f) {
			} else {
			}+/
		}
	}
}



class Style {
	float	activationTime		= 0.f;
	float	deactivationTime	= 0.f;
	const static tupleofIndexStart = 2;		// don't do magic with the two above fields
	
	Opt!(vec4)				color;
	Opt!(BorderStyle)		border;
	Opt!(FontStyle)			font;
	Opt!(BackgroundStyle)	background;
	Opt!(ImageStyle)		image;
	Opt!(TextInputStyle)	textInput;
}



vec4 parseColor(Value val) {
	switch (val.type) {
		case Value.Type.String:
			switch (val.String) {
				case "black":	return vec4(0, 0, 0, 1);
				case "red":		return vec4(1, 0, 0, 1);
				case "green":	return vec4(0, 1, 0, 1);
				case "blue":	return vec4(0, 0, 1, 1);
				case "white":	return vec4.one;
				
				default: assert (false, val.String);
			}
		
		case Value.Type.FuncCall: {
			char[]	fname = val.FuncCall.name;
			auto	fargs = val.FuncCall.args;
				
			float num(Value v) {
				switch (v.type) {
					case (Value.Type.Int): return v.Int;
					case (Value.Type.Float): return v.Float;
					default: assert (false);
				}
			}
			
			switch (fname) {
				case "rgb": {
					vec4 col = vec4(num(fargs[0]), num(fargs[1]), num(fargs[2]), 1);
					convertRGB!(RGBSpace.sRGB, RGBSpace.Linear_sRGB)(col, &col);
					return col;
				}
				
				case "rgba": {
					vec4 col = vec4(num(fargs[0]), num(fargs[1]), num(fargs[2]), num(fargs[3]));
					convertRGB!(RGBSpace.sRGB, RGBSpace.Linear_sRGB)(col, &col);
					return col;
				}

				default: {
					hybridThrow("Unknown color function: '{}'.  Valid functions: rgb, rgba", fname);
					assert (false);
					//assert (false, fname);
				}
			}
		}
		
		default: {
			assert (false);
		}
	}
}


Style parseStyle(PropAssign[] cfg) {
	auto s = new Style;
	
	if (cfg is null) {
		return s;
	}
	
	foreach (p; cfg) {
		switch (p.name) {
			case "activation": {
				s.activationTime = parseFloat(p.value);
			} break;
			
			case "deactivation": {
				s.deactivationTime = parseFloat(p.value);
			} break;

			case "border": {
				s.border.value = BorderStyle.init;
				auto b = s.border.value;
				
				assert (Value.Type.Complex == p.value.type);
				foreach (item; p.value.Complex.items) {
					switch (item.type) {
						case Value.Type.Int: {
							b.width = item.Int;
						} break;
						
						case Value.Type.String:
						case Value.Type.FuncCall: {
							b.color = parseColor(item);
						} break;

						default: assert (false);
					}
				}
			} break;
			
			case "background": {
				if (Value.Type.FuncCall == p.value.type) {
					char[]	fname = p.value.FuncCall.name;
					auto		fargs = p.value.FuncCall.args;
					
					void makeGradient(GradientStyle.Type type) {
						s.background.value = BackgroundStyle.init;
						auto b = s.background.value;
						b.type = BackgroundStyle.Type.Gradient;
						auto g = &b.Gradient;
						g.type = type;
						g.color0 = parseColor(fargs[0]);
						g.color1 = parseColor(fargs[1]);
					}
					
					switch (fname) {
						case "hgradient": {
							makeGradient(GradientStyle.Type.Horizontal);
						} break;

						case "vgradient": {
							makeGradient(GradientStyle.Type.Vertical);
						} break;
						
						case "solid": {
							s.background.value = BackgroundStyle.init;
							auto b = s.background.value;
							b.type = BackgroundStyle.Type.Solid;
							b.Solid = parseColor(fargs[0]);
						} break;
						
						default: {
							assert (false, "Unknown background type: '" ~ fname ~ "'");
						}
					}
				}
			} break;
			
			
			case "textInput": {
				TextInputStyle tis = void;
				if (s.textInput.available) {
					tis = *s.textInput.value;
				} else {
					tis = TextInputStyle.init;
				}
				
				assert (Value.Type.Block == p.value.type);
				
				foreach (propAssign; p.value.Block) {
					switch (propAssign.name) {
						case "caretColor": {
							tis.caretColor = parseColor(propAssign.value);
						} break;

						case "selectionBgColor": {
							tis.selectionBgColor = parseColor(propAssign.value);
						} break;

						case "selectionFgColor": {
							tis.selectionFgColor = parseColor(propAssign.value);
						} break;

						default: assert (false);
					}
				}
				
				s.textInput.value = tis;
			} break;
			
			
			case "image": {
				if (Value.Type.FuncCall == p.value.type) {
					char[]	fname = p.value.FuncCall.name;
					auto		fargs = p.value.FuncCall.args;

					switch (fname) {
						case "file": {
							assert (fargs[0].type == Value.Type.String);
							auto nis = new ImageStyle(fargs[0].String.dup);
							s.image.value = nis;
						} break;

						case "grid": {
							assert (fargs.length >= 3);
							assert (fargs[0].type == Value.Type.String);
							auto nis = new ImageStyle(fargs[0].String.dup);
							s.image.value = nis;
							auto img = s.image.value;
							
							foreach (fa; fargs[1..$]) {
								assert (Value.Type.FuncCall == fa.type);
								
								char[]	fafname = fa.FuncCall.name;
								auto		fafargs = fa.FuncCall.args;
								
								assert (2 == fafargs.length);

								// TODO: runtime exceptions
								assert (Value.Type.Int == fafargs[0].type);
								assert (Value.Type.Int == fafargs[1].type);
								assert (fafargs[0].Int >= 0);
								assert (fafargs[0].Int <= ushort.max);
								assert (fafargs[1].Int >= 0);
								assert (fafargs[1].Int <= ushort.max);

								switch (fafname) {
									case "hline": {
										img.hlines[0] = cast(ushort)fafargs[0].Int;
										img.hlines[1] = cast(ushort)fafargs[1].Int;
									} break;

									case "vline": {
										img.vlines[0] = cast(ushort)fafargs[0].Int;
										img.vlines[1] = cast(ushort)fafargs[1].Int;
									} break;
									
									default: {
										assert (false, fafname);
									}
								}
							}
						} break;

						default: assert (false);
					}
				}
			} break;
			
			
			case "color": {
				s.color.value = parseColor(p.value);
			} break;
			
			
			default: {
				Trace.formatln("hybrid.backend.gl.Style.parseStyle: don't know what to do with property '" ~ p.name ~ "'");
			} break;
		}
	}
	
	return s;
}



template MStyleSupport() {
	Style	style() {
		if (!styleUpToDate) {
			calcCombinedState();
		}
		
		return _combinedStyle;
	}
	
	
	bool styleUpToDate() {
		return _combinedStyle !is null && _styleTimeDelta == 0.f;
	}
	
	
	void updateStyle(float seconds) {
		assert (seconds >= 0.f);
		
		if (seconds > 0.f) {
			_styleTimeDelta += seconds;
		}
	}
	
	
	void registerStyle(char[] name, Style style) {
		assert (name.length > 0);
		assert (style !is null);
		
		_registeredStyles[name] = style;
	}
	
	
	void enableStyle(char[] name) {
		onStyleEnabled(name);

		TStyle* st;
		if (!styleEnabled(name, &st)) {
			if (auto r = name in _registeredStyles) {
				_styles ~= TStyle(*r);
				st = &_styles[$-1];
			} else {
				//Trace.formatln("no style called '{}' in {}", name, this.classinfo.name);
				return;
			}
		}
		
		st.time = 0.f;
		st.status = StyleStatus.Activating;
		//Trace.formatln("style enabled: {}", name);
	}
	
	
	void disableStyle(char[] name) {
		onStyleDisabled(name);

		TStyle* st;
		if (styleEnabled(name, &st)) {
			st.time = 0.f;
			st.status = StyleStatus.Deactivating;
			//Trace.formatln("style disabled: {}", name);
		}
	}
	
	
	bool styleEnabled(char[] name, TStyle** ts = null) {
		if (auto sptr = name in _registeredStyles) {
			foreach (ref s; _styles) {
				if (s.style is *sptr && s.status != StyleStatus.Deactivating) {
					if (ts !is null) {
						*ts = &s;
					}
					
					return true;
				}
			}
		}
		
		return false;
	}
	
	
	private {
		void calcCombinedState() {
			if (_combinedStyle is null) {
				_combinedStyle = new Style;
			}
			
			updateStateTimes();
			
			/+foreach (i, _dummy; _combinedStyle.tupleof[Style.tupleofIndexStart .. $]) {
				_combinedStyle.tupleof[i+Style.tupleofIndexStart].reset();
			}+/
			
			foreach (st; _styles) {
				float weight = 0.f;

				switch (st.status) {
					case StyleStatus.Active:				weight = 1.f; break;
					case StyleStatus.Activating:		weight =
						0.f == st.style.activationTime ? 1.f : st.time / st.style.activationTime; break;
					case StyleStatus.Deactivating:	weight = 1.f - st.time / st.style.deactivationTime; break;
				}
				
				assert (weight <>= 0);
				
				this.combineStyle(st.style, weight);
			}
		}
		
		
		void combineStyle(Style st, float weight) {
			foreach (i, t; st.tupleof[Style.tupleofIndexStart .. $]) {
				if (!t.available) {
					continue;
				}

				auto ct = &_combinedStyle.tupleof[Style.tupleofIndexStart+i];
				
				auto src = t.value();
				auto dst = ct.available ? ct.value() : null;
				auto com = combineStyleItem!(t.type, typeof(src))(src, dst, weight);
				ct.value = com;
			}
		}
		
		
		static T combineStyleItem(T, TRef)(TRef src, TRef dst, float weight) {
			assert (src !is null);		// dst, however, may be null
			
			static if (is(typeof(.combineStyle(src, dst, weight) == T))) {
				return .combineStyle(src, dst, weight);
			}
			else static if (is(typeof(.combineStyle(*src, dst, weight) == T))) {
				return .combineStyle(*src, dst, weight);
			}
			else static if (is(typeof(*src * weight) == T) && is(typeof(*src + *dst) == T)) {
				if (dst is null) {
					return *src * weight;
				} else {
					return *src * weight + *dst * (1.f - weight);
				}
			}
			else {
				//static assert (false);
				pragma(msg, "static assert here: " ~ T.stringof ~ " is not " ~ typeof(src).stringof);
				return .combineStyle(src, dst, weight);
			}
		}
		
		
		void updateStateTimes() {
			bool removeAnyStyle = false;
			
			foreach (ref st; _styles) {
				st.time += _styleTimeDelta;
				
				switch (st.status) {
					case StyleStatus.Activating: {
						if (st.time >= st.style.activationTime) {
							st.status = StyleStatus.Active;
							st.time = 0.f;
						}
					} break;

					case StyleStatus.Deactivating: {
						if (st.time >= st.style.deactivationTime) {
							st.status = StyleStatus.RemoveMe;
							removeAnyStyle = true;
						}
					} break;
					
					case StyleStatus.Active: break;
				}
			}
			
			if (removeAnyStyle) {
				removeInactiveStyles();
			}			
			
			_styleTimeDelta = 0.f;
		}
		
		
		void resetCombinedStyle() {
			foreach (i, _dummy; _combinedStyle.tupleof[Style.tupleofIndexStart .. $]) {
				_combinedStyle.tupleof[i+Style.tupleofIndexStart].reset();
			}
		}
		
		
		void removeInactiveStyles() {
			/*
				HACK: it's located here so widgets styled from D won't have their style erased as if when
				this call was in calcCombinedState. It will be consistent with the previous behavior
				Styles need to be largely refactored anyway
			*/
			resetCombinedStyle();

			int dst = 0;
			foreach (src, ref st; _styles) {
				if (StyleStatus.RemoveMe != st.status) {
					if (dst != src) {
						_styles[dst] = st;
					}
					++dst;
				}
			}
			_styles.length = dst;
		}


		enum StyleStatus : ubyte {
			Active,
			Activating,
			Deactivating,
			RemoveMe
		}
		
		
		struct TStyle {
			Style				style;
			float				time;
			StyleStatus	status;
		}
		
		
		TStyle[]	_styles;
		Style			_combinedStyle;
		float			_styleTimeDelta = 0.f;
		
		Style[char[]]	_registeredStyles;
	}
}
