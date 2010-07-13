module xf.mem.ScratchAllocator;

private {
	import xf.Common;
	import xf.mem.Log;
}


private template Ref(T) {
	static if (is(T == class)) {
		alias T Ref;
	} else {
		alias T* Ref;
	}
}


template MScratchAllocator() {
	T[] allocArray(T)(size_t len, bool throwExc = true) {
		auto res = allocArrayNoInit!(T)(len, throwExc);
		if (res) {
			res[] = T.init;
		}
		return res;
	}


	template _new(T) {
		Ref!(T) _new(P...)(P p) {
			static if (is(T == class)) {
				void[] data = dupArray(T.classinfo.init);
				T res = cast(T)data.ptr;
				static if (is(typeof(&res._ctor))) {
					res._ctor(p);
				}
			} else static if (is(T == struct)) {
				T* res = cast(T*)allocRaw(T.sizeof);
				*res = T(p);
			} else {
				T* res = cast(T*)allocRaw(T.sizeof);
				static if (1 == p.length) {
					*res = p[0];
				} else {
					static assert (0 == p.length);
					*res = T.init;
				}
			}
			return res;
		}
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
}


struct DgScratchAllocator {
	void* delegate(uword)	_allocator;

	void* allocRaw(size_t bytes, bool throwExc) {
		void* res = _allocator(bytes);
		if (res is null && bytes > 0 && throwExc) {
			memError("DgScratchAlloc: _allocator returned null when trying to alloc {} bytes.", bytes);
			assert (false);
		} else {
			return res;
		}
	}

	void* allocRaw(size_t bytes) {		// throws
		return this.allocRaw(bytes, true);
	}

	mixin MScratchAllocator;
}


struct PoolScratchAllocator {
	void[] _pool;

	void* allocRaw(size_t bytes, bool throwExc) {
		if (bytes <= _pool.length) {
			void* res = _pool.ptr;
			_pool = _pool[bytes..$];
			return res;
		} else if (throwExc) {
			memError("PoolScratchAllocator: ran out of pool space when trying to alloc {} bytes.", bytes);
			assert (false);
		} else {
			return null;
		}
	}

	void* allocRaw(size_t bytes) {		// throws
		return this.allocRaw(bytes, true);
	}

	bool isFull() {
		return 0 == _pool.length;
	}

	mixin MScratchAllocator;
}
