module xf.omg.geom.Triangle;

private {
	import xf.omg.core.LinearAlgebra : vec3, dot, cross;
}



/// Single sided ray intersection
bool intersectTriangle(vec3[] vertices, vec3 orig, vec3 dir, ref float t) {
	const float EPSILON = 0.0001f;
	
	/+ find vectors for two edges sharing vert0 +/
	vec3 edge1 = vertices[1] - vertices[0];
	vec3 edge2 = vertices[2] - vertices[0];
	
	/+ begin calculating determinant - also used to calculate U parameter +/
	vec3 pvec = cross(dir, edge2);
	
	/+ if determinant is near zero, ray lies in plane of triangle +/
	float det = dot(edge1, pvec);
	
	if (det < EPSILON) return false;
	
	/+ calculate distance from vert0 to ray origin +/
	vec3 tvec = orig - vertices[0];
	
	/+ calculate U parameter and test bounds +/
	float u = dot(tvec, pvec);
	if (u < 0 || u > det) return false;
	
	/+ prepare to test V parameter +/
	vec3 qvec = cross(tvec, edge1);
	
	/+ calculate V parameter and test bounds +/
	float v = dot(dir, qvec);
	if (v < -EPSILON || u + v > det + EPSILON) return false;
	
	/+ calculate t, scale parameters, ray intersects triangle +/
	float t_ = dot(edge2, qvec) / det;
	if (t_ <= 0 || t_ >= t) return false;
	
	t = t_;
	return true;
}
