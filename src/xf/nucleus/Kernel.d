module xf.nucleus.Kernel;

private {
	import xf.Common;
}


alias uhword KernelVersion;


struct KernelRef {
	static KernelRef opCall(cstring name, KernelProvider prov) {
		KernelRef res;
		assert (name.length <= uhword.max);
		res._namePtr = name.ptr;
		res._nameLen = cast(uhword)name.length;
		res._provider = prov;
		return res;
	}


	cstring name() {
		return _namePtr[0.._nameLen];
	}


	Kernel* get() {
		if (_provider !is null) {
			final pv = _provider.kernelProviderVersion;
			if (pv == _ver && _cached) {
				return _cached;
			} else {
				_ver = pv;
				return _cached = _provider.getKernel(name);
			}
		} else {
			return null;
		}
	}
	alias get opCall;
	

	private {
		KernelProvider	_provider;
		Kernel*			_cached;
		char*			_namePtr;
		uhword			_nameLen;
		KernelVersion	_ver = KernelVersion.max;
	}
}

static assert (uword.sizeof * 4 == KernelRef.sizeof);


struct Kernel {
	// actual kernel stuff here
}


interface KernelProvider {
	Kernel*			getKernel(cstring name);
	KernelVersion	kernelProviderVersion();
}
