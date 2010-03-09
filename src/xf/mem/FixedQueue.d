module xf.mem.FixedQueue;

private {
	import xf.mem.Log : error = memError;
}



private template MFixedQueue() {
	bool empty() {
		return head is tail;
	}


	T* pushBack() {
		final res = tail;

		tail += itemSize;
		
		if (tail is dataEnd) {
			// wrap around
			tail = data;
		}

		if (head is tail) {
			error("Fixed queue overflow.");
		}

		return cast(T*)res;
	}


	T* popFront() {
		if (empty) {
			error("Fixed queue underflow.");
		}

		final res = head;

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
				error(
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
					error(
						"Fixed queue out of bounds (indexing {} items to the right)",
						(ptr - tail) / itemSize
					);
					assert (false);
				}
			}
			
			return cast(T*)ptr;
		} else {
			error("Trying to index an empty queue (with {}).", i);
			assert (false);
		}
	}


	size_t capacity() {
		return (dataEnd - data) / itemSize;
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
		RawFixedQueue res;
		res.itemSize = itemSize;
		res.data = data.ptr;
		res.dataEnd = data.ptr + (data.length / itemSize) * itemSize;
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
		FixedQueue res;
		res.data = data.ptr;
		res.dataEnd = data.ptr + (data.length / itemSize) * itemSize;
		assert (res.data < res.dataEnd);
		return res;
	}


	private {
		const itemSize = T.sizeof;
	}


	mixin MFixedQueue;
}
