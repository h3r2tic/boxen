module xf.utils.ChunkCache;

private {
	import xf.utils.ThreadChunkAllocator;
}


private struct ChunkCache(int _pageSize) {
	private {
		struct Chunk {
			Chunk*	next;
			size_t	capacity;
			
			void dispose() {
				.chunkCache!(_pageSize).dispose(this);
			}
		}

		Chunk* next;
	}
	

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


	void _disposeChunkPtr(void* chunk) {
		return dispose(cast(Chunk*)chunk);
	}
}


template chunkCache(int _pageSize) {
	__thread ChunkCache!(_pageSize) chunkCache;
}
