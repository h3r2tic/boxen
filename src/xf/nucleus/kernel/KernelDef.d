module xf.nucleus.kernel.KernelDef;

private {
	import xf.Common;
	import xf.nucleus.Function;
	import xf.nucleus.DepTracker;
}



final class KernelDef {
	AbstractFunction	func;
	cstring				superKernel;
	private DepTracker	_dependentOnThis;

	this(DgAllocator allocator) {
		_dependentOnThis = DepTracker(allocator);
	}


	bool opEquals(KernelDef other) {
		return equal(func, other.func) && superKernel == other.superKernel;
	}


	void invalidateIfDifferent(KernelDef other) {
		if (!opEquals(other)) {
			dependentOnThis.valid = false;
		}
	}


	DepTracker* dependentOnThis() {
		return &_dependentOnThis;
	}

	bool isConcrete() {
		return cast(Function)func !is null;
	}
}
