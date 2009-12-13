module xf.omg.misc.Interpolation;


/**
	'Nearest' interpolation function
	
	Params:
	t == time, a float from [0, 1]
	a == first value
	b == second value
	res == a place to put the result in
	
	Remarks:
	---
	nearestInterp(< 0.5, a, b, res), res == a
	nearestInterp(>= 0.5, a, b, res), res == b
	---
*/
void nearestInterp(T)(float t, T a, T b, inout T res) {
	if (t >= 0.5f) res = b;
	else res = a;
}


/**
	'Linear' interpolation function
	
	Params:
	t == time, a float from [0, 1]
	a == first value
	b == second value
	res == a place to put the result in
	
	Remarks:
	---
	nearestInterp(0, a, b, res), res == a
	nearestInterp(1, a, b, res), res == b
	---
*/
void linearInterp(T)(float t, T a, T b, out T res) {
	res = a * (1.f - t) + b * t;
}


/**
	Catmull-Rom interpolation function
	
	Params:
	t == time, a float from [0, 1]
	a == first value
	b == second value
	c == third value
	d == fourth value
	res == a place to put the result in
*/
void catmullRomInterp(T)(float t, T a, T b, T c, T d, out T res) {
	res = .5f * (	(b * 2.f) +
						(c - a) * t +
						(a * 2.f - b * 5.f + c * 4.f - d) * t * t +
						(b * 3.f - c * 3.f + d - a) * t * t * t);
}



/**
	Catmull-Rom derivative
*/
void catmullRomDeriv(T)(float t, T p0, T p1, T p2, T p3, out T res) {
	float t2 = t*t;
	res =	((-p0 + p2) +
				(p0*2.f - p1*5.f + p2*4.f - p3) * t * 2.f +
				(-p0 + p1*3.f - p2*3.f + p3) * t2 * 3.f) * .5f;
}




void hermiteInterp(T)(float t, T a, T ta, T b, T tb, inout T res) {
	float t2 = t * t;
	float t3 = t2 * t;
	float h1 = 2 * t3 - 3 * t2 + 1;
	float h2 = -2* t3 + 3 * t2;
	float h3 = t3 - 2 * t2 + t;
	float h4 = t3 - t2;
	res = h1 * a + h3 * ta + h2 * b + h4 * tb;
}
