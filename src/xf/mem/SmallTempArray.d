module xf.mem.SmallTempArray;



template MSmallTempArray(T) {
	enum { GrowBy = 8 }
	
	T[] items() {
		return _items[0.._length];
	}

	ushort length() {
		return _length;
	}

	void pushBack(T item, DgAllocator mem) {
		if (_length < _capacity) {
			_items[_length++] = item;
		} else {
			_capacity += GrowBy;
			assert (_capacity > _length);
			T* nitems = cast(T*)mem(_capacity * T.sizeof);
			nitems[0.._length] = _items[0.._length];
			nitems[_length++] = item;
			nitems[_length.._capacity] = T.init;
			_items = nitems;
		}
	}

	void remove(T* item) {
		assert (_length > 0);
		assert (item >= _items && item < _items + _length);
		ushort idx = cast(ushort)(item - _items);
		if (idx != _length-1) {
			_items[idx] = _items[_length-1];
		}
		_items[_length-1] = T.init;
		--_length;
	}

	void removeMatching(bool delegate(T) pred) {
		ushort dst = 0;
		for (ushort src = 0; src < _length; ++src) {
			if (!pred(_items[src])) {
				if (dst != src) {
					_items[dst] = _items[src];
				}
				++dst;
			}
		}

		assert (dst <= _length);

		_items[dst.._length] = T.init;
		_length = dst;
	}

	void alloc(ushort num, DgAllocator mem) {
		if (num > 0) {
			_capacity = cast(ushort)(((num + cast(ushort)(GrowBy-1)) / GrowBy) * GrowBy);
			_items = cast(T*)mem(_capacity * T.sizeof);
			assert (_items !is null);
			_length = num;
			_items[0.._capacity] = T.init;
		} else {
			_items = null;
			_length = 0;
			_capacity = 0;
		}
	}

	void clear() {
		_length = 0;
	}
	

	T*		_items;
	ushort	_length;
	ushort	_capacity;
}
