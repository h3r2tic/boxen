module xf.hybrid.Math;

public {
	version (OldMath) {
		import xf.maths.Vec;
		import xf.maths.Misc;
	} else {
		import xf.omg.core.LinearAlgebra : vec2, vec2i, vec3, vec4, Vector, cross, dot;
		import xf.omg.core.Misc;
	}
}
