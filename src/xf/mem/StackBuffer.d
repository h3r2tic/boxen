module xf.mem.StackBuffer;

private {
	import xf.mem.Chunk;
	import xf.mem.ThreadChunkAllocator : _stackBufferInternalAllocator = threadChunkAllocator;
	import xf.mem.ChunkCache;
	import xf.mem.Common;
	
	// import tango.util.log.Trace;
}


private struct MainStackBuffer {
	const int			minStaticMemory = 2 * 1024 * 1024;

	private alias _stackBufferInternalAllocator
							_subAllocator;

	const size_t		maxAllocSize = minStaticMemory - _subAllocator.maxChunkOverhead;
	const int			maxChunks = 128;
	
	static ChunkCache!(maxAllocSize, _subAllocator)
							g_chunkCache;

	Chunk*[maxChunks]		_chunks;
	size_t							_topChunk = size_t.max;
	size_t							_chunkTop;
	static Object					g_mutex;
	
	static this() {
		g_mutex = new Object;
	}
	
	
	void releaseChunksDownToButExcluding(size_t mark) {
		if (size_t.max == _topChunk) {
			assert (size_t.max == mark);
		}
		assert (size_t.max == mark || _topChunk >= mark);
		
		synchronized (g_mutex) {
			for (; _topChunk != mark; --_topChunk) {
				_chunks[_topChunk].dispose();
			}
		}
	}
	
	
	void[] alloc(size_t bytes) {
		if (bytes > maxAllocSize) {
			throw new Exception("My spoon is too big!");
		}
		
		Chunk* chunk = void;
		
		if (bytes > maxAllocSize - _chunkTop || size_t.max == _topChunk) {
			synchronized (g_mutex) {
				// Trace.formatln("MainStackBuffer: allocating a new chunk");
				chunk = g_chunkCache.alloc(maxAllocSize);
			}
			if (_topChunk == _chunks.length-1) {
				//tango.core.Exception.onOutOfMemoryError();
				throw new Exception("Ran out of stack chunks.");
			}
			_chunks[++_topChunk] = chunk;
			_chunkTop = 0;
		} else {
			chunk = _chunks[_topChunk];
		}
		
		size_t bottom = _chunkTop;
		_chunkTop += bytes;
		return chunk.ptr()[bottom .. _chunkTop];
	}
}


private __thread MainStackBuffer g_mainStackBuffer;


scope class StackBuffer {
	this() {
		_mainBuffer = &g_mainStackBuffer;
		_chunkMark = _mainBuffer._topChunk;
		_topMark = _mainBuffer._chunkTop;
	}
	
	
	private template RefType(T) {
		static if (is(T == class)) {
			alias T RefType;
		} else {
			alias T* RefType;
		}
	}
	
	
	template alloc(T) {
		RefType!(T) alloc(Args ...)(Args args) {
			size_t size = void;
			
			static if (is(T == class)) {
				size = T.classinfo.init.length;
			} else {
				size = T.sizeof;
			}
			
			auto buf = _mainBuffer.alloc(size);
			
			static if (is(T == class)) {
				buf[] = T.classinfo.init[];
				auto res = cast(T)cast(void*)buf.ptr;
				res._ctor(args);
				return res;
			} else static if (is(T == struct)) {
				T* res = cast(T*)buf.ptr;
				*res = T(args);
				return res;
			} else {
				T* res = cast(T*)buf.ptr;
				static if (1 == args.length) {
					*res = args[0];
				} else {
					static assert (0 == args.length);
					*res = T.init;
				}
				return res;
			}
		}
	}
	
	
	T[] allocArray(T)(size_t len) {
		size_t size = len * T.sizeof;
		auto res = cast(T[])_mainBuffer.alloc(size);
		foreach (ref r; res) {
			r = T.init;
		}
		return res;
	}
	
	
	~this() {
		_mainBuffer.releaseChunksDownToButExcluding(_chunkMark);
		_mainBuffer._chunkTop = _topMark;
	}
	
	
	MainStackBuffer*	_mainBuffer;
	size_t					_chunkMark;
	size_t					_topMark;
}
