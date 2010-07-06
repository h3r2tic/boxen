module xf.nucleus.kernel.KernelDef;

private {
	import xf.Common;
	import xf.nucleus.Function;
	import xf.nucleus.DepTracker;
}



class KernelDef {
	AbstractFunction	func;
	cstring				superKernel;
	private DepTracker	_dependentOnThis;

	this(DgAllocator allocator) {
		_dependentOnThis = DepTracker(allocator);
	}


	void invalidateIfDifferent(KernelDef other) {
		if (	func != other.func
			||	superKernel != other.superKernel
		) {
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
