module xf.vsd.VSD;

private {
	import xf.omg.core.CoordSys;
	import xf.omg.core.LinearAlgebra;
	import xf.omg.util.ViewSettings;
	import xf.omg.geom.Frustum;
	import xf.omg.geom.Sphere;
	import xf.omg.core.Misc;
	import xf.utils.BitSet;
}



struct VisibleObject {
	uint	id;
}


struct VSDRoot {
	// rebuild structures and whatnot
	void update() {
		// TODO
	}

	// HACK
	void findVisible(ViewSettings vs, void delegate(VisibleObject[]) sink) {
		Frustum frustum = vs.computeFrustum();

		// TODO: optimize
		size_t num = enabledFlags.length;
		for (size_t id = 0; id < num; ++id) {
			if (enabledFlags.isSet(id)){
				// sphere culling is TMP

				vec3 hs = localHalfSizes[id];
				
				Sphere sph = Sphere(
					vec3.from(transforms[id].origin),
					sqrt(dot(hs, hs))
				);

				if (frustum.contains(sph)) {
					VisibleObject vo;
					vo.id = cast(uint)id;
					sink((&vo)[0..1]);
				}
			}
		}
	}


	void createObject(uint id) {
		// TODO
		enabledFlags.alloc(id+1);
		enabledFlags.set(id);
	}

	void disposeObject(uint id) {
		assert (false, "TODO");
	}

	void invalidateObject(uint id) {
		// TODO
	}


	void enableObject(uint id) {
		// TODO
	}

	void disableObject(uint id) {
		// TODO
	}


	/// To be maintained by the user
	CoordSys[]		transforms;

	/// ditto
	vec3[]			localHalfSizes;

	/// ditto
	DynamicBitSet	enabledFlags;

	/// ditto
	// Should be set to true when an object moved or got added. In debug mode the impls
	// should probably check whether the user did just that, so that when later more
	// fancy VSD is added, it doesn't suddendly fall apart because nothing did the
	// invalidation
	DynamicBitSet	invalidationFlags;
}
