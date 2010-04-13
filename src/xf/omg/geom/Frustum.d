module xf.omg.geom.Frustum;

private {
	import xf.Common;
	import xf.omg.core.LinearAlgebra;
	import xf.omg.geom.Plane;
	import xf.omg.geom.Sphere;
}



struct Frustum {
	/// @mat = projection * view matrix
	void construct(mat4 mat, vec3 origin, bool nearPlane = false, bool farPlane = false) {
		remPlanes();
		
		// left plane
		addPlane(Plane(mat.getRC(3,0)+mat.getRC(0,0), mat.getRC(3,1)+mat.getRC(0,1), mat.getRC(3,2)+mat.getRC(0,2), mat.getRC(3,3)+mat.getRC(0,3)));
		
		// right plane
		addPlane(Plane(mat.getRC(3,0)-mat.getRC(0,0), mat.getRC(3,1)-mat.getRC(0,1), mat.getRC(3,2)-mat.getRC(0,2), mat.getRC(3,3)-mat.getRC(0,3)));
		
		// top plane
		addPlane(Plane(mat.getRC(3,0)-mat.getRC(1,0), mat.getRC(3,1)-mat.getRC(1,1), mat.getRC(3,2)-mat.getRC(1,2), mat.getRC(3,3)-mat.getRC(1,3)));
		
		// bottom plane
		addPlane(Plane(mat.getRC(3,0)+mat.getRC(1,0), mat.getRC(3,1)+mat.getRC(1,1), mat.getRC(3,2)+mat.getRC(1,2), mat.getRC(3,3)+mat.getRC(1,3)));

		// near plane
		if (nearPlane) {
			addPlane(Plane(mat.getRC(3,0)+mat.getRC(2,0), mat.getRC(3,1)+mat.getRC(2,1), mat.getRC(3,2)+mat.getRC(2,2), mat.getRC(3,3)+mat.getRC(2,3)));
		}
		
		// far plane
		if (farPlane) {
			addPlane(Plane(mat.getRC(3,0)-mat.getRC(2,0), mat.getRC(3,1)-mat.getRC(2,1), mat.getRC(3,2)-mat.getRC(2,2), mat.getRC(3,3)-mat.getRC(2,3)));
		}
		
		// camera position
		_origin = origin;
	}


	void setOrigin(vec3 o) {
		_origin = o;
	}
	
	
	void addPlane(Plane p) {
		p.normalize();
		_planes[_numPlanes++] = p;
	}
	
	
	void remPlanes() {
		_numPlanes = 0;
	}
	
	
	Plane[] planes() {
		return _planes[0.._numPlanes];
	}
	
	
	void dispose() {}
	
	
	void biasPlanes(float value) {
		foreach (ref p; planes) {
			p.d -= value;
		}
	}
	

	// TODO
/+	void transform(mat4 x) {

		foreach (ref p; planes) {
			p.transform(x);
		}
		
		origin = x * origin;
*/
	}+/

	
	Frustum dup() {
		Frustum res;
		res._origin = _origin;
		res._planes[] = _planes;
		res._numPlanes = _numPlanes;
		return res;
	}
	
	
	bool contains(Sphere sphere) {
		float sphereRadius = sphere.radius();
		
		foreach (ref plane; planes) {
			float oDist = plane.distance(sphere.origin);
			if (oDist < -sphereRadius) {
				return false;
			}
		}
		
		return true;
	}
	
	
	private {
		// TODO: more fancy frusta (?)
		Plane[6]	_planes;
		uword		_numPlanes;
		vec3		_origin = {x: 0, y: 0, z: 0};
	}
}



/+struct MultiFrustum {
	void addFrustum(Frustum f) {
		/+if (frusta_.length == numFrusta) {
			allocMore();
		}
		
		Frustum* newF = &frusta_[numFrusta++];
		newF.remPlanes();
		foreach (Plane p; f.planes) {
			newF.addPlane(p);
		}
		newF.origin = f.origin;+/
		TODO
	}
	
	
	void remFrusta() {
		//numFrusta = 0;
		TODO
	}
	

	Frustum[] frusta() {
		//return frusta_[0 .. numFrusta];
		TODO
	}


	uint clip(Polygon poly, inout Polygon[] result)
	{
		assert (result is null);
		Alloc!(Polygon)(result, numFrusta);
		
		uint clippedOut = 0;
		
		foreach (uint i, Frustum f; frusta) {
			result[i] = poly.dup;
			if (Polygon.Classify.BACK == f.clip(result[i])) {
				++clippedOut;
			}
		}
		
		poly.destroy();
		
		uint res = result.length - clippedOut;
		if (0 == res) {
			Free!(Polygon)(result);
		}
		
		return res;
	}


	/+void transform(xform x)
	{
		foreach (inout Frustum f; frusta) {
			f.transform(x);
		}
	}+/
	
	
	void transform(mat4 x) {
		foreach (ref f; frusta) {
			f.transform(x);
		}
	}
	
	
	MultiFrustum dup() {
		TODO
	}
	
	
	bool inside(vec3[] hull) {
		foreach (ref f; frusta) {
			if (f.inside(hull)) {
				return true;
			}
		}
		
		return false;
	}

	
	private {
		Frustum[]	frusta_;
		vec3			origin = {x: 0, y: 0, z: 0};
	}
}
+/
