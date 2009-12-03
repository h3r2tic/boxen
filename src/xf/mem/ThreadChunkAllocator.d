module xf.mem.ThreadChunkAllocator;

private {
	struct winapi {
		import xf.platform.win32.winbase;
		import xf.platform.win32.windef;
		import xf.platform.win32.winnt;
	}
	static import tango.core.Exception;
}



struct ThreadChunkAllocator {
	struct Chunk {
		void*					ptr;
		size_t					size;
		ThreadChunkAllocator*	allocator;

		void dispose() {
			allocator.free(this);
		}
	}

	Chunk alloc(size_t size = 0) {
		if (0 == size) {
			size = _pageSize;
		}
		
		if (_heapId is null) {
			initialize();
		}

		void* ptr = .winapi.HeapAlloc(_heapId, 0, size);
		if (ptr is null) {
			tango.core.Exception.onOutOfMemoryError();
		}
		return Chunk(ptr, size, this);
	}

	void free(Chunk* chunk) {
		assert (_heapId !is null);
		.winapi.HeapFree(_heapId, 0, chunk.ptr);
	}

	void free(void* ptr) {
		assert (_heapId !is null);
		.winapi.HeapFree(_heapId, 0, ptr);
	}

	size_t minChunkSize() {
		return _pageSize;
	}
	
	bool initialized() {
		return _heapId !is null;
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



/+
	import tango.io.Stdout;

	void main() {
		auto chunk = threadChunkAllocator.alloc();
		Stdout.formatln("Allocated a chunk with {} bytes", chunk.size);
		chunk.dispose();
	}
+/
