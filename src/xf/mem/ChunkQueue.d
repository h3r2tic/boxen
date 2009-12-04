module xf.mem.ChunkQueue;

private {
	import xf.mem.ChunkCache;
	import xf.mem.ThreadChunkAllocator : _chunkQueueInternalAllocator = threadChunkAllocator;
	import xf.mem.Common;
	import xf.mem.Chunk;
}



/**
	An efficient implementation of a queue to which one may only append items and iterate over them.
	Internally it's based on chunked memory allocation from the ThreadChunkAllocator and connecting
	the chunks in a uni-directional linked list.
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
		size_t				capacity;
		size_t				length;

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
