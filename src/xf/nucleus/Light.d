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
	CoordSys	transform;

	abstract cstring kernelName();
	abstract void setKernelData(KernelParamInterface);
	abstract void determineInfluenced(
		void delegate(
			bool delegate(
				ref CoordSys	cs,
				ref vec3		localHalfSize
			)
		) objectIter
	);
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
