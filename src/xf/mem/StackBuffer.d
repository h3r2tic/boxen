module xf.mem.StackBuffer;

private {
	import xf.mem.Chunk;
	import xf.mem.ThreadChunkAllocator : _StackBufferInternalAllocator = ThreadChunkAllocator;
	import xf.mem.ChunkCache;
	import xf.mem.Common;
	
	import tango.util.log.Trace;
}



/**
	An utility for creating local stack-based allocations in the gist of alloca(), yet without the
	severe limitations of the native stack nor the unfortunate awkward interface to it.
	
	Internally StackBuffer is a thin interface to MainStackBuffer, which uses chunk-based
	globally-cached allocation of large stack segments. StackBuffer simply stores the 'stack pointer'
	of MainStackBuffer in the ctor and restores it in the dtor. Due to how the scope storage class works,
	it's possible to nest multiple StackBuffer instances in program flow.
	
	There's a one-time allocation limit at the max chunk size being 2MB and a maximum number of
	chunks to be used in MainStackBuffer at 128 per-thread.
	
	The only place where disposal of resources is required is at the end of a thread's life. It's necessary
	to call StackBuffer.releaseThreadData there because by default each thread-local stack buffer
	retains one 2MB chunk of memory so it doesn't have to access the global pool constantly. This memory
	will be leaked if StackBuffer.releaseThreadData is not called.
	
	// TODO: some more elaborate pooling strategy can be implemented should 'keeping one chunk' fail.

	----
	scope buf = new StackBuffer;		// stack-based instance
	int* foo = buf.alloc!(int)();
	int[] arr = buf.allocArray!(int)(500_000);
	auto bar = buf.alloc!(Bar)(3.14f, "poop");
	// all allocated entities are gone at the end of scope, no manual disposal required
	----
*/
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
	
	
	static void releaseThreadData() {
		g_mainStackBuffer.releaseThreadData();
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
		auto res = allocArrayNoInit!(T)(len);
		foreach (ref r; res) {
			r = T.init;
		}
		return res;
	}
	

	T[] allocArrayNoInit(T)(size_t len) {
		size_t size = len * T.sizeof;
		return cast(T[])_mainBuffer.alloc(size);
	}

	
	~this() {
		_mainBuffer.releaseChunksDownToButExcluding(_chunkMark);
		_mainBuffer._chunkTop = _topMark;
	}
	
	
	MainStackBuffer*	_mainBuffer;
	size_t					_chunkMark;
	size_t					_topMark;
}



const int		minStaticMemory = 2 * 1024 * 1024;
const size_t	maxAllocSize = minStaticMemory - g_subAllocator.maxChunkOverhead;

private {
	_StackBufferInternalAllocator										g_subAllocator;
	static ChunkCache!(maxAllocSize, g_subAllocator)		g_chunkCache;
	static Object																g_mutex;
}


private struct MainStackBuffer {
	const int						maxChunks = 128;	
	Chunk*[maxChunks]		_chunks;
	size_t							_topChunk = size_t.max;
	size_t							_chunkTop;
	
	static this() {
		g_mutex = new Object;
	}
	
	
	void releaseThreadData() {
		releaseChunksDownToButExcluding(size_t.max, false);
	}
	
	
	void releaseChunksDownToButExcluding(size_t mark, bool keepOne = true) {
		if (size_t.max == _topChunk) {
			assert (size_t.max == mark);
		}
		
		// hold at least one buffer on the TLS so we don't constantly re-acquire it
		if (size_t.max == mark) {
			if (keepOne) {
				mark = 0;
			}
		} else {
			assert (_topChunk >= mark);
		}
		
		// try to avoid taking the lock
		if (_topChunk != mark) {
			synchronized (g_mutex) {
				for (; _topChunk != mark; --_topChunk) {
					_chunks[_topChunk].dispose();
				}
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
				//Trace.formatln("MainStackBuffer: allocating a new chunk");
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
