module xf.omg.core.Misc;

public {
	import tango.math.Math :    min, max, floor, ceil, sin, cos, tan, atan, atan2,
                                rndint, pow, abs, exp, sqrt, cbrt;

    import tango.stdc.math : fmodf;
}


const real deg2rad	= 0.0174532925199432957692369076848861;
const real rad2deg	= 57.2957795130823208767981548141052;
const real pi			= 3.1415926535897932384626433832795;

// for unitness tests
const real unitSqNormEpsilon = 0.001;



// Stolen from Beyond3D
// Modified magical constant based on Chris Lomont's paper
float invSqrt(float x) {
    float xhalf = 0.5f * x;
    int i = *cast(int*)&x;
    i = 0x5f375a86 - (i >> 1);
    x = *cast(float*)&i;
    x = x*(1.5f - xhalf * x * x);
    return x;
}


// as in Cg
float saturate(float x) {
    return min(1.0f, max(0.0f, x));
}

double saturate(double x) {
    return min(1.0, max(0.0, x));
}

real saturate(real x) {
    return min(1.0, max(0.0, x));
}
