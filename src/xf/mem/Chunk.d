module xf.mem.Chunk;



/**
	The internal header of each allocated memory chunk. Contains the pointer to data,
	available size and a method to release it through the associated allocator.
	
	Chunks are always aligned to xf.mem.Common.defaultAllocationAlignment
	
	Allocators always return Chunk pointers within an allocated memory region.
*/
struct Chunk {
	package {
		size_t					_size;
		void delegate(Chunk*)	_dispose;
		size_t					_reserved;
	}
	
	static Chunk* fromPtr(void* ptr) {
		return cast(Chunk*)(ptr - Chunk.sizeof);
	}
	
	void* ptr() {
		return cast(void*)this + Chunk.sizeof;
	}
	
	size_t size() {
		return _size;
	}
	
	void dispose() {
		assert (_dispose.funcptr !is null);
		_dispose(this);
	}
}


/**
	Compared to regular chunks, 'raw' chunks are returned by value and the allocated data
	doesn't contain any header. As such, the user has to take greater care to release raw chunks
	with the appropriate allocator. The advantage of using raw chunks is that no space is wasted
	when allocating them. In case of regular Chunks, potential wasted space is equal to
	Chunk.sizeof + xf.mem.Common.defaultAllocationAlignment - 1
*/
struct RawChunk {
	size_t					size;
	void*					ptr;
	void delegate(void*)	dispose;
}


/// A poor man's concept for checking allocator implementations
template implementsChunkAllocator(ThisType) {
	const implementsChunkAllocator =
			is(typeof(ThisType.maxChunkOverhead) : size_t)
	&&	is(typeof(ThisType.init.alloc()) == Chunk*)
	&&	is(typeof(ThisType.init.alloc(123)) == Chunk*)
	&&	is(typeof(ThisType.init.free((Chunk*).init)) == void)
	;
}
