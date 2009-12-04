module xf.mem.ThreadChunkAllocator;

private {
	import xf.mem.Chunk;
	import xf.mem.Common;
	
	struct winapi {
		import xf.platform.win32.winbase;
		import xf.platform.win32.windef;
		import xf.platform.win32.winnt;
	}
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
		const size_t alignment = 16;
		
		if (0 == size) {
			size = _pageSize;
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
		size += _pageSize - 1;
		size /= _pageSize;
		size *= _pageSize;

		if (_heapId is null) {
			initialize();
		}

		//Trace.formatln("ThreadChunkAllocator: allocating {} bytes", size);
		void* ptr = .winapi.HeapAlloc(_heapId, 0, size);
		
		if (ptr is null) {
			tango.core.Exception.onOutOfMemoryError();
		}
		
		return RawChunk(size, ptr, &freeRaw);
	}
	

	void free(Chunk* chunk) {
		freeRaw(cast(void*)chunk._reserved);
	}
	
	
	void freeRaw(void* ptr) {
		assert (_heapId !is null);
		.winapi.HeapFree(_heapId, 0, ptr);
	}


	bool initialized() {
		return _heapId !is null;
	}
	
	
	size_t pageSize() {
		return _pageSize;
	}


	private {
		.winapi.HANDLE	_heapId;

		void initialize() {
			// 1 MB by default
			_heapId = .winapi.HeapCreate(.winapi.HEAP_NO_SERIALIZE, 1024 * 1024, 0);
			assert (_heapId !is null);
		}
		
		static {
			size_t _pageSize;
		}
	}
}


__thread ThreadChunkAllocator threadChunkAllocator;


static this() {
	.winapi.SYSTEM_INFO info;
	.winapi.GetSystemInfo(&info);
	ThreadChunkAllocator._pageSize = info.dwPageSize;
}
