module xf.mem.ChunkQueue;

private {
	import xf.mem.ChunkCache;
	import xf.mem.ThreadChunkAllocator : _chunkQueueInternalAllocator = threadChunkAllocator;
	import xf.mem.Common;
	import xf.mem.Chunk;
	import xf.mem.Log;
	import tango.stdc.string : memcpy;
}



struct ScratchFIFO {
	const size_t _pageSize = minDefaultPageSize;
	
	private alias _chunkQueueInternalAllocator
		_subAllocator;
		
	private alias chunkCache!(_pageSize - _subAllocator.maxChunkOverhead, _subAllocator)
		_allocator;
		

	private struct QueueChunk {
		QueueChunk*	next;
		size_t		capacity;
		size_t		used;
		void*		lastAddr;

		void*		ptr() {
			return (cast(void*)this) + QueueChunk.sizeof;
		}
	}
	static assert (QueueChunk.sizeof == size_t.sizeof * 4);


	private QueueChunk* allocNewChunk() {
		auto raw = _allocator.alloc();
		assert (raw !is null);
		assert (raw.ptr !is null);
		final chunk = cast(QueueChunk*)raw.ptr;
		chunk.used = 0;
		chunk.capacity = raw.size - QueueChunk.sizeof;
		chunk.next = null;
		return chunk;
	}


	void* pushBack(size_t bytes, size_t alignment = size_t.sizeof) {
		assert (bytes > 0);
		
		QueueChunk*	chunk = void;
		void*		ptr = void;

		if (_tail is null) {
			assert (_head is null);
			
			_head = _tail = chunk = allocNewChunk();
			ptr = alignPointerUp(chunk.ptr(), alignment);

			if (ptr + bytes > chunk.ptr + chunk.capacity) {
				memError(
					"Chunks too small ({}) to allocate {} bytes.",
					chunk.capacity, bytes
				);
			}
		} else {
			assert (_head !is null);
			
			chunk = _tail;
			ptr = alignPointerUp(chunk.ptr() + chunk.used, alignment);
			
			if (ptr + bytes > chunk.ptr + chunk.capacity) {
				chunk = allocNewChunk();
				ptr = alignPointerUp(chunk.ptr(), alignment);
				_tail.next = chunk;
				_tail = chunk;

				if (ptr + bytes > chunk.ptr + chunk.capacity) {
					memError(
						"Chunks too small ({}) to allocate {} bytes.",
						chunk.capacity, bytes
					);
				}
			}
		}

		chunk.lastAddr = ptr;
		chunk.used = ptr + bytes - chunk.ptr;
		return ptr;
	}


	void popFront(void* ptr) {
		assert (ptr !is null);
		assert (_head !is null);

		final ch = _head;
		final chptr = ch.ptr();
		final last = ch.lastAddr;
		if (ptr < chptr || ptr > last) {
			memError(
				"Trying to pop a wrong mem address: {:x}. head.ptr: {:x}, head.last: {:x}.",
				ptr, chptr, last
			);
		}

		if (_lastFreed !is null) {
			if (ptr <= _lastFreed) {
				if (ptr < _lastFreed) {
					memError("Popping an address in a wrong order.");
				} else {
					memError("Double-popping an address.");
				}
			}
		}

		if (last is ptr) {
			_lastFreed = null;		// another chunk, can't be used for linear comparisons
			
			auto cache = &_allocator;
			final QueueChunk* next = ch.next;
			cache.free(Chunk.fromPtr(cast(void*)ch));
			_head = next;

			if (next is null) {
				_tail = null;
			}
		} else {
			_lastFreed = ptr;
		}
	}


	void clear() {
		if (_head) {
			QueueChunk* cur = _head;
			auto cache = &_allocator;
			
			while (cur) {
				QueueChunk* next = cur.next;
				cache.free(Chunk.fromPtr(cast(void*)cur));
				cur = next;
			}
			
			_head = _tail = null;
			_lastFreed = null;
		}
	}


	bool isEmpty() {
		if (_head !is null) {
			assert (_head.used > 0);
		}
		return _head is null;
	}


	/+struct IterateFruct {
		RawChunkQueue	q;
		size_t			itemSize;

		int opApply(int delegate(ref void*) dg) {
			QueueChunk* ch = q._head;
			size_t itemSize = this.itemSize;
			while (ch) {
				void* ptr = ch.ptr();
				size_t cntr = ch.used;
				assert (0 == cntr % itemSize);
				cntr /= itemSize;
				
				for (; cntr--; ptr += itemSize) {
					void* x = ptr;
					if (int r = dg(x)) {
						return r;
					}
				}
				ch = ch.next;
			}

			return 0;
		}
	}
	IterateFruct iterateAssumingFixedSize(size_t itemSize) {
		return IterateFruct(*this, itemSize);
	}+/


	size_t chunkCapacity() {
		return _pageSize - _subAllocator.maxChunkOverhead - QueueChunk.sizeof;
	}


	QueueChunk*	_head;
	QueueChunk*	_tail;
	void*		_lastFreed;
}



/// No alignment guarantees
struct RawChunkDeque {
	const size_t _pageSize = minDefaultPageSize;
	
	private alias _chunkQueueInternalAllocator
		_subAllocator;
		
	alias chunkCache!(_pageSize - _subAllocator.maxChunkOverhead, _subAllocator)
		_allocator;



	static RawChunkDeque opCall(size_t itemSize) {
		RawChunkDeque res;
		res._itemSize = itemSize;
		return res;
	}
		

	private struct QueueChunk {
		size_t	nextXorPrev;
		size_t	capacity;		// bytes
		size_t	head;			// beginning of first item, bytes
		size_t	tail;			// one past end of last item, bytes

		void* ptr() {
			return (cast(void*)this) + QueueChunk.sizeof;
		}
	}
	static assert (QueueChunk.sizeof == size_t.sizeof * 4);


	private QueueChunk* allocNewChunk() {
//		memLog.trace("RawChunkDeque :: requesting a new chunk.");

		auto raw = _allocator.alloc();
		assert (raw !is null);
		assert (raw.ptr !is null);
		final chunk = cast(QueueChunk*)raw.ptr;
		chunk.capacity = raw.size - QueueChunk.sizeof;

		if (_itemSize > chunk.capacity) {
			memError(
				"Chunks too small ({}) to allocate {} bytes.",
				chunk.capacity, _itemSize
			);
		}

		return chunk;
	}


	void* pushBack() {
		assert (_itemSize != 0);
		
		QueueChunk*	chunk = void;

		if (_tail is null) {
			_head = _tail = chunk = allocNewChunk();
			chunk.head = chunk.tail = 0;
			chunk.nextXorPrev = 0;
		} else {
			chunk = _tail;
			
			if (chunk.tail + _itemSize > chunk.capacity) {
				chunk = allocNewChunk();
				chunk.head = chunk.tail = 0;
				_tail.nextXorPrev ^= cast(size_t)chunk;
				chunk.nextXorPrev = cast(size_t)_tail;
				_tail = chunk;
			}
		}

		void* ptr = chunk.ptr() + chunk.tail;
		chunk.tail += _itemSize;
		return ptr;
	}


	void* pushFront() {
		assert (_itemSize != 0);

		QueueChunk*	chunk = void;

		if (_head is null) {
			_head = _tail = chunk = allocNewChunk();
			chunk.head = chunk.tail = chunk.capacity;
			chunk.nextXorPrev = 0;
		} else {
			chunk = _head;
			
			if (chunk.head < _itemSize) {
				chunk = allocNewChunk();
				chunk.head = chunk.tail = chunk.capacity;
				_head.nextXorPrev ^= cast(size_t)chunk;
				chunk.nextXorPrev = cast(size_t)_head;
				_head = chunk;
			}
		}

		chunk.head -= _itemSize;
		return chunk.ptr() + chunk.head;
	}


	void popFront(void* target) {
		final ch = _head;
		if (ch is null) {
			memError("Queue underflow");
		}
		
		memcpy(target, ch.ptr + ch.head, _itemSize);

		ch.head += _itemSize;

		if (ch.head > ch.tail) {
			memError("Queue underflow");
		}

		if (ch.head == ch.tail) {
			final nhead = cast(QueueChunk*)ch.nextXorPrev;
			_head = nhead;
			
			if (nhead is null) {
				_tail = null;
			} else {
				nhead.nextXorPrev ^= cast(size_t)ch;
			}

			auto cache = &_allocator;
//			memLog.trace("RawChunkDeque :: releasing a chunk.");
			cache.free(Chunk.fromPtr(cast(void*)ch));
			_head = nhead;
		}
	}


	void popFront() {
		final ch = _head;
		if (ch is null) {
			memError("Queue underflow");
		}
		
		ch.head += _itemSize;

		if (ch.head > ch.tail) {
			memError("Queue underflow");
		}

		if (ch.head == ch.tail) {
			final nhead = cast(QueueChunk*)ch.nextXorPrev;
			_head = nhead;
			
			if (nhead is null) {
				_tail = null;
			} else {
				nhead.nextXorPrev ^= cast(size_t)ch;
			}

			auto cache = &_allocator;
//			memLog.trace("RawChunkDeque :: releasing a chunk.");
			cache.free(Chunk.fromPtr(cast(void*)ch));
			_head = nhead;
		}
	}


	void popBack(void* target) {
		final ch = _tail;
		if (ch is null || ch.tail < ch.head + _itemSize) {
			memError("Queue underflow");
		}
		
		ch.tail -= _itemSize;
		
		memcpy(target, ch.ptr + ch.tail, _itemSize);

		if (ch.head == ch.tail) {
			final ntail = cast(QueueChunk*)ch.nextXorPrev;
			_tail = ntail;
			
			if (ntail is null) {
				_head = null;
			} else {
				ntail.nextXorPrev ^= cast(size_t)ch;
			}

			auto cache = &_allocator;
//			memLog.trace("RawChunkDeque :: releasing a chunk.");
			cache.free(Chunk.fromPtr(cast(void*)ch));
			_tail = ntail;
		}
	}


	void popBack() {
		final ch = _tail;
		if (ch is null || ch.tail < ch.head + _itemSize) {
			memError("Queue underflow");
		}
		
		ch.tail -= _itemSize;

		if (ch.head == ch.tail) {
			final ntail = cast(QueueChunk*)ch.nextXorPrev;
			_tail = ntail;
			
			if (ntail is null) {
				_head = null;
			} else {
				ntail.nextXorPrev ^= cast(size_t)ch;
			}

			auto cache = &_allocator;
//			memLog.trace("RawChunkDeque :: releasing a chunk.");
			cache.free(Chunk.fromPtr(cast(void*)ch));
			_tail = ntail;
		}
	}


	void* front() {
		assert (!isEmpty());
		return _head.ptr + _head.head;
	}


	void* back() {
		assert (!isEmpty());
		return _tail.ptr + _tail.tail - _itemSize;
	}


	void clear() {
		size_t		prev	= 0;
		QueueChunk*	cur		= _head;
		auto cache = &_allocator;
		
		while (cur) {
			final next = cast(QueueChunk*)(prev ^ cur.nextXorPrev);
			scope (success)	{
				prev = cast(size_t)cur;
				cur = next;
			}

//			memLog.trace("RawChunkDeque :: releasing a chunk.");
			cache.free(Chunk.fromPtr(cast(void*)cur));
		}

		_head = _tail = null;
	}


	void dispose() {
		clear();
	}


	bool isEmpty() {
		if (_head !is null) {
			assert (_head.head != _head.tail);
		}
		return _head is null;
	}


	int opApply(int delegate(ref void*) dg) {
		size_t		prev	= 0;
		QueueChunk*	cur		= _head;
		
		while (cur) {
			final next = cast(QueueChunk*)(prev ^ cur.nextXorPrev);
			scope (success)	{
				prev = cast(size_t)cur;
				cur = next;
			}

			void* ptr = cur.ptr();
			void* last = ptr + cur.tail;
			void* it = null;

			for (it = ptr + cur.head; it < last; it += _itemSize) {
				void* meh = it;
				if (int r = dg(meh)) {
					return r;
				}
			}

			assert (
				it is last,
				"Shit went bananas, someone changed _itemSize"
				" during a RawChunkDeque's life?"
			);
		}

		return 0;
	}


	int opApplyReverse(int delegate(ref void*) dg) {
		size_t		prev	= 0;
		QueueChunk*	cur		= _tail;
		
		while (cur) {
			final next = cast(QueueChunk*)(prev ^ cur.nextXorPrev);
			scope (success)	{
				prev = cast(size_t)cur;
				cur = next;
			}

			void* ptr = cur.ptr();
			void* first = ptr + cur.head;
			void* it = null;

			assert (
				0 == (cur.tail - cur.head) % _itemSize,
				"Shit went bananas, someone changed _itemSize"
				" during a RawChunkDeque's life?"
			);

			assert (cur.head <= cur.tail);

			for (it = ptr + cur.tail; it != first; /+ nothing +/) {
				it -= _itemSize;
				void* meh = it;
				if (int r = dg(meh)) {
					return r;
				}
			}
		}

		return 0;
	}


	private {
		QueueChunk*	_head;
		QueueChunk*	_tail;
		size_t		_itemSize;
	}
}


// TODO: rename ChunkQueue to ThreadLocalChunkQueue and add a version with a global allocator (GlobalChunkQueue)


/**
	An efficient implementation of a queue to which one may only append items and
	iterate over them. Internally it's based on chunked memory allocation from the
	ThreadChunkAllocator and connecting the chunks in a uni-directional linked list.
*/
struct ChunkQueue(T) {
	const size_t _pageSize = minDefaultPageSize;
	
	static assert (T.sizeof <= _pageSize - Chunk.sizeof - 15 - RawChunkDeque.QueueChunk.sizeof);

	RawChunkDeque _impl = {
		_head: null,
		_tail: null,
		_itemSize: T.sizeof
	};

	alias _impl._allocator _allocator;


	void pushBack(T x) {
		*cast(T*)_impl.pushBack() = x;
	}
	
	void pushFront(T x) {
		*cast(T*)_impl.pushBack() = x;
	}


	void popFront(T* x) {
		return _impl.popFront(x);
	}

	void popFront() {
		return _impl.popFront();
	}

	void popBack(T* x) {
		return _impl.popBack(x);
	}

	void popBack() {
		return _impl.popBack();
	}


	T* front() {
		return cast(T*)_impl.front();
	}

	T* back() {
		return cast(T*)_impl.back();
	}


	int opApply(int delegate(ref int, ref T) dg) {
		int i = 0;
		foreach (void* ptr; _impl) {
			if (int r = dg(i, *cast(T*)ptr)) {
				return r;
			}
			++i;
		}
		return 0;
	}

	int opApply(int delegate(ref T) dg) {
		foreach (void* ptr; _impl) {
			if (int r = dg(*cast(T*)ptr)) {
				return r;
			}
		}
		return 0;
	}

	int opApplyReverse(int delegate(ref int, ref T) dg) {
		int i = 0;
		foreach_reverse (void* ptr; _impl) {
			if (int r = dg(i, *cast(T*)ptr)) {
				return r;
			}
			++i;
		}
		return 0;
	}

	int opApplyReverse(int delegate(ref T) dg) {
		foreach_reverse (void* ptr; _impl) {
			if (int r = dg(*cast(T*)ptr)) {
				return r;
			}
		}
		return 0;
	}


	void clear() {
		_impl.clear();
	}

	void dispose() {
		_impl.dispose();
	}


	bool isEmpty() {
		return _impl.isEmpty();
	}
}
