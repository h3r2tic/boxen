module xf.mem.ScratchRope;

private {
	import xf.Common;
	import xf.mem.ScratchAllocator;
}



private struct ScratchRope {
	private {
		struct Chunk {
			align(0)
			Chunk*	next		= null;
			ubyte	length		= 0;	// 0->1, 1->2, etc
			ubyte	capacity	= 0;	// 0->1, 1->2, etc
		}
		static assert (Chunk.sizeof == (Chunk*).sizeof + 2 * ubyte.sizeof);

		const uword allocAlign = 32;
		const uword minAlloc = allocAlign;
		const uword maxAlloc = cast(uword)(ubyte.max)+1;

		Chunk*	first	= null;
		Chunk*	last	= null;

		static Chunk* allocChunk(uword len, DgScratchAllocator mem) {
			assert (len != 0);
			
			if (len <= minAlloc) {
				final chunk = cast(Chunk*)mem.allocRaw(minAlloc+Chunk.sizeof);
				chunk.next = null;
				chunk.length = cast(ubyte)(len-1);
				chunk.capacity = minAlloc-1;
				return chunk;
			}
			
			else if (len >= maxAlloc) {
				final chunk = cast(Chunk*)mem.allocRaw(maxAlloc+Chunk.sizeof);
				chunk.next = null;
				chunk.length = maxAlloc-1;
				chunk.capacity = maxAlloc-1;
				return chunk;
			}

			else {
				uword siz = (len + (allocAlign-1)) & ~(allocAlign-1);
				assert (siz <= cast(uword)(ubyte.max)+1);

				final chunk = cast(Chunk*)mem.allocRaw(siz+Chunk.sizeof);
				chunk.next = null;
				chunk.length = cast(ubyte)(len-1);
				chunk.capacity = cast(ubyte)(siz-1);
				return chunk;
			}
		}
	}
	
	void append(cstring str_, DgScratchAllocator mem) {
		if (0 == str_.length) {
			return;
		}
		
		uword len = str_.length;
		char* str = str_.ptr;
		
		if (last is null) {
			last = first = allocChunk(len, mem);

			uword allocLen = cast(uword)(last.length)+1;
			memcpy(last+1, str, allocLen);
			len -= allocLen;
			str += allocLen;
		} else {
			uword freeSpace = last.capacity - last.length;
			if (len <= freeSpace) {
				memcpy(cast(void*)(last+1)+last.length+1, str, len);
				last.length += len;
				return;
			} else if (freeSpace > 0) {
				memcpy(cast(void*)(last+1)+last.length+1, str, freeSpace);
				last.length = last.capacity;
				len -= freeSpace;
				str += freeSpace;
			}
		}

		while (len) {
			auto chunk = last.next = allocChunk(len, mem);
			last = chunk;

			uword allocLen = cast(uword)(last.length)+1;

			memcpy(last+1, str, allocLen);
			len -= allocLen;
			str += allocLen;
		}
	}

	void writeOut(void delegate(char[]) sink) {
		for (Chunk* it = first; it; it = it.next) {
			assert (it.length <= it.capacity);
			assert (it.next is null || it.length == it.capacity);
			char* str = cast(char*)(it+1);
			sink(str[0..cast(uword)(it.length)+1]);
		}
	}
}


private struct ScratchFixedRope {
	private {
		struct Chunk {
			align(0)
			Chunk*	next		= null;
			ubyte	length		= 0;	// 0->1, 1->2, etc
			// capacity == 256
		}
		static assert (Chunk.sizeof == (Chunk*).sizeof + ubyte.sizeof);

		Chunk*	first	= null;
		Chunk*	last	= null;

		static Chunk* allocChunk(uword len, DgScratchAllocator mem) {
			assert (len != 0);
			
			if (len <= 256) {
				final chunk = cast(Chunk*)mem.allocRaw(256+Chunk.sizeof);
				chunk.next = null;
				chunk.length = cast(ubyte)(len-1);
				return chunk;
			}
			
			else {
				final chunk = cast(Chunk*)mem.allocRaw(256+Chunk.sizeof);
				chunk.next = null;
				chunk.length = 256-1;
				return chunk;
			}
		}
	}
	
	void append(cstring str_, DgScratchAllocator mem) {
		if (0 == str_.length) {
			return;
		}
		
		uword len = str_.length;
		char* str = str_.ptr;
		
		if (last is null) {
			last = first = allocChunk(len, mem);

			uword allocLen = cast(uword)(last.length)+1;
			memcpy(last+1, str, allocLen);
			len -= allocLen;
			str += allocLen;
		} else {
			uword freeSpace = 256-1 - last.length;
			if (len <= freeSpace) {
				memcpy(cast(void*)(last+1)+last.length+1, str, len);
				last.length += len;
				return;
			} else if (freeSpace > 0) {
				memcpy(cast(void*)(last+1)+last.length+1, str, freeSpace);
				last.length = 256-1;
				len -= freeSpace;
				str += freeSpace;
			}
		}

		while (len) {
			auto chunk = last.next = allocChunk(len, mem);
			last = chunk;

			uword allocLen = cast(uword)(last.length)+1;

			memcpy(last+1, str, allocLen);
			len -= allocLen;
			str += allocLen;
		}
	}

	void writeOut(void delegate(char[]) sink) {
		for (Chunk* it = first; it; it = it.next) {
			char* str = cast(char*)(it+1);
			sink(str[0..cast(uword)(it.length)+1]);
		}
	}
}
