module xf.mem.Array;

private {
	import xf.mem.ArrayAllocator;
	import xf.mem.Log;
}


private template MArrCommon(T) {
	T popBack() {
		assert (_length > 0);
		return _ptr[--_length];
	}


	void clear() {
		_length = 0;
	}
	
	
	void opIndexAssign(T x, size_t i) {
		assert (i < _length);
		_ptr[i] = x;
	}
	

	T* opIndex(size_t i) {
		assert (i < _length);
		assert (_ptr !is null);
		return _ptr + i;
	}


	size_t indexOf(T* item) {
		size_t res = 0;
		return
			(item >= _ptr && (res = item - _ptr) < _length)
			? res
			: _length;
	}
	
	
	int opApply(int delegate(ref T) dg) {
		if (_ptr is null) {
			return 0;
		}
		
		T* end = _ptr + _length;
		for (T* it = _ptr; it < end; ++it) {
			if (auto r = dg(*it)) {
				return r;
			}
		}
		
		return 0;
	}
	

	int opApply(int delegate(ref int i, ref T) dg) {
		if (_ptr is null) {
			return 0;
		}
		
		T* end = _ptr + _length;
		int i = 0;
		for (T* it = _ptr; it < end; ++it, ++i) {
			if (auto r = dg(i, *it)) {
				return r;
			}
		}
		
		return 0;
	}


	void removeKeepOrder(size_t i) {
		assert (i < _length);
		for (; i+1 < _length; ++i) {
			_ptr[i] = _ptr[i+1];
		}
		--_length;
	}


	void removeKeepOrder(bool delegate(ref T) filter) {
		size_t dst = 0;
		for (size_t src = 0; src < _length; ++src) {
			if (!filter(_ptr[src])) {
				if (src != dst) {
					_ptr[dst++] = _ptr[src];
				} else {
					++dst;
				}
			}
		}
		_length = dst;
	}


	void removeNoOrder(size_t idx) {
		assert (idx < _length);
		if (idx != _length-1) {
			_ptr[idx] = _ptr[_length-1];
		}
		--_length;
	}


	T* opIn_r(T item) {
		foreach (ref x; _ptr[0.._length]) {
			if (x == item) {
				return &x;
			}
		}
		return null;
	}
	
	
	size_t length() {
		return _length;
	}
	
	
	T* ptr() {
		return _ptr;
	}


	T[] data() {
		return _ptr[0.._length];
	}


	size_t capacity() {
		return _capacity;
	}

	
	private {
		T*		_ptr = null;
		size_t	_length = 0;
		size_t	_capacity = 0;
	}
}


struct Array(
		T,
		alias ExpandPolicy = ArrayExpandPolicy.FixedAmount!(64),
		alias Allocator = ArrayAllocator.MainHeap
) {
	mixin Allocator;
	mixin ExpandPolicy;
	
	
	size_t pushBack(T x) {
		size_t res = _length;
		if (_length < _capacity) {
			_ptr[_length++] = x;
		} else {
			_expand(1U);
			_ptr = cast(T*)_reallocate(_ptr, 0, _length * T.sizeof, _capacity * T.sizeof);
			_ptr[_length++] = x;
		}
		return res;
	}


	size_t append(T[] x) {
		size_t res = _length;
		size_t xlen = x.length;
		if (_length + xlen <= _capacity) {
			_ptr[_length .. _length+xlen] = x;
			_length += xlen;
		} else {
			_expand(xlen);
			_ptr = cast(T*)_reallocate(_ptr, 0, _length * T.sizeof, _capacity * T.sizeof);
			_ptr[_length .. _length+xlen] = x;
			_length += xlen;
		}
		return res;
	}


	size_t growBy(uint num) {
		size_t res = _length;
		resize(res + num);
		return res;
	}
	
	
	void reserve(size_t num) {
		if (num > _capacity) {
			_expand(num - _capacity);
			_ptr = cast(T*)_reallocate(_ptr, 0, _length * T.sizeof, _capacity * T.sizeof);
		}
	}
	
	
	void resize(size_t num) {
		if (num > 0) {
			reserve(num);
			if (num > _length) {
				initElements(_length, num);
			}
		}
		
		_length = num;
		
		if (num > 0) {
			assert (_ptr !is null);
		}
	}
	
	
	private void initElements(size_t start, size_t end) {
		_ptr[start..end] = T.init;
	}
	
	
	void dispose() {
		_dispose(_ptr);
		_length = _capacity = 0;
	}


	mixin MArrCommon!(T);
}



struct FixedArray(T) {
	static FixedArray opCall(T[] arr) {
		FixedArray res = void;
		res._ptr = arr.ptr;
		res._length = 0;
		res._capacity = arr.length;
		return res;
	}

	
	size_t pushBack(T x) {
		size_t res = _length;
		if (_length < _capacity) {
			_ptr[_length++] = x;
		} else {
			memError("FixedArray overflow (cap={}).", _capacity);
			assert (false);
		}
		return res;
	}


	size_t append(T[] x) {
		size_t res = _length;
		size_t xlen = x.length;
		if (_length + xlen <= _capacity) {
			_ptr[_length .. _length+xlen] = x;
			_length += xlen;
		} else {
			memError("FixedArray overflow (cap={}, len={}, arg={}).", _capacity, _length, xlen);
			assert (false);
		}
		return res;
	}


	mixin MArrCommon!(T);
}
