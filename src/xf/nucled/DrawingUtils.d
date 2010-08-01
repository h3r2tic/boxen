module xf.nucled.DrawingUtils;

private {
	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.Misc;
	import xf.omg.misc.Interpolation;
}



/+void tesselateCurve(int segments, vec2 left, vec2 right, void delegate(float t, vec2 p0, vec2 p1) dg) {
	alias left p0;
	alias right p1;

	float dist = (p0 - p1).length * 0.3 + abs(p0.x - p1.x) * 0.7;
	float dirMult = 1.f - dot((p1 - p0).normalized, vec2(1, 0));
	dist *= 1.f + dirMult;
	if (dist > 700) dist = 700;

	vec2 t0 = vec2(dist, (p1.y-p0.y)*dirMult*0.3);
	vec2 t1 = vec2(dist, (p1.y-p0.y)*dirMult*0.3);
	
	tesselateCurve(segments, p0, t0, p1, t1, dg);
}



void tesselateCurve(int segments, vec2 p0_, vec2 t0_, vec2 p1_, vec2 t1_, void delegate(float t, vec2 p0, vec2 p1) dg) {
	alias p0_ p0;
	alias p1_ p2;
	
	float dist = (p0 - p2).length * 0.3 + abs(p0.x - p2.x) * 0.7;
	float dirMult = 1.f - dot((p2 - p0).normalized, vec2(1, 0));
	dist *= 1.f + dirMult;
	if (dist > 700) dist = 700;

	alias t0_ p1;
	alias t1_ p3;
	
	//int segments = 32;
	for (int i = 0; i < segments; ++i) {
		float tl = cast(float)(i) / segments;
		float tr = (cast(float)i+1.01) / segments;
		vec2 pl; hermiteInterp(tl, p0, p1, p2, p3, pl);
		vec2 pr; hermiteInterp(tr, p0, p1, p2, p3, pr);
		dg(tl, pl, pr);
	}
}
+/

void tesselateCurve(int segments, vec2 left, vec2 right, void delegate(vec2 p0) dg) {
	alias left p0;
	alias right p1;

	float dist = (p0 - p1).length * 0.3 + abs(p0.x - p1.x) * 0.7;
	float dirMult = 1.f - dot((p1 - p0).normalized, vec2(1, 0));
	dist *= 1.f + dirMult;
	if (dist > 700) dist = 700;

	vec2 t0 = vec2(dist, (p1.y-p0.y)*dirMult*0.3);
	vec2 t1 = vec2(dist, (p1.y-p0.y)*dirMult*0.3);
	
	tesselateCurve(segments, p0, t0, p1, t1, dg);
}


void tesselateCurve(int segments, vec2 p0_, vec2 t0_, vec2 p1_, vec2 t1_, void delegate(vec2 p0) dg) {
	assert (segments > 1);
	
	alias p0_ p0;
	alias p1_ p2;
	
	float dist = (p0 - p2).length * 0.3 + abs(p0.x - p2.x) * 0.7;
	float dirMult = 1.f - dot((p2 - p0).normalized, vec2(1, 0));
	dist *= 1.f + dirMult;
	if (dist > 700) dist = 700;

	alias t0_ p1;
	alias t1_ p3;
	
	dg(p0_);
	
	for (int i = 0; i < segments; ++i) {
		float tl = cast(float)(i+1)/segments;
		vec2 pl; hermiteInterp(tl, p0, p1, p2, p3, pl);
		dg(pl);
	}
}


void tesselateThickCurve(vec2 point0, vec2 point1, float thickness_, void delegate(vec2 pA, vec2 p, vec2 pB) sink) {
	const int maxSegments = 32;
	
	int segments = max(6, cast(int)(abs(point0.y - point1.y) / 15.f) + cast(int)(abs(point0.x - point1.x) / 40.f));
	if (point1.x < point0.x + 2.f) {
		segments *= 2;
	}
	if (segments > maxSegments-1) {
		segments = maxSegments-1;
	}
	
	float thickness = thickness_ * 0.5f;
	
	vec2[maxSegments] interpolated_;
	auto interpolated = interpolated_[0..segments+1]; {
		int segI = 0;
		tesselateCurve(segments, point0, point1, (vec2 p) {
			interpolated[segI++] = p;
		});
	}
	
	vec2[2][maxSegments] thick_;
	auto thick = thick_[0..segments+1];
	
	void genCurve(vec2 prevDir, float prevDist, int from, int to, int inc) {
		int prev = from;
		vec2 p0 = interpolated[prev];
		vec2 p1;
		
		int idx1 = (inc + 1) / 2;
		int idx0 = 1 - idx1;
		
		thick[from][0] = p0 + vec2(0, thickness);
		thick[from][1] = p0 - vec2(0, thickness);

		vec2 prevA = thick[from][idx0];
		vec2 prevB = thick[from][idx1];
		
		const int fixLength = 2;
		vec2[fixLength] prevDir2 = prevDir;
		float[fixLength] prevDist2 = prevDist;
		
		for (int i = from+inc; i != to; i += inc, p0 = p1) {
			p1 = interpolated[i];
			vec2 dir = (p1 - p0).normalized;
			vec2 perpend = dir.rotatedHalfPi();
			
			vec2 pA = p1 + perpend * thickness;
			vec2 pB = p1 - perpend * thickness;
			
			bool inFront(vec2 p) {
				if (dot(p, prevDir) - prevDist < 0.f) {
					return false;
				}

				foreach (i, d; prevDir2) {
					if (dot(p, d) - prevDist2[i] < 0.f) {
						return false;
					}
				}
				
				return true;
			}
			
			if (!inFront(pA)) {
				pA = prevA;
			}
			
			if (!inFront(pB)) {
				pB = prevB;
			}
			
			thick[i][idx0] = pA;
			thick[i][idx1] = pB;
			
			for (int j = 0; j < fixLength-1; ++j) {
				prevDir2[j] = prevDir2[j+1];
				prevDist2[j] = prevDist2[j+1];
			}

			prevDir2[$-1] = prevDir;
			prevDist2[$-1] = prevDist;
			
			prevDir = dir;
			prevDist = dot(dir, p1);
			
			prevA = pA;
			prevB = pB;
		}
	}
	
	genCurve(vec2.unitX, dot(vec2.unitX, point0), 0, segments/2+1, 1);
	genCurve(-vec2.unitX, dot(-vec2.unitX, point1), segments, segments-segments/2-1, -1);
	
	for (int i = 0; i < segments+1; ++i) {
		sink(thick[i][0], interpolated[i], thick[i][1]);
	}
}
