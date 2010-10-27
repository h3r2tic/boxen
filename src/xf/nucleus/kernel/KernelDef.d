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

	void*	_module;	// KDefModule, after semantic analysis
	uint	_firstByte;
	uint	_lengthBytes;


	this(DgAllocator allocator) {
		_dependentOnThis = DepTracker(allocator);
	}


	bool opEquals(KernelDef other) {
		return equal(func, other.func) && superKernel == other.superKernel;
	}


	DepTracker* dependentOnThis() {
		return &_dependentOnThis;
	}

	void invalidate() {
		_dependentOnThis.valid = false;
	}

	bool isValid() {
		return _dependentOnThis.valid;
	}

	bool isConcrete() {
		return cast(Function)func !is null;
	}
}
