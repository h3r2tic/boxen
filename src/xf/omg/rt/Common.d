module xf.omg.rt.Common;

private {
	import xf.omg.core.LinearAlgebra : Vector;
	import xf.omg.core.CoordSys : CoordSys;
	import xf.omg.core.Algebra : negativeMax;
}


enum IntersectFlags {
	ComputeUV			= 0b1,
	ComputeNormal		= 0b10,
	Default					= 0
}


struct HitT(flt) {
	flt					distance = flt.max;
	flt					u;
	flt					v;
	Vector!(flt, 3)	normal;
	size_t			primitive;
}


struct RayT(flt) {
	Vector!(flt, 3) origin;
	Vector!(flt, 3)	direction;
	
	
	static RayT fromOrigDir(Vector!(flt, 3) origin, Vector!(flt, 3) direction) {
		RayT res = void;
		res.origin = origin;
		res.direction = direction;
		return res;
	}
	
	
	RayT opMul(CoordSys cs) {
		auto off = Vector!(flt, 3).from(cs.origin);
		return RayT(cs.rotation.xform(origin) + off, cs.rotation.xform(direction));
	}
}


alias HitT!(float)		Hit;
alias RayT!(float)	Ray;
