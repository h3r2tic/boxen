module xf.mem.ScratchAlloc;

private {
	import xf.Common;
}


template MScratchAlloc() {
	T[] allocArray(T)(size_t len, bool throwExc = true) {
		auto res = allocArrayNoInit!(T)(len, throwExc);
		if (res) {
			res[] = T.init;
		}
		return res;
	}
	

	T[] allocArrayNoInit(T)(size_t len, bool throwExc = true) {
		size_t size = len * T.sizeof;
		return (cast(T*)this.allocRaw(size, throwExc))[0..len];
	}


	T[] dupArray(T)(T[] arr, bool throwExc = true) {
		final copy = allocArrayNoInit!(T)(arr.length, throwExc);
		copy[] = arr;
		return copy;
	}

	alias dupArray!(char) dupString;


	char[] dupStringz(char[] arr, bool throwExc = true) {
		final copy = allocArrayNoInit!(char)(arr.length+1, throwExc)[0..$-1];
		copy[] = arr;
		copy.ptr[copy.length] = 0;
		return copy;
	}


	void* allocRaw(size_t bytes) {		// throws
		return this.allocRaw(bytes, true);
	}
}


struct DgScratchAlloc {
	void* delegate(uword)	_allocator;

	void* allocRaw(size_t bytes, bool throwExc) {
		void* res = _allocator(bytes);
		if (res is null && throwExc) {
			throw new Exception("DgScratchAlloc: _allocator returned null.");
		} else {
			return res;
		}
	}

	mixin MScratchAlloc;
}


struct PoolScratchAlloc {
	void[] _pool;

	void* allocRaw(size_t bytes, bool throwExc) {
		if (bytes <= _pool.length) {
			void* res = _pool.ptr;
			_pool = _pool[bytes..$];
			return res;
		} else if (throwExc) {
			throw new Exception("PoolScratchAlloc: ran out of pool space.");
		} else {
			return null;
		}
	}

	bool isFull() {
		return 0 == _pool.length;
	}

	mixin MScratchAlloc;
}
