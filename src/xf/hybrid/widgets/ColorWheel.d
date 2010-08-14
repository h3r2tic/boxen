module xf.hybrid.widgets.ColorWheel;

private {
	import xf.hybrid.Common;
	import xf.hybrid.IconCache;
	import xf.hybrid.Texture;
	import xf.hybrid.FontRenderer;
	import xf.utils.Memory;
	import xf.omg.core.LinearAlgebra;
	import xf.omg.color.HSV;
	import tango.stdc.math : fmodf;
	import tango.math.Math;
	
	import tango.io.Stdout;
}


private bool pointInTriangle(vec2 P, vec2 C, vec2 B, vec2 A, out float u, out float v) {
	assert (P.ok);
	assert (A.ok);
	assert (B.ok);
	assert (C.ok);
	
	// Compute vectors
	auto v0 = C - A;
	auto v1 = B - A;
	auto v2 = P - A;

	// Compute dot products
	auto dot00 = dot(v0, v0);
	auto dot01 = dot(v0, v1);
	auto dot02 = dot(v0, v2);
	auto dot11 = dot(v1, v1);
	auto dot12 = dot(v1, v2);

	// Compute barycentric coordinates
	auto invDenom = 1.0 / (dot00 * dot11 - dot01 * dot01);
	u = (dot11 * dot02 - dot01 * dot12) * invDenom;
	v = (dot00 * dot12 - dot01 * dot02) * invDenom;

	// Check if point is in triangle
	return (u >= 0.0) && (v >= 0.0) && (u + v <= 1.0);
}


private ubyte f2ub(float v) {
	if (v <= 0) return 0;
	if (v >= 1) return 255;
	return cast(ubyte)rndint(255 * v);
}	



private vec2 closestPointOnSegment(vec2 P, vec2 A, vec2 B) {
	vec2 seg = B - A;
	double segLen = seg.length;
	seg *= 1.0 / segLen;
	
	double ptDist = dot(P - A, seg);
	if (ptDist < 0) {
		return A;
	} else {
		if (ptDist < segLen) {
			auto res = A + seg * ptDist;
			//double dev = dot(B - A, P - res);
			//assert (abs(dev) < 0.001, Format("deviation = {} (A={}, B={}, P={}, res={})", dev, A, B, P, res));
			return res;
		} else {
			return B;
		}
	}
}


private vec2 constrainToTriPerpendicular(vec2 pt, vec2 p0, vec2 p1, vec2 p2) {
	vec2 a = closestPointOnSegment(pt, p0, p1);
	vec2 b = closestPointOnSegment(pt, p1, p2);
	vec2 c = closestPointOnSegment(pt, p2, p0);

	double ad = (pt - a).sqLength;
	double bd = (pt - b).sqLength;
	double cd = (pt - c).sqLength;
	
	vec2 res = a;
	double dist = ad;
	
	if (bd < dist) {
		res = b;
		dist = bd;
	}

	if (cd < dist) {
		res = c;
	}
	
	return vec2(res.x, res.y);
}


class ColorWheel : Widget {
	const vec2 csize = { x: 150, y: 150 };
	
	override vec2 minSize() {
		return csize;
	}
	
	struct CachedTex {
		Texture tex;
		vec2i bl, tr;
		vec2 blCoords, trCoords;
	}
	
	CachedTex ringTexture;
	CachedTex triangleTexture;

	const vec2i hotspotSize = { x: 8, y: 8 };
	CachedTex hotspotTexture;
	
	const float ringOuter = 1.0;
	const float ringInner = 0.75;
	
	float	currentHue = 0.f;
	float	currentSaturation = 1.f;
	float	currentValue = 1.f;
	
	bool	triangleDirty = true;
	bool	draggingRing = false;
	bool	draggingTriangle = false;
	//vec2	curTriUV = { x: 1.f, y: 0.f };
	
	static float angleToHue(float a) {
		return fmodf(fmodf(a / (2.0 * pi), 1.f) + 1.f, 1.f);
	}
	
	static float hueToAngle(float h) {
		return h * 2 * pi;
	}	

	private float triRotation() {
		return hueToAngle(currentHue);
	}
	
	private void triRotation(float a) {
		currentHue = angleToHue(a);
		//Stdout.formatln("rot={} hue={}", a * rad2deg, currentHue);
		triangleDirty = true;
	}


	ubyte inRing(float outer, float inner, float d) {
		float margin = 5 / csize.x;
		if (d > outer) return 0;
		else if (d < inner) return 0;
		else if (d > outer - margin) return cast(ubyte)rndint(255.f * (outer - d) / margin);
		else if (d < inner + margin) return cast(ubyte)rndint(255.f * (d - inner) / margin);
		//else if (d < inner + 1/csize.x*5) return cast(ubyte) ((d - inner + 1/csize.x*5) * 127f);
		else return 255;
	}

	
	void updateTexture(IconCache iconCache, CachedTex tex, vec4ub delegate(float x, float y) calc) {
		vec2i size = tex.tr - tex.bl;

		vec4ub[] data;
		data.alloc(size.x * size.y);
		scope (exit) data.free();
		
		for (int y_ = 0; y_ < size.y; ++y_) {
			float y = (cast(float)y_ + 0.5f) / size.y;
			y -= 0.5f;
			y *= 2.f;
			//size_t offset = y_ * cast(int)csize.x;
			
			for (int x_ = 0; x_ < size.x; ++x_) {
				float x = (cast(float)x_ + 0.5f) / size.x;
				x -= 0.5f;
				x *= 2.f;
				
				//data[offset + x_] = calc(x, y);
				data[x_ * cast(int)size.y + y_] = calc(x, y);
			}
		}
		
		iconCache.updateTexture(tex.tex, tex.bl, tex.tr - tex.bl, cast(ubyte*)data.ptr);
	}
	
	
	private void createRingTexture(IconCache iconCache) {
		updateTexture(iconCache, ringTexture, (float x, float y) {
			float len = sqrt(x * x + y * y);
			if (auto alpha = inRing(ringOuter, ringInner,  len)) {
				float h = angleToHue(atan2(y, x));//fmodf(fmodf(atan2(y, x) / (2.0 * pi), 1.f) + 1.f, 1.f);
				float s = 1;
				float v = 1;
				
				vec3 rgb = void;
				hsv2rgb(h, s, v, &rgb.r, &rgb.g, &rgb.b);
				
				return vec4ub(f2ub(rgb.r), f2ub(rgb.g), f2ub(rgb.b), alpha);
			} else {
				return vec4ub.zero;
			}
		});
	}
	
	
	private vec3 getTriangleColor(vec2 pt0, vec2 pt1, vec2 pt2, vec2 pt, out float s, out float v) {
		float det = (pt0.x - pt2.x) * (pt1.y - pt2.y) - (pt0.y - pt2.y) * (pt1.x - pt2.x);
		float b0 = ((pt1.y - pt2.y) * (pt.x - pt2.x) + (pt2.x - pt1.x) * (pt.y - pt2.y)) / det;
		float b1 = ((pt2.y - pt0.y) * (pt.x - pt2.x) + (pt0.x - pt2.x) * (pt.y - pt2.y)) / det;
		float b2 = 1.0 - b0 - b1;

		s = 1.0 == b2 ? 0 : (b0 / (b0 + b1));
		v = b0 + b1;

		s = min(1.0, max(0.0, s));
		v = min(1.0, max(0.0, v));
		
		vec3 rgb = void;
		hsv2rgb(currentHue, s, v, &rgb.r, &rgb.g, &rgb.b);
		return rgb;
	}
	
	
	void getTrianglePoints(out vec2 pt0, out vec2 pt1, out vec2 pt2) {
		float angle0 = this.triRotation();
		float angle1 = angle0 + pi*2/3;
		float angle2 = angle1 + pi*2/3;
		
		pt0 = vec2(cos(angle0), sin(angle0)) * ringInner;
		pt1 = vec2(cos(angle1), sin(angle1)) * ringInner;
		pt2 = vec2(cos(angle2), sin(angle2)) * ringInner;
		
		//Stdout.formatln("pt0: {}", pt0);
	}
	

	private void createTriangleTexture(IconCache iconCache) {
		vec2 pt0, pt1, pt2;
		getTrianglePoints(pt0, pt1, pt2);
		
		updateTexture(iconCache, triangleTexture, (float x, float y) {
			float tu, tv;
			if (pointInTriangle(vec2(x, y), pt0, pt1, pt2, tu, tv)) {
				float margin = 5.f / csize.x;
				float fuzz = min(1, 1.f - max(0, (margin - tu) / margin, (margin - tv) / margin, (margin - 1.f + tu + tv) / margin));
				
				float s, v;
				auto rgb = getTriangleColor(pt0, pt1, pt2, vec2(x, y), s, v);
				
				return vec4ub(f2ub(rgb.r), f2ub(rgb.g), f2ub(rgb.b), cast(ubyte)rndint(fuzz * 255.f));
			} else {
				return vec4ub.zero;
			}
		});
		
		triangleDirty = false;
	}

	
	void drawCachedTex(GuiRenderer r, ref CachedTex tex, vec2 size, vec2 offset = vec2.zero) {
		r.color = vec4.one;
		r.enableTexturing(tex.tex);
		
		vec2[4] vp = void;
		vp[0] = vec2(0, size.y);
		vp[1] = vec2(size.x, size.y);
		vp[2] = vec2(size.x, 0);
		vp[3] = vec2(0, 0);
		
		vec2 off = this.globalOffset + offset;

		vec2[4] tc = void;
		tc[0] = tex.blCoords;
		tc[2] = tex.trCoords;
		tc[1] = vec2(tc[0].x, tc[2].y);
		tc[3] = vec2(tc[2].x, tc[0].y);
		
		/+ Way to go, DMD

.objs\xf-hybrid-widgets-HTiledImage.obj(xf-hybrid-widgets-HTiledImage)  Offset 06304H Record Type 00C3
 Error 1: Previous Definition Different : __arrayExpSliceAddass_S2xf3omg4core13LinearAlgebra16__T6VectorTfVi2Z6Vector
		+/
		//vp[] += off;
		foreach (ref p; vp) {
			p += off;
		}

		r.absoluteQuad(vp, tc);
	}


	this() {
		this.addHandler(&this.handleMouseButton);
		this.addHandler(&this.handleMouseMove);
	}


	void handleMouseInput(vec2 pos, bool click = false) {
		float x = ((pos.x / this.size.x) - .5f) * 2.f;
		float y = -((pos.y / this.size.y) - .5f) * 2.f;
		
		vec2 pt0, pt1, pt2;
		getTrianglePoints(pt0, pt1, pt2);
		float tu, tv;
		
		bool inTri = pointInTriangle(vec2(x, y), pt0, pt1, pt2, tu, tv);
		if (draggingTriangle || (!draggingRing && click && inTri)) {
			if (click) draggingTriangle = true;
			
			vec2 pt = tu * pt0 + tv * pt1 + (1.f - tu - tv) * pt2;
			
			if (!inTri) {
				pt = constrainToTriPerpendicular(pt, pt2, pt1, pt0);
				Stdout.formatln("before: {} {}", tu, tv);
				pointInTriangle(pt, pt0, pt1, pt2, tu, tv);
				Stdout.formatln("after: {} {}", tu, tv);
			} else {
				Stdout.formatln("pos: {}", pt.toString);
			}
			
			//curTriUV = vec2(tu, tv);
			Stdout.formatln("tu: {}, tv: {}", tu, tv);
			
			getTriangleColor(pt0, pt1, pt2, pt, this.currentSaturation, this.currentValue);
			
			this.currentSaturation = min(this.currentSaturation, 1);
			this.currentSaturation = max(this.currentSaturation, 0);
			
			this.currentValue = min(this.currentValue, 1);
			this.currentValue = max(this.currentValue, 0);
			
			Stdout.formatln("hsv: {}", getHSV());
		} else if (draggingRing || (!draggingTriangle && click && !inTri)) {
			if (click) draggingRing = true;
			this.triRotation = atan2(y, x);
		}
	}


	EventHandling handleMouseMove(MouseMoveEvent e) {
		if (e.sinking && !e.handled) {
			handleMouseInput(e.pos, false);
			return EventHandling.Stop;
		}
		return EventHandling.Continue;
	}
	
	
	EventHandling handleMouseButton(MouseButtonEvent e) {
		if (e.button.Left == e.button && !e.down) {
			draggingRing = false;
			draggingTriangle = false;
		}
		
		if (e.sinking && !e.handled && e.button.Left == e.button && e.down) {
			handleMouseInput(e.pos, true);
			return EventHandling.Stop;
		}
		return EventHandling.Continue;
	}
	
	
	override EventHandling handleRender(RenderEvent e) {
		if (!widgetVisible) {
			return EventHandling.Stop;
		}

		assert (e.renderer !is null);
		auto r = e.renderer;
		
		/+if (auto fr = cast(FontRenderer)e) {
			fr.blendingMode = BlendingMode.Alpha;
		}+/
		
		if (hotspotTexture.tex is null) {
			hotspotTexture.tex = r.iconCache.get(vec2i.from(hotspotSize), hotspotTexture.bl, hotspotTexture.tr, hotspotTexture.blCoords, hotspotTexture.trCoords);

			updateTexture(r.iconCache, hotspotTexture, (float x, float y) {
				float len = sqrt(x * x + y * y);
				const float width = 0.5;
				const float off = 0.7;
				float alpha = 1.f - min(1, abs(off - len) / width);
				//alpha *= alpha;
				float val = 1.f - alpha * alpha;
				ubyte ubval = f2ub(val);
				
				return vec4ub(ubval, ubval, ubval, f2ub(alpha));
			});
		}
		
		if (ringTexture.tex is null) {
			ringTexture.tex = r.iconCache.get(vec2i.from(csize), ringTexture.bl, ringTexture.tr, ringTexture.blCoords, ringTexture.trCoords);
			createRingTexture(r.iconCache);
		}
		drawCachedTex(r, ringTexture, this.size);

		if (triangleTexture.tex is null) {
			triangleTexture.tex = r.iconCache.get(vec2i.from(csize), triangleTexture.bl, triangleTexture.tr, triangleTexture.blCoords, triangleTexture.trCoords);
		}
		
		if (triangleDirty) {
			createTriangleTexture(r.iconCache);
		}
		
		drawCachedTex(r, triangleTexture, this.size);
		
		{
			vec2 pt0, pt1, pt2;
			getTrianglePoints(pt0, pt1, pt2);
			
			//vec2 p = pt0 * curTriUV.x + pt1 * curTriUV.y + pt2 * (1.f - curTriUV.x - curTriUV.y);
			vec3 b = svToBarycentric(vec2(currentSaturation, currentValue));
			vec2 p = pt0 * b.x + pt1 * b.y + pt2 * b.z;
			
			drawCachedTex(r, hotspotTexture, vec2.from(hotspotSize), this.size * (vec2(p.x, -p.y) + 1.f) * 0.5f - vec2.from(hotspotSize) / 2);
		}

		return EventHandling.Continue;
	}


	private vec3 svToBarycentric(vec2 sv) {
		/+s = 1.0 == b2 ? 0 : (b0 / (b0 + b1));
		v = b0 + b1;

		s = min(1.0, max(0.0, s));
		v = min(1.0, max(0.0, v));+/

		float b0 = sv.x * sv.y;
		float b1 = sv.y - b0;
		float b2 = 1.0 - b0 - b1;
		return vec3(b0, b1, b2);
	}
	
	
	vec3 getHSV() {
		return vec3(currentHue, currentSaturation, currentValue);
	}
	

	void setHSV(vec3 hsv) {
		currentHue = hsv.x;
		currentSaturation = hsv.y;
		currentValue = hsv.z;
	}

	
	vec3 getRGB() {
		vec3 hsv = getHSV();
		vec3 rgb = void;
		hsv2rgb(hsv.x, hsv.y, hsv.z, &rgb.r, &rgb.g, &rgb.b);
		return rgb;
	}
	
	
	mixin(defineProperties("out vec3 getHSV, out vec3 getRGB"));
	mixin MWidget;
}
