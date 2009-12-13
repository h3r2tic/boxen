module xf.omg.geom.Plane;

private {
	import xf.omg.core.LinearAlgebra : Vector, dot;
	import xf.omg.core.Algebra;
	import xf.omg.rt.Common;
}



struct PlaneT(flt) {
	alias Vector!(flt, 3) vec3;
	
	union {
		struct {
			flt a, b, c;
		}
		
		vec3 normal;
	}
	
	flt d;
	
	
	bool ok() {
		return normal.ok && !isNaN(d);
	}
	alias ok isOK;
	alias ok isCorrect;
	
	
	static PlaneT opCall(flt a, flt b, flt c, flt d) {
		PlaneT res = void;
		res.a = a;
		res.b = b;
		res.c = c;
		res.d = d;
		assert (res.ok);
		return res;
	}


	static PlaneT opCall(vec3 normal, flt d) {
		PlaneT res = void;
		res.normal = normal;
		res.d = d;
		assert (res.ok);
		return res;
	}
	
	
	static PlaneT fromNormalPoint(vec3 normal, vec3 point) {
		assert (normal.isUnit());
		assert (point.ok);
		PlaneT res = void;
		res.normal = normal;
		res.d = -dot(normal, point);
		return res;
	}
	
	
	flt dist(ref vec3 pt) {
		assert (ok);
		return dot(pt, normal) + d;
	}
	
	
	// TODO: remove the 'dist' version
	alias dist distance;
	

	vec3 point() {
		assert (ok);
		return normal * -d;
	}
	
	
	bool intersect(ref RayT!(flt) ray, ref HitT!(flt) hit, IntersectFlags flags = IntersectFlags.Default) {
		flt dist = this.dist(ray.origin) / -dot(ray.direction, this.normal);
		if (dist >= cscalar!(flt, 0) && dist < hit.distance) {
			hit.distance = dist;
			if (flags & IntersectFlags.ComputeUV) {
				static int mod3[4] = [0, 1, 2, 0];
				int i = this.normal.dominatingAxis();
				i = mod3[++i];
				hit.u = ray.origin.cell[i] + ray.direction.cell[i] * dist;
				i = mod3[++i];
				hit.v = ray.origin.cell[i] + ray.direction.cell[i] * dist;
			}
			if (flags & IntersectFlags.ComputeNormal) {
				hit.normal = this.normal;
			}
			return true;
		} else {
			return false;
		}
	}
	
	
	vec3 reflect(ref vec3 v) {
		return v + this.normal * (dot(v, this.normal) * cscalar!(flt, -2));
	}
}


alias PlaneT!(float)		Plane;
alias PlaneT!(double)	Planed;
