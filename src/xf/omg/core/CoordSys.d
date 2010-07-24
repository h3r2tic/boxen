module xf.omg.core.CoordSys;

private {
	import xf.omg.core.LinearAlgebra;
}



/**
	The usage of vec3fi (fixed - based) instead of vec3 (float - based) yields two advantages:
	1. uniform resolution across the whole space
	2. higher precission even than using doubles because CoordSys only uses 'fixed-safe' operations which don't overflow under normal circumstances
*/
struct CoordSys {
	vec3fi	origin;
	quat	rotation;
	
	static const CoordSys identity = { origin: vec3fi.zero, rotation: quat.identity };


	static CoordSys opCall(vec3fi origin) {
		CoordSys res = void;
		res.origin = origin;
		res.rotation = quat.identity;
		return res;
	}
	
	
	static CoordSys opCall(vec3fi origin, quat rotation) {
		CoordSys res = void;
		res.origin = origin;
		res.rotation = rotation;
		return res;
	}
	

	static CoordSys fromMatrix(T)(T matrix) {
		return CoordSys(
			vec3fi.from(matrix.getTranslation()),
			quat(matrix.getRotation())
		);
	}

	alias fromMatrix!(mat3)		opCall;
	alias fromMatrix!(mat34)	opCall;
	alias fromMatrix!(mat4)		opCall;
	
	
	CoordSys opIn(CoordSys reference) {
		CoordSys res = void;
		res.origin = reference.origin;
		res.origin += reference.rotation.xform(this.origin);
		res.rotation = reference.rotation * this.rotation;
		res.rotation.normalize();
		return res;
	}


	CoordSys quickIn(CoordSys reference) {
		CoordSys res = void;
		res.origin = reference.origin;
		res.origin += reference.rotation.xform(this.origin);
		res.rotation = reference.rotation * this.rotation;
		return res;
	}
	
	
	CoordSys deltaFrom(CoordSys from) {
		return *this in from.inverse;
	}


	vec3 opIn_r(vec3 v) {
		return rotation.xform(v) + vec3.from(origin);
	}


	vec3fi opIn_r(vec3fi v) {
		return rotation.xform(v) + origin;
	}
	
	
	quat opIn_r(quat q) {
		return rotation * q;
	}
	
	
	CoordSys worldToLocal(CoordSys global) {
		CoordSys inv = *this;
		inv.invert();
		return global in inv;
	}


	void invert() {
		rotation.invert();
		origin = rotation.xform(-origin);
	}
	
	
	CoordSys inverse() {
		CoordSys res = *this;
		res.invert();
		return res;
	}


	mat4 toMatrix() {
		mat4 res = rotation.toMatrix!(4, 4)();
		res.setTranslation(vec3.from(this.origin));
		return res;
	}
	
	mat34 toMatrix34() {
		mat34 res = rotation.toMatrix!(3, 4)();
		res.setTranslation(vec3.from(this.origin));
		return res;
	}

	char[] toString(){
		return "{" ~ origin.toString ~ ";" ~ rotation.toString ~ "}";
	}
}
