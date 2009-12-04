module xf.mem.Chunk;



struct Chunk {
	package {
		size_t							_size;
		void delegate(Chunk*)	_dispose;
		size_t							_reserved;
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



struct RawChunk {
	size_t						size;
	void*						ptr;
	void delegate(void*)	dispose;
}


// a poor man's concept
template implementsChunkAllocator(ThisType) {
	const implementsChunkAllocator =
			is(typeof(ThisType.maxChunkOverhead) : size_t)
	&&	is(typeof(ThisType.init.alloc()) == Chunk*)
	&&	is(typeof(ThisType.init.alloc(123)) == Chunk*)
	&&	is(typeof(ThisType.init.free((Chunk*).init)) == void)
	;
}
