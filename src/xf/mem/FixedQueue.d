module xf.mem.FixedQueue;

private {
	import xf.mem.Log : memError;
}



// NOTE: this queue sucks. could use some wrap-around.
private template MFixedQueue() {
	bool isEmpty() {
		return head is tail;
	}


	bool isFull() {
		auto t2 = tail + itemSize;
		
		if (t2 is dataEnd) {
			// wrap around
			t2 = data;
		}

		return head is t2;
	}


	T* pushBack() {
		final res = tail;
		assert (res !is null);

		tail += itemSize;
		
		if (tail is dataEnd) {
			// wrap around
			tail = data;
		}

		if (head is tail) {
			memError("Fixed queue overflow.");
		}

		return cast(T*)res;
	}


	T* popFront() {
		if (isEmpty) {
			memError("Fixed queue underflow.");
		}

		final res = head;
		assert (res !is null);

		head += itemSize;
		
		if (head is dataEnd) {
			// wrap around
			head = data;
		}

		return cast(T*)res;
	}


	T* opIndex(size_t i) {
		void* ptr = head + i * itemSize;
		void* ptrEnd = ptr + itemSize;

		if (head < tail) {
			if (ptrEnd > tail) {
				memError(
					"Fixed queue out of bounds (indexing {} items to the right)",
					(ptr - tail) / itemSize
				);
				assert (false);
			} else {
				return cast(T*)ptr;
			}
		} else if (tail < head) {
			if (ptrEnd > dataEnd) {		// wrap around
				final off = data - dataEnd;
				ptr += off;
				ptrEnd += off;
				if (ptrEnd > tail) {
					memError(
						"Fixed queue out of bounds (indexing {} items to the right)",
						(ptr - tail) / itemSize
					);
					assert (false);
				}
			}
			
			return cast(T*)ptr;
		} else {
			memError("Trying to index an empty queue (with {}).", i);
			assert (false);
		}
	}


	size_t capacity() {
		return (dataEnd - data) / itemSize;
	}


	void clear() {
		head = tail = data;
	}


	private {
		void*	head;
		void*	tail;
		void*	data;
		void*	dataEnd;
	}
}


struct RawFixedQueue {
	static RawFixedQueue opCall(size_t itemSize, void[] data) {
		RawFixedQueue res = void;
		res.itemSize = itemSize;
		res.data = data.ptr;
		res.dataEnd = data.ptr + (data.length / itemSize) * itemSize;
		res.head = res.tail = res.data;
		assert (res.data < res.dataEnd);
		return res;
	}


	private {
		alias void	T;
		size_t		itemSize;
	}


	mixin MFixedQueue;
}


struct FixedQueue(T) {
	static FixedQueue opCall(void[] data) {
		FixedQueue res = void;
		res.data = data.ptr;
		res.dataEnd = data.ptr + (data.length / itemSize) * itemSize;
		res.head = res.tail = res.data;
		assert (res.data < res.dataEnd);
		return res;
	}


	static if (!is(T == void)) {
		static FixedQueue opCall(T[] data) {
			FixedQueue res = void;
			res.data = data.ptr;
			res.dataEnd = cast(void*)(data.ptr + data.length);
			res.head = res.tail = res.data;
			assert (res.data < res.dataEnd);
			return res;
		}
	}


	private {
		const itemSize = T.sizeof;
	}


	mixin MFixedQueue;
}
