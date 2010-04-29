module xf.omg.color.Quantize;

private {
	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.Misc : rndint, ceil, floor, min, max;
}



// Round-off is linear here, although should not be so for non-linear color spaces
vec3ub linearQuantizeColor(vec3 c) {
	vec3ub res = void;

	if (c.x >= 1.0) res.x = 255;
	else if (c.x <= 0.0) res.x = 0;
	else res.x = cast(ubyte)rndint(255 * c.x);

	if (c.y >= 1.0) res.y = 255;
	else if (c.y <= 0.0) res.y = 0;
	else res.y = cast(ubyte)rndint(255 * c.y);

	if (c.z >= 1.0) res.z = 255;
	else if (c.z <= 0.0) res.z = 0;
	else res.z = cast(ubyte)rndint(255 * c.z);

	return res;
}


// This is overkill, but considering how everyone does colors wrong, fuck that :P
// Basically, for each component, the conversion func checks whether
// rounding down or up yields the least error in the original linear function
// then chooses this round-off mode.
vec3ub quantizeColor(Gamma)(vec3 c) {
	vec3ub res = void;

	{
		real l = Gamma.toLinear(c.x);
		real lf = Gamma.toLinear(floor(c.x * 255.0) / 255.0);
		real lc = Gamma.toLinear(ceil(c.x * 255.0) / 255.0);
		
		if (abs(lf - l) <= abs(lc - l)) {
			res.x = cast(ubyte)min(255, max(0, rndint(floor(255 * c.x))));
		} else {
			res.x = cast(ubyte)min(255, max(0, rndint(ceil(255 * c.x))));
		}
	}

	{
		real l = Gamma.toLinear(c.y);
		real lf = Gamma.toLinear(floor(c.y * 255.0) / 255.0);
		real lc = Gamma.toLinear(ceil(c.y * 255.0) / 255.0);
		
		if (abs(lf - l) <= abs(lc - l)) {
			res.y = cast(ubyte)min(255, max(0, rndint(floor(255 * c.y))));
		} else {
			res.y = cast(ubyte)min(255, max(0, rndint(ceil(255 * c.y))));
		}
	}

	{
		real l = Gamma.toLinear(c.z);
		real lf = Gamma.toLinear(floor(c.z * 255.0) / 255.0);
		real lc = Gamma.toLinear(ceil(c.z * 255.0) / 255.0);
		
		if (abs(lf - l) <= abs(lc - l)) {
			res.z = cast(ubyte)min(255, max(0, rndint(floor(255 * c.z))));
		} else {
			res.z = cast(ubyte)min(255, max(0, rndint(ceil(255 * c.z))));
		}
	}

	return res;
}


// Round-off is linear here, although should not be so for non-linear color spaces
vec4ub linearQuantizeColor(vec4 c) {
	vec4ub res = void;

	if (c.x >= 1.0) res.x = 255;
	else if (c.x <= 0.0) res.x = 0;
	else res.x = cast(ubyte)rndint(255 * c.x);

	if (c.y >= 1.0) res.y = 255;
	else if (c.y <= 0.0) res.y = 0;
	else res.y = cast(ubyte)rndint(255 * c.y);

	if (c.z >= 1.0) res.z = 255;
	else if (c.z <= 0.0) res.z = 0;
	else res.z = cast(ubyte)rndint(255 * c.z);

	if (c.w >= 1.0) res.w = 255;
	else if (c.w <= 0.0) res.w = 0;
	else res.w = cast(ubyte)rndint(255 * c.w);

	return res;
}
