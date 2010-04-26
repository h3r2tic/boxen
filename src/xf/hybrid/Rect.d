module xf.hybrid.Rect;

private {
	import xf.hybrid.Math : vec2;
}



///
struct Rect {
	///
	vec2 min	= {x: float.max,	y: float.max};
	
	///
	vec2 max	= {x: -float.max,	y: -float.max};


	///
	float width()	{ return max.x - min.x; }
	
	///
	float height()	{ return max.y - min.y; }
	

	///
	static Rect opCall(vec2 min, vec2 max) {
		Rect res;
		res.min = min;
		res.max = max;
		return res;
	}
	
	
	///
	vec2 size() {
		return vec2(width, height);
	}
	
	
	///
	bool intersect(Rect rect) {
		return	(min.x < rect.max.x && max.x > rect.min.x) &&
					(min.y < rect.max.y && max.y > rect.min.y);
	}
	
	
	///
	bool contains(vec2 p) {
		return p.x >= min.x && p.x < max.x && p.y >= min.y && p.y < max.y;
	}
	
	
	///
	void shrink(float x, float y) {
		min.x += x;
		min.y += y;
		max.x -= x;
		max.y -= y;
	}
	

	///
	static Rect sum(Rect a, Rect b) {
		float min(float a, float b)		{ return (a < b ? a : b); }
		float max(float a, float b)	{ return (a > b ? a : b); }
		
		Rect res;
		res.min.x	= min(a.min.x, b.min.x);
		res.min.y	= min(a.min.y, b.min.y);
		res.max.x	= max(a.max.x, b.max.x);
		res.max.y	= max(a.max.y, b.max.y);
		
		return res;
	}
	
	
	///
	static Rect shaft(Rect a, Rect b) {
		float min(float a, float b)		{ return (a < b ? a : b); }
		float max(float a, float b)	{ return (a > b ? a : b); }
		
		Rect res;
		res.min.x	= min(a.max.x, b.max.x);
		res.max.x	= max(a.min.x, b.min.x);
		res.min.y	= min(a.max.y, b.max.y);
		res.max.y	= max(a.min.y, b.min.y);
		
		if (res.min.x > res.max.x) {
			float tmp = res.min.x;
			res.min.x = res.max.x;
			res.max.x = tmp;
		}

		if (res.min.y > res.max.y) {
			float tmp = res.min.y;
			res.min.y = res.max.y;
			res.max.y = tmp;
		}
		
		return res;
	}


	///
	static Rect intersection(Rect a, Rect b) {
		float min(float a, float b)		{ return (a < b ? a : b); }
		float max(float a, float b)	{ return (a > b ? a : b); }
		
		Rect res;
		res.min.x	= max(a.min.x, b.min.x);
		res.max.x	= min(a.max.x, b.max.x);
		res.min.y	= max(a.min.y, b.min.y);
		res.max.y	= min(a.max.y, b.max.y);
		return res;
	}
}
