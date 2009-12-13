module xf.omg.geom.Sphere;

private {
	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.Algebra;
	import xf.omg.core.Misc;
	import xf.omg.rt.Common;
}



struct SphereT(flt) {
	alias Vector!(flt, 3)	vec3;
	
	vec3	origin;
	
	private {
		flt r_;
		flt r2_;
	}
	
	
	flt radius() {
		assert (ok);
		return r_;
	}
	
	
	void radius(flt r) {
		this.r_ = r;
		this.r2_ = r * r;
	}
	

	flt sqRadius() {
		assert (ok);
		return r2_;
	}	
	
	
	bool ok() {
		return origin.ok && !isNaN(r_) && !isNaN(r2_);
	}
	alias ok isOK;
	alias ok isCorrect;
	
	
	static SphereT opCall(vec3 o, flt r) {
		SphereT res = void;
		res.origin = o;
		res.radius = r;
		assert (res.ok);
		return res;
	}


	bool intersect(ref RayT!(flt) ray, ref HitT!(flt) hit, IntersectFlags flags = IntersectFlags.Default) {
		assert (ok);
		
		// TODO: more fuzzy unit checking
		//assert (ray.direction.isUnit);

		vec3 dst = ray.origin - origin;
		flt B = dot(dst, ray.direction);
		flt C = dot(dst, dst) - r2_;
		flt D = B*B - C;
		
		if (D < cscalar!(flt, 0)) {
			return false;
		}
		
		flt sqrtD = scalar!(flt)(sqrt(cast(real)D));
		flt t0 = -(B + sqrtD);
		// t1 = -B + sqrtD;
		
		if (t0>= cscalar!(flt, 0) && t0 < hit.distance) {
			hit.distance = t0;
			if (flags & IntersectFlags.ComputeUV) {
				assert (false, "TODO");
			}
			if (flags & IntersectFlags.ComputeNormal) {
				vec3 n = ray.origin + ray.direction * t0;
				n -= origin;
				hit.normal = n / r_;
			}
		
			return true;
		} else {
			return false;
		}
	}
	
	
	bool contains(vec3 pt) {
		return (pt - origin).sqLength < sqRadius;
	}
}


alias SphereT!(float)	Sphere;