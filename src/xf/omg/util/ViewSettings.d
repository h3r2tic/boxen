module xf.omg.util.ViewSettings;

private {
	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.CoordSys;
	import xf.omg.geom.Frustum;
}



struct ViewSettings {
	CoordSys	eyeCS;
	float		verticalFOV;		// in Degrees; _not_ half of the FOV
	float		aspectRatio;
	float		nearPlaneDistance;
	float		farPlaneDistance;


	mat4 computeProjectionMatrix() {
		return mat4.perspective(
			verticalFOV,
			aspectRatio,
			nearPlaneDistance,
			farPlaneDistance
		);
	}


	mat4 computeViewMatrix() {
		return eyeCS.inverse.toMatrix();
	}


	Frustum computeFrustum() {
		Frustum res;
		mat4 viewProj = computeProjectionMatrix * computeViewMatrix;
		res.construct(
			viewProj,
			vec3.from(eyeCS.origin),
			true,
			true
		);
		return res;
	}
}
