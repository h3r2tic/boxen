module xf.nucled.Intersect;

private {
	import
		xf.Common;
	import
		xf.omg.core.LinearAlgebra,
		xf.omg.geom.Triangle,
		xf.omg.rt.Common;
}



abstract class TrayRacer {
	abstract bool intersect(Ray, Hit*);
}


class MeshTrayRacer : TrayRacer {
	vec3[]	points;
	u32[]	indices;

	this(vec3[] points, u32[] indices) {
		assert (indices.length % 3 == 0);
		this.points = points;
		this.indices = indices;
	}

	override bool intersect(Ray ray, Hit* hit) {
		bool	result = false;
		
		for (int i = 0; i < indices.length; i += 3) {
			vec3[3] p = void;
			p[0] = points[indices[i+0]];
			p[1] = points[indices[i+1]];
			p[2] = points[indices[i+2]];
			
			result |= intersectTriangle(
				p[],
				ray.origin,
				ray.direction,
				hit.distance
			);
		}

		return result;
	}
}
