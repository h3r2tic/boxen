module xf.mem.StackBuffer;

private {
	import xf.mem.Chunk;
	import xf.mem.ThreadChunkAllocator : _StackBufferInternalAllocator = ThreadChunkAllocator;
	import xf.mem.ScratchAllocator;
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
scope class StackBuffer : StackBufferUnsafe {
}	


class StackBufferUnsafe {
	this() {
		_mainBuffer = &g_mainStackBuffer;
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
	

	void* allocRaw(size_t bytes) {		// throws
		return _mainBuffer.alloc(bytes, this, true).ptr;
	}

	void* allocRaw(size_t bytes, bool throwExc) {
		return _mainBuffer.alloc(bytes, this, throwExc).ptr;
	}

	mixin MScratchAllocator;


	/**
	 * This moves ownership of the data associated with this stack buffer
	 * to the other buffer given as a parameter. As a result, the current
	 * buffer will not pop any data off the shared buffer and all the mem
	 * will be assumed to belong to the other buffer.
	 */
	void mergeWith(StackBufferUnsafe other) {
		if (_topChunk != size_t.max) {
			_mainBuffer.mergeWith(this, other);
			_topChunk = size_t.max;
		}
	}


	static size_t bytesUsed() {
		final buf = &g_mainStackBuffer;
		if (size_t.max == buf._topChunk) {
			return 0;
		} else {
			size_t res = 0;
			foreach (ch; buf._chunks[0..buf._topChunk]) {
				res += ch.size;
			}
			res += buf._chunkTop;
			return res;
		}
	}

	
	~this() {
		assert (_mainBuffer !is null);
		
		if (_topChunk != size_t.max) {
			_mainBuffer.release(this);
		}

		_mainBuffer = null;		// Cause an assert/segfault on double destruction
	}
	
	
	MainStackBuffer*	_mainBuffer;
	size_t				_topChunk = size_t.max;
	size_t				_topOffset;
	StackBufferUnsafe	_prevBuffer;
}



const int		minStaticMemory = 2 * 1024 * 1024;
const size_t	maxAllocSize = minStaticMemory - g_subAllocator.maxChunkOverhead;

private {
	_StackBufferInternalAllocator							g_subAllocator;
	static ChunkCache!(maxAllocSize, g_subAllocator)		g_chunkCache;
	static Object											g_mutex;
}


private struct MainStackBuffer {
	const int				maxChunks = 128;	
	Chunk*[maxChunks]		_chunks;
	
	size_t					_topChunk = size_t.max;
	size_t					_chunkTop;
	StackBufferUnsafe		_bufferList;
	
	static this() {
		g_mutex = new Object;
	}
	
	
	void releaseThreadData() {
		if (size_t.max != _topChunk) {
			releaseChunksDownToButExcluding(size_t.max, false);
		}
		_chunkTop = 0;
		_bufferList = null;
	}


	void release(StackBufferUnsafe buf) {
		assert (_bufferList !is null);
		assert (buf._topChunk != size_t.max);

		// Unlink from the buffer list
		
		if (buf is _bufferList) {
			_bufferList = buf._prevBuffer;

			if (auto prev = _bufferList) {
				releaseChunksDownToButExcluding(prev._topChunk);
				_chunkTop = prev._topOffset;
			} else {
				releaseChunksDownToButExcluding(size_t.max, true);
				_chunkTop = 0;
			}
		} else {
			auto next = _bufferList;
			
			while (next._prevBuffer !is buf) {
				next = next._prevBuffer;
				assert (next !is null);
			}

			next._prevBuffer = buf._prevBuffer;
		}
	}


	void mergeWith(StackBufferUnsafe buf, StackBufferUnsafe other) {
		assert (buf !is null);
		assert (other !is null);
		assert (_bufferList !is null);
		assert (buf._topChunk != size_t.max);


		bool replaceWithOther = false;

		if (size_t.max == other._topChunk) {
			// Nothing was allocated from that other stack, put it in place
			// of the original buffer

			replaceWithOther = true;
		} else if (
				other._topChunk <= buf._topChunk
			&&	other._topOffset <= buf._topOffset
		) {
			// If the 'other' buffer (that we're merging unto) is deeper in the stack
			// than our current buffer, we'll need to move the 'other' buffer up
			// all the way to the position of 'buf'. This happens in two steps
			// - the first one is to remove 'other' from its current location in the list.

			auto next = _bufferList;
			
			while (next._prevBuffer !is other) {
				next = next._prevBuffer;
				assert (next !is null);
			}

			next._prevBuffer = other._prevBuffer;

			// The second step will be the same as for merging with an empty stack
			// - the other stack will be put in place of the current one
			replaceWithOther = true;
		}
		
		if (buf is _bufferList) {
			if (replaceWithOther) {
				_bufferList = other;
				other._prevBuffer = buf._prevBuffer;
				other._topChunk = buf._topChunk;
				other._topOffset = buf._topOffset;
				return;
			} else {
				_bufferList = buf._prevBuffer;
			}
		} else {
			auto next = _bufferList;
			
			while (next._prevBuffer !is buf) {
				next = next._prevBuffer;
				assert (next !is null);
			}

			if (replaceWithOther) {
				// Nothing was allocated from that other stack, put it in place
				// of the original buffer
				next._prevBuffer = other;
				other._prevBuffer = buf._prevBuffer;
				other._topChunk = buf._topChunk;
				other._topOffset = buf._topOffset;
				return;
			} else {
				next._prevBuffer = buf._prevBuffer;
			}
		}
	}
	
	
	private void releaseChunksDownToButExcluding(size_t chunkIdx, bool keepOne = true) {
		assert (_topChunk != size_t.max);
		
		// hold at least one buffer on the TLS so we don't constantly re-acquire it
		if (size_t.max == chunkIdx) {
			if (keepOne) {
				chunkIdx = 0;
			}
		} else {
			assert (_topChunk >= chunkIdx);
		}
		
		// try to avoid taking the lock
		if (_topChunk != chunkIdx) {
			synchronized (g_mutex) {
				for (; _topChunk != chunkIdx; --_topChunk) {
					_chunks[_topChunk].dispose();
				}
			}
		}
	}
	
	
	void[] alloc(size_t bytes, StackBufferUnsafe buf, bool throwExc = true) {
		if (bytes > maxAllocSize) {
			if (throwExc) {
				throw new Exception("My spoon is too big!");
			} else {
				return null;
			}
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
		
		final bottom = _chunkTop;
		_chunkTop += bytes;
		final result = chunk.ptr()[bottom .. _chunkTop];

		if (buf !is _bufferList) {
			if (_bufferList is null) {
				// This is the first allocation
				_bufferList = buf;
			} else if (size_t.max == buf._topChunk) {
				// This is the first allocation with the new stack buffer
				buf._prevBuffer = _bufferList;
				_bufferList = buf;
			} else {
				// This stack buffer has already been used. We also previously
				// allocated from another stack, move this one up in the list.
				// This is O(n), but n should always be small.
				
				auto next = _bufferList;
				
				while (next._prevBuffer !is buf) {
					next = next._prevBuffer;
					assert (next !is null);
				}

				next._prevBuffer = buf._prevBuffer;
				buf._prevBuffer = _bufferList;
				_bufferList = buf;
			}
		}	// else we previously allocated from the same stack, nothing to do.

		buf._topChunk = _topChunk;
		buf._topOffset = _chunkTop;

		return result;
	}
}


private __thread MainStackBuffer g_mainStackBuffer;
