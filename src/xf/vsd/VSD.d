module xf.vsd.VSD;

private {
	import xf.omg.core.CoordSys;
	import xf.omg.core.LinearAlgebra;
	import xf.utils.BitSet;
}



struct VisibleObject {
	uint	id;
}


struct ViewSettings {
	// TODO
}


struct VSDRoot {
	// rebuild structures and whatnot
	void update() {
		assert (false, "TODO");
	}

	void findVisible(ViewSettings, void delegate(VisibleObject[]) sink) {
		assert (false, "TODO");
	}


	void createObject(uint id) {
		assert (false, "TODO");
	}

	void disposeObject(uint id) {
		assert (false, "TODO");
	}

	void invalidateObject(uint id) {
		assert (false, "TODO");
	}


	void enableObject(uint id) {
		assert (false, "TODO");
	}

	void disableObject(uint id) {
		assert (false, "TODO");
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
