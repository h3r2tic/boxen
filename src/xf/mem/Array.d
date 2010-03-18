module xf.mem.Array;



interface ArrayExpandPolicy {
	template FixedAmount(int count) {
		template FixedAmount(int _count = count) {
			void _expand(size_t num) {
				if (num < _count) {
					_capacity += _count;
				} else {
					_capacity += (num + _count - 1) / _count * _count;
				}
				
				_reallocate();
			}
		}
	}

	template Exponential(int _mult) {
		static assert (false, `TODO`);
	}
}


interface ArrayAllocator {
	template MainHeap() {
		private static import xf.mem.MainHeap;


		void _reallocate() {
			assert (_capacity != 0);
			_ptr = cast(T*)xf.mem.MainHeap.mainHeap.reallocRaw(_ptr, _capacity * T.sizeof);
			assert (_ptr !is null);
		}
		
		void _dispose() {
			xf.mem.MainHeap.mainHeap.freeRaw(_ptr);
			_length = _capacity = 0;
		}
	}
}


struct Array(
		T,
		alias ExpandPolicy = ArrayExpandPolicy.FixedAmount!(64),
		alias Allocator = ArrayAllocator.MainHeap
) {
	mixin Allocator;
	mixin ExpandPolicy;
	
	
	void pushBack(T x) {
		if (_length < _capacity) {
			_ptr[_length++] = x;
		} else {
			_expand(1U);
			_ptr[_length++] = x;
		}
	}
	alias pushBack opCatAssign;
	
	
	T popBack() {
		assert (_length > 0);
		return _ptr[--_length];
	}
	
	
	void reserve(size_t num) {
		if (num > _capacity) {
			_expand(num - _capacity);
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
		_dispose();
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
