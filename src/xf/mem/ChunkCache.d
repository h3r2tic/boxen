module xf.mem.ChunkCache;

private {
	import xf.mem.Chunk;
	import xf.mem.Common;
	import xf.mem.Log;
	import tango.text.convert.Format;
	import Trace = tango.core.tools.StackTrace;
	import tango.core.Thread;
	static import tango.core.Exception;
}


/**
	ChunkCache allows the caching and on-demand allocation of memory chunks.
	The actual allocation is delegated to the allocator specified as a template alias parameter
	the parameter will usually be a symbol of a thread-local or global allocator instance.
*/
private struct ChunkCache(int _pageSize, alias _allocator) {
	static assert ((_pageSize + _allocator.maxChunkOverhead) % minDefaultPageSize == 0);
	const size_t maxChunkOverhead = _allocator.maxChunkOverhead;

	static assert (implementsChunkAllocator!(ChunkCache));
	
	private {
		struct CachedChunk {
			Chunk*			chunk;
			CachedChunk*	next;
		}

		CachedChunk*	next;
		int				_totalAllocated = 0;
	}
	

	Chunk* alloc(size_t size = 0) {
		if (size > _pageSize) {
			throw new Exception(Format(
				"The ChunkCache cannot allocate more data ({}) than it was statically parametrized for ({})",
				size,
				_pageSize
			));
		}
		
		if (auto res = next) {
			next = res.next;
			return res.chunk;
		} else {
			++_totalAllocated;
			
			/+if (Thread.getThis()) {
				auto tr = Trace.basicTracer(null);
				char[] msg;
				tr.writeOut((char[] s) { msg ~= s; });
				memLog.trace(
					"ChunkCache: allocating a new chunk ({}). At:\n{}",
					_totalAllocated,
					msg
				);
				delete tr;
			} else {
				memLog.trace(
					"ChunkCache: allocating a new chunk ({}) in foreign thread.",
					_totalAllocated
				);
			}+/
			
			auto raw = _allocator.allocRaw(_pageSize);

			auto res = cast(Chunk*)(alignPointerUp(raw.ptr + Chunk.sizeof, defaultAllocationAlignment) - Chunk.sizeof);
			res._size = raw.size - (res.ptr() - raw.ptr);
			res._dispose = &free;
			res._reserved = cast(size_t)raw.ptr;

			return res;
		}
	}
	
	void free(Chunk* chunk) {
		assert (chunk !is null);
		auto cchunk = cast(CachedChunk*)chunk.ptr;
		cchunk.chunk = chunk;
		cchunk.next = this.next;
		this.next = cchunk;
	}
}


template chunkCache(int _pageSize, alias allocator) {
	__thread ChunkCache!(_pageSize, allocator) chunkCache;
}
