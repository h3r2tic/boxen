module xf.nucleus.Light;

private {
	import xf.Common;
	import xf.nucleus.Defs;
	import xf.nucleus.KernelParamInterface;
	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.CoordSys;
	import xf.mem.MultiArray;
	import xf.mem.Array;
	import xf.mem.ArrayAllocator;
}



abstract class Light {
	vec3	position = { x: 0, y: 1, z: 2 };
	vec4	lumIntens = vec4.one;		// uh oh, luminous intensity
	float	influenceRadius = 0;
	LightId	_id;

	void	calcInfluenceRadius() {
		// cuts off at 0.01 luma assuming 1/r2 attenuation
		float meh = dot(vec4(0.2126, 0.7152, 0.0722, 0), lumIntens) * 100.0f + 0.5;
		influenceRadius = meh <= 0 ? 0 : sqrt(meh);
	}

	abstract cstring kernelName();
	abstract void setKernelData(KernelParamInterface);

	// Called by renderer prior to using the light. Can e.g. calc shadow maps
	// TODO: replace it with a version which runs on all instances of a given
	// light class as to allow clustering and reduce call overhead
	void prepareRenderData() {}

	void determineInfluenced(
		void delegate(
			bool delegate(
				ref CoordSys	cs,
				ref vec3		localHalfSize
			)
		) objectIter
	) {
		objectIter((
				ref CoordSys	cs,
				ref vec3		localHalfSize
			) {
				return true;
			}
		);
	}
}


Light[] lights;


interface ILightObserver {
	void onLightCreated(LightId);
	void onLightDisposed(LightId);
	void onLightInvalidated(LightId);
}


LightId createLight(Light l) {
	LightId res = void;
	
	if (_lightIdPool.length > 0) {
		res = _lightIdPool.popBack();
	} else {
		res = cast(LightId)lights.length;
		lights.length = lights.length + 1;
	}

	lights[res] = l;
	l._id = res;

	foreach (o; _lightObservers) {
		o.onLightCreated(res);
	}

	return res;
}


void disposeLight(LightId r) {
	foreach (o; _lightObservers) {
		o.onLightDisposed(r);
	}

	lights[r] = null;

	_lightIdPool.pushBack(r);
}


void invalidateLight(LightId id) {
	// TODO: make sure the id is correct
	
	foreach (o; _lightObservers) {
		o.onLightInvalidated(id);
	}
}


void registerLightObserver(ILightObserver o) {
	_lightObservers ~= o;
}


private {
	ILightObserver[] _lightObservers;
	Array!(
		LightId,
		ArrayExpandPolicy.FixedAmount!(1024)
	)	_lightIdPool;
}
