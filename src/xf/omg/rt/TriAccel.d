module xf.omg.rt.TriAccel;

private {
	import xf.omg.rt.Common;
	import xf.omg.core.LinearAlgebra;	// for vec3
	import tango.math.Math : fabs;
}



struct TriAccel {
	const float EPSILON = 1.0e-6f;
	
	
	bool intersect(ref Ray ray, inout Hit hit) {
		int u = mod3[k + 1];
		int v = mod3[k + 2];

		// don’t prefetch here, assume data has already been prefetched
		// start high-latency division as early as possible
		float nd = 1. / (ray.direction.cell[k] + n_u * ray.direction.cell[u] + n_v * ray.direction.cell[v]);
		float f = (n_d - ray.origin.cell[k] - n_u * ray.origin.cell[u] - n_v * ray.origin.cell[v]) * nd;
		
		// check for valid distance.
		if (!(hit.distance > f && f > EPSILON)) return false;
		
		// compute hitpoint positions on uv plane
		float hu = (ray.origin.cell[u] + f * ray.direction.cell[u]);
		float hv = (ray.origin.cell[v] + f * ray.direction.cell[v]);
		
		// check first barycentric coordinate
		float lambda = (hu * b_nu + hv * b_nv + b_d);
		if (lambda < 0.f) return false;
		
		// check second barycentric coordinate
		float mue = (hu * c_nu + hv * c_nv + c_d);
		if (mue < 0.f) return false;
		
		// check third barycentric coordinate
		if (lambda + mue > 1.f) return false;
		
		// have a valid hitpoint here. store it.
		hit.distance = f;
		hit.u = lambda;
		hit.v = mue;
		hit.primitive = data;
		return true;
	}



	// first 16 byte half cache line
	// plane:
	float n_u;	//!< == normal.u / normal.k
	float n_v;	//!< == normal.v / normal.k
	float n_d;	//!< constant of plane equation
	int k;	// projection dimension
	
	// second 16 byte half cache line
	// line equation for line ac
	float b_nu;
	float b_nv;
	float b_d;
	int nsign;	// pad to next cache line	// sign of normal.k: 0 -> pos, 1 -> neg
	
	// third 16 byte half cache line
	// line equation for line ab
	float c_nu;
	float c_nv;
	float c_d;	
	uint data;	// pad to 48 bytes for cache alignment purposes		// any user data
	
	
	static TriAccel opCall(vec3 A, vec3 B, vec3 C, bool* valid) {
		TriAccel res;

		if (valid !is null) {
			*valid = true;
			*valid &= A.ok;
			*valid &= B.ok;
			*valid &= C.ok;
			assert (*valid);
		}
		
		vec3 N = void;
		{
			vec3	b = C - A;
			vec3 c = B - A;
			N = cross(c, b);
		}

		if (valid !is null) {
			*valid &= N.ok;
			if (!*valid) {
				return res;
			}
		}
		
		float anx = fabs(N.x);
		float any = fabs(N.y);
		float anz = fabs(N.z);
		
		int k;
		if (anx > any) {
			if (anx > anz) k = 0; else k = 2;
		} else {
			if (any > anz) k = 1; else k = 2;
		}

		int u = mod3[k+1];
		int v = mod3[k+2];
		
		float Nscale = (1.f / N.cell[k]);
		if (valid !is null) {
			*valid &= Nscale <>= 0;
			if (!*valid) {
				return res;
			}
		}

		vec3 Nprim = N * Nscale;
		if (valid !is null) {
			*valid &= Nprim.ok;
			if (!*valid) {
				return res;
			}
		}

		res.n_u = Nprim.cell[u];
		res.n_v = Nprim.cell[v];
		res.n_d = dot(A, Nprim);

		if (valid !is null) {
			*valid &= Nprim.ok;
			if (!*valid) {
				return res;
			}
		}
		
		vec2 Aprim = vec2(A.cell[u], A.cell[v]);
		vec2 Bprim = vec2(B.cell[u], B.cell[v]);
		vec2 Cprim = vec2(C.cell[u], C.cell[v]);

		if (valid !is null) {
			*valid &= Aprim.ok;
			*valid &= Bprim.ok;
			*valid &= Cprim.ok;
			if (!*valid) {
				return res;
			}
		}

		vec2 b = Cprim - Aprim;
		vec2 c = Bprim - Aprim;

		{
			float mul = 1.f / (b.x*c.y - b.y*c.x);
			
			res.b_nu = -b.y * mul;
			res.b_nv = b.x * mul;
			res.b_d = (b.y * Aprim.x - b.x * Aprim.y) * mul;

			res.c_nu = c.y * mul;
			res.c_nv = -c.x * mul;
			res.c_d = (c.x * Aprim.y - c.y * Aprim.x) * mul;
		}
		
		res.k = k;
		res.nsign = (N.cell[k] > 0 ? 0 : 1);
		
		return res;
	}


	// lookup table for the modulo operation
	const static uint[5] mod3 = [0, 1, 2, 0, 1];
	
	
	/// Normalized with maths.Utils.invSqrt
	vec3 calcNormal() {
		int u = mod3[k+1];
		int v = mod3[k+2];
		vec3 n;
		
		if (0 == nsign) {
			n.cell[k] = 1.f;
			n.cell[u] = n_u;
			n.cell[v] = n_v;
		} else {
			n.cell[k] = -1.f;
			n.cell[u] = -n_u;
			n.cell[v] = -n_v;
		}
		
		return n * invSqrt(dot(n, n));
	}
	

	/+
		A'.x = (b.x * (c_d / mul) + c.x * (b_d / mul)) / ( c.x * b.y - b.x * c.y )
		A'.y = (b.x * A.x - (b_d / mul)) / b.x
	+/
}


static assert (TriAccel.sizeof % 16 == 0);
