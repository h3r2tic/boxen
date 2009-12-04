module xf.mem.OSChunkAllocator;

private {
	import xf.mem.Chunk;
	import xf.mem.Common;
	
	struct winapi {
		import xf.platform.win32.winbase;
		import xf.platform.win32.windef;
		import xf.platform.win32.winnt;
	}
	static import tango.core.Exception;
}



/**
	An allocator that directly requests memory pages from the OS. Slow, but makes it possible
	to return the memory to the OS and has very little extra data overhead.
*/
struct OSChunkAllocator {
	const size_t maxChunkOverhead = Chunk.sizeof + defaultAllocationAlignment-1;

	static assert(implementsChunkAllocator!(OSChunkAllocator));
	
	
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

		void* ptr = .winapi.VirtualAlloc(null, size, .winapi.MEM_COMMIT, .winapi.PAGE_READWRITE);
		
		if (ptr is null) {
			tango.core.Exception.onOutOfMemoryError();
		}
		
		return RawChunk(size, ptr, &freeRaw);
	}
	

	void free(Chunk* chunk) {
		freeRaw(cast(void*)chunk._reserved);
	}
	
	
	void freeRaw(void* ptr) {
		.winapi.VirtualFree(ptr, 0, .winapi.MEM_RELEASE);
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


OSChunkAllocator osChunkAllocator;


static this() {
	.winapi.SYSTEM_INFO info;
	.winapi.GetSystemInfo(&info);
	OSChunkAllocator._pageSize = info.dwPageSize;
}



/+
	import tango.io.Stdout;

	void main() {
		auto chunk = threadChunkAllocator.alloc();
		Stdout.formatln("Allocated a chunk with {} bytes", chunk.size);
		chunk.dispose();
	}
+/
