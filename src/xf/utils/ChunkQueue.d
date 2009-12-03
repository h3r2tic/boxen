module xf.utils.ChunkQueue;

private {
	import xf.utils.ThreadChunkAllocator;
}



private const int _pageSize = 4096;


struct ChunkQueue(T) {
	static assert (T.sizeof <= _pageSize - Chunk.sizeof);
	private alias ChunkQueue PtrType;
	
	
	private struct Chunk {
		Chunk*	next;
		size_t	capacityBytes;
		size_t	capacity;
		size_t	length;

		T[] data() {
			return (cast(T*)(cast(void*)this + Chunk.sizeof))[0 .. this.length];
		}
	}


	void opCatAssign(T item) {
		Chunk* chunk = void;

		if (_tail is null) {
			_head = _tail = chunk = cast(Chunk*)chunkCache.get();
			chunk.length = 0;
			chunk.capacity = (chunk.capacityBytes - Chunk.sizeof) / T.sizeof;
			chunk.next = null;
		} else {
			chunk = _tail;
			if (chunk.capacity == chunk.length) {
				chunk = cast(Chunk*)chunkCache.get();
				chunk.length = 0;
				chunk.capacity = (chunk.capacityBytes - Chunk.sizeof) / T.sizeof;
				_tail.next = chunk;
			}
		}
		
		chunk.data()[chunk.length++] = item;
	}
	
	
	int opApply(int delegate(ref int, ref T) dg) {
		int i = 0;
		for (Chunk* cur = _head; cur; cur = cur.next) {
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
		for (Chunk* cur = _head; cur; cur = cur.next) {
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
			Chunk* cur = _head;
			auto cache = chunkCache;
			
			while (cur) {
				Chunk* next = cur.next;
				cur.next = null;
				cache.dispose(cast(ChunkCache.Chunk*)cur);
				cur = next;
			}
			
			_head = _tail = null;
		}
	}

	Chunk*	_head;
	Chunk*	_tail;
}


private {
	struct ChunkCache {
		struct Chunk {
			Chunk*	next;
			size_t	capacity;
		}

		Chunk* next;

		Chunk* get() {
			if (auto res = next) {
				next = res.next;
				res.next = null;
				return res;
			} else {
				auto rawChunk = threadChunkAllocator.alloc(_pageSize);
				auto chunk = cast(Chunk*)rawChunk.ptr;
				chunk.capacity = rawChunk.size;
				return chunk;
			}
		}
		
		void dispose(Chunk* chunk) {
			assert (chunk !is null);
			assert (chunk.next is null);
			chunk.next = next;
			next = chunk;
		}
	}
	
	
	__thread ChunkCache chunkCache;
}
