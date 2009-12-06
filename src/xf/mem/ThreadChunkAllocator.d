module xf.mem.ThreadChunkAllocator;

private {
	import xf.mem.Chunk;
	import xf.mem.Common;
	import xf.mem.OSHeap;
	static import tango.core.Exception;
	
	//import tango.util.log.Trace;
}



/**
	An allocator utilizing thread-local heaps. When only using one thread, the performance is similar
	to malloc / new, but scales gracefully with multithreading, beating DMD-Win's malloc by a factor
	of about 6.5 with 4 threads on a single-core machine and an order of over 50-200 on a quad-core.
*/
struct ThreadChunkAllocator {
	const size_t maxChunkOverhead = Chunk.sizeof + defaultAllocationAlignment-1;

	static assert(implementsChunkAllocator!(ThreadChunkAllocator));
	
	
	Chunk* alloc(size_t size = 0) {
		const size_t alignment = defaultAllocationAlignment;
		
		if (0 == size) {
			size = pageSize;
		} else {
			size += maxChunkOverhead;
		}
		
		auto raw = allocRaw(size);

		auto res = cast(Chunk*)(alignPointerUp(raw.ptr + Chunk.sizeof, defaultAllocationAlignment) - Chunk.sizeof);
		res._size = size - (res.ptr() - raw.ptr);
		res._dispose = &free;
		res._reserved = cast(size_t)raw.ptr;
		
		return res;
	}
	
	
	RawChunk allocRaw(size_t size = 0) {
		size += pageSize - 1;
		size /= pageSize;
		size *= pageSize;

		//Trace.formatln("ThreadChunkAllocator: allocating {} bytes", size);
		void* ptr = osHeap.allocRaw(size);
		
		if (ptr is null) {
			tango.core.Exception.onOutOfMemoryError();
		}
		
		return RawChunk(size, ptr, &freeRaw);
	}
	

	void free(Chunk* chunk) {
		freeRaw(cast(void*)chunk._reserved);
	}
	
	
	void freeRaw(void* ptr) {
		osHeap.freeRaw(ptr);
	}


	size_t pageSize() {
		return OSHeap.pageSize;
	}
}


__thread ThreadChunkAllocator threadChunkAllocator;
