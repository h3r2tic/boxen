module xf.mem.ChunkQueue;

private {
	import xf.mem.ThreadChunkAllocator;
	import xf.mem.ChunkCache;
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
			_head = _tail = chunk = cast(Chunk*)chunkCache!(_pageSize).get();
			chunk.length = 0;
			chunk.capacity = (chunk.capacityBytes - Chunk.sizeof) / T.sizeof;
			chunk.next = null;
		} else {
			chunk = _tail;
			if (chunk.capacity == chunk.length) {
				chunk = cast(Chunk*)chunkCache!(_pageSize).get();
				chunk.length = 0;
				chunk.capacity = (chunk.capacityBytes - Chunk.sizeof) / T.sizeof;
				_tail.next = chunk;
				_tail = chunk;
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
			auto cache = &chunkCache!(_pageSize);
			
			while (cur) {
				Chunk* next = cur.next;
				cur.next = null;
				cache._disposeChunkPtr(cast(void*)cur);
				cur = next;
			}
			
			_head = _tail = null;
		}
	}

	Chunk*	_head;
	Chunk*	_tail;
}
