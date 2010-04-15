module xf.utils.BitSet;

private {
	import Memory = xf.utils.Memory;
	import std.intrinsic;
}



struct BitSet(int minBits) {
	const bool dynamic = false;

	
	void opIndexAssign(bool b, int idx) {		// TODO: maybe there are some intrinsics for this...
		if (b) {
			bts(bits.ptr, idx);
		} else {
			btr(bits.ptr, idx);
		}
	}
	
	
	bool opIndex(int idx) {
		//return (bits[idx / Tbits] & (1 << (idx % Tbits))) != 0;
		return bt(bits.ptr, idx) != 0;
	}
	
	
	// opApply is evil, because it forces an inout index :F
	void iter(void delegate(uint i) dg) {
		uint off = 0;
		
		foreach (chunk; bits) {
			while (chunk != 0) {
				int idx = bsf(chunk);
				dg(off + idx);
				btr(&chunk, idx);
			}			
			
			off += Tbits;
		}
	}


	size_t length() {
		return minBits;
	}


	private {
		alias uint	T;
		const uint	Tbits = T.sizeof * 8;
		T[(minBits + Tbits - 1) / Tbits]
					bits;
	}
}


struct DynamicBitSet {
	const bool dynamic = true;

	enum { WordBits = size_t.sizeof * 8 }


	void dispose() {
		if (freeMem) {
			Memory.free(bits);
			freeMem = false;
		}
		bits = null;
	}
	

	void alloc(size_t count) {
		size_t size = (count+WordBits-1) / WordBits;
		if (bits.length != size) {
			if (bits !is null && freeMem) {
				Memory.realloc(bits, size);
			} else {
				dispose();
				Memory.alloc(bits, size);
			}
			freeMem = true;
		}
	}


	void alloc(size_t count, void* delegate(size_t) allocator) {
		size_t size = (count+WordBits-1) / WordBits;
		if (bits.length != size) {
			dispose();
			bits = (cast(size_t*)allocator(size*size_t.sizeof))[0..size];
		}		
	}
	
	
	size_t length() {
		return bits.length * WordBits;
	}


	void set(int i) {
		bits[i / WordBits] |= (1 << (i % WordBits));
	}


	bool isSet(int i) {
		return (bits[i / WordBits] & (1 << (i % WordBits))) != 0;
	}


	void clear(int i) {
		bits[i / WordBits] &= ~(1 << (i % WordBits));
	}


	void clearAll() {
		bits[] = 0;
	}


	private {
		size_t[]	bits;
		bool		freeMem = false;
	}
}



unittest {
	BitSet!(128) bs;
	static const int[] indices = [1, 3, 31, 55, 127];
	
	foreach (i; indices) bs[i] = true;
	foreach (i; indices) assert (bs[i] == true);
	foreach (i; indices) bs[i] = false;
	foreach (i; indices) assert (bs[i] == false);

	foreach (i; indices) bs[i] = true;
	{
		int i = 0;
		bs.iter((uint bi) {
			assert (indices[i++] == bi);
		});
	}

	foreach (i; indices) bs[i] = false;
	bs.iter((uint bi) {
		assert (false);
	});
}
