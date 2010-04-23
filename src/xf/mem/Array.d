module xf.mem.Array;

private {
	import xf.mem.ArrayAllocator;
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
			_ptr = cast(T*)_reallocate(_ptr, 0, _length, _capacity * T.sizeof);
			_ptr[_length++] = x;
		}
		return res;
	}


	size_t growBy(uint num) {
		size_t res = _length;
		resize(res + num);
		return res;
	}
	
	
	T popBack() {
		assert (_length > 0);
		return _ptr[--_length];
	}
	
	
	void reserve(size_t num) {
		if (num > _capacity) {
			_expand(num - _capacity);
			_ptr = cast(T*)_reallocate(_ptr, 0, _length, _capacity * T.sizeof);
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

	
	void dispose() {
		_dispose(_ptr);
		_length = _capacity = 0;
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
	
	
	size_t length() {
		return _length;
	}
	
	
	T* ptr() {
		return _ptr;
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
