module xf.mem.ChunkQueue;

private {
	import xf.mem.ChunkCache;
	import xf.mem.ThreadChunkAllocator : _chunkQueueInternalAllocator = threadChunkAllocator;
	import xf.mem.Common;
	import xf.mem.Chunk;
	import xf.mem.Log : error = memError;
}



struct RawChunkQueue {
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
		QueueChunk*	chunk = void;
		void*		ptr = void;

		if (_tail is null) {
			_head = _tail = chunk = allocNewChunk();
			ptr = alignPointerUp(chunk.ptr(), alignment);

			if (ptr + bytes > chunk.ptr + chunk.capacity) {
				error(
					"Chunks too small ({}) to allocate {} bytes.",
					chunk.capacity, bytes
				);
			}
		} else {
			chunk = _tail;
			ptr = alignPointerUp(chunk.ptr() + chunk.used, alignment);
			
			if (ptr + bytes > chunk.ptr + chunk.capacity) {
				chunk = allocNewChunk();
				ptr = alignPointerUp(chunk.ptr(), alignment);
				_tail.next = chunk;
				_tail = chunk;

				if (ptr + bytes > chunk.ptr + chunk.capacity) {
					error(
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
			error(
				"Trying to pop a wrong mem address: {:x}. head.ptr: {:x}, head.last: {:x}.",
				ptr, chptr, last
			);
		}

		if (_lastFreed !is null) {
			if (ptr <= _lastFreed) {
				if (ptr < _lastFreed) {
					error("Popping an address in a wrong order.");
				} else {
					error("Double-popping an address.");
				}
			}
		}

		if (last is ptr) {
			_lastFreed = null;		// another chunk, can't be used for linear comparisons
			
			auto cache = &_allocator;
			final QueueChunk* next = ch.next;
			Chunk.fromPtr(cast(void*)ch).dispose();
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
				Chunk.fromPtr(cast(void*)cur).dispose();
				cur = next;
			}
			
			_head = _tail = null;
			_lastFreed = null;
		}
	}


	QueueChunk*	_head;
	QueueChunk*	_tail;
	void*		_lastFreed;
}


// TODO: rename ChunkQueue to ThreadLocalChunkQueue and add a version with a global allocator (GlobalChunkQueue)


/**
	An efficient implementation of a queue to which one may only append items and
	iterate over them. Internally it's based on chunked memory allocation from the
	ThreadChunkAllocator and connecting the chunks in a uni-directional linked list.
*/
struct ChunkQueue(T) {
	const size_t _pageSize = minDefaultPageSize;
	
	static assert (T.sizeof <= _pageSize - Chunk.sizeof - 15 - QueueChunk.sizeof);
	
	private alias _chunkQueueInternalAllocator
		_subAllocator;
		
	private alias chunkCache!(_pageSize - _subAllocator.maxChunkOverhead, _subAllocator)
		_allocator;
		
	private alias ChunkQueue PtrType;
	
	
	private struct QueueChunk {
		QueueChunk*	next;
		size_t		capacity;
		size_t		length;

		T[] data() {
			return (cast(T*)(cast(void*)this + QueueChunk.sizeof))[0 .. this.length];
		}
	}


	void opCatAssign(T item) {
		QueueChunk* chunk = void;

		if (_tail is null) {
			auto raw = _allocator.alloc();
			assert (raw !is null);
			assert (raw.ptr !is null);
			_head = _tail = chunk = cast(QueueChunk*)raw.ptr;
			chunk.length = 0;
			chunk.capacity = (raw.size - QueueChunk.sizeof) / T.sizeof;
			chunk.next = null;
		} else {
			chunk = _tail;
			if (chunk.capacity == chunk.length) {
				auto raw = _allocator.alloc();
				assert (raw !is null);
				assert (raw.ptr !is null);
				chunk = cast(QueueChunk*)raw.ptr;
				chunk.length = 0;
				chunk.capacity = (raw.size - QueueChunk.sizeof) / T.sizeof;
				_tail.next = chunk;
				_tail = chunk;
			}
		}
		
		chunk.data()[chunk.length++] = item;
	}
	
	
	int opApply(int delegate(ref int, ref T) dg) {
		int i = 0;
		for (QueueChunk* cur = _head; cur; cur = cur.next) {
			foreach (ref item; cur.data()) {
				if (auto r = dg(i, item)) {
					return r;
				}
				++i;
			}
		}
		return 0;
	}


	int opApply(int delegate(ref T) dg) {
		for (QueueChunk* cur = _head; cur; cur = cur.next) {
			foreach (ref item; cur.data()) {
				if (auto r = dg(item)) {
					return r;
				}
			}
		}
		return 0;
	}


	void clear() {
		if (_head) {
			QueueChunk* cur = _head;
			auto cache = &_allocator;
			
			while (cur) {
				QueueChunk* next = cur.next;
				Chunk.fromPtr(cast(void*)cur).dispose();
				cur = next;
			}
			
			_head = _tail = null;
		}
	}

	QueueChunk*	_head;
	QueueChunk*	_tail;
}
