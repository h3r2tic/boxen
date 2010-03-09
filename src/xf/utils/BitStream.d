module xf.utils.BitStream;

private {
	import Convert = tango.util.Convert;
	import Intrinsic = std.intrinsic;

	alias size_t	uword;
	alias ptrdiff_t	word;
}



// Little Endian only
struct BitStreamWriter {
	const header = 3;	// the first three bits contain the length (including header) modulo 8
	const wordBits = uword.sizeof * 8;


	/// storage = must be padded to words
	static BitStreamWriter opCall(void[] storage) {
		BitStreamWriter res;
		assert (storage.length % uword.sizeof == 0);
		res.data = res.dataBlockStart = cast(uword*)storage.ptr;
		res.dataBlockSize = storage.length * 8;
		return res;
	}

	void writeUWord(uword w) {
		assert (writeOffset + wordBits <= dataBlockSize);
		auto d = data;
		auto off = writeOffset % wordBits;
		if (off) {
			uword w1 = w, w2 = w;
			w1 <<= off;
			w2 >>= wordBits - off;
			*d++ |= w1;
			*d |= w2;
			writeOffset += wordBits;
			data = d;
		} else {
			*d++ = w;
			writeOffset += wordBits;
			data = d;
		}
	}

	void writeBits(uword w, uint bits) {
		{
			uword highMask = ~((1 << bits) - 1);
			assert (0 == (w & highMask));
		}
		assert (bits <= wordBits);
		assert (writeOffset + bits <= dataBlockSize);

		auto d = data;
		auto off = writeOffset % wordBits;
		if (off) {
			if (off + bits <= wordBits) {
				w <<= off;
				*d |= w;
				writeOffset += bits;
				data = d;
			} else {
				uword w1 = w, w2 = w;
				w1 <<= off;
				w2 >>= wordBits - off;
				*d++ |= w1;
				*d |= w2;
				writeOffset += bits;
				data = d;
			}
		} else {
			*d++ = w;
			writeOffset += bits;
			data = d;
		}
	}

	void writeUWordMinMax(uword x, uword min, uword max) {
		assert (max > min);
		x -= min;
		uword diff = max - min;

		static if (uword.sizeof > 4) {
			if (diff <= 0xFFFF_FFFF) {
				writeBits(x, cast(uint)Intrinsic.bsr(cast(uint)diff)+1);
			} else {
				writeBits(x, cast(uint)Intrinsic.bsr(cast(uint)(diff >> 32))+33);
			}
		} else {
			writeBits(x, cast(uint)Intrinsic.bsr(cast(uint)diff)+1);
		}
	}

	void writeCompact(uword x) {
		while (x != 0) {
			uword w = x;
			w <<= 1;
			w |= 1;
			writeBits(w, 8);
			x >>= 7;
		}
		writeBits(0, 1);
	}

	void writeRaw(void[] raw) {
		int bulk = raw.length / uword.sizeof;
		int rest = raw.length % uword.sizeof;
		ubyte* ptr = cast(ubyte*)raw.ptr;
		while (bulk--) {
			writeUWord(*cast(uword*)ptr);
			ptr += uword.sizeof;
		}
		while (rest--) {
			writeBits(*ptr, 8);
			++ptr;
		}
	}

	void writeString(char[] str) {
		writeCompact(str.length);
		writeRaw(cast(void[])str);
	}

	void flush() {
		uword d = *dataBlockStart;
		scope (success) *dataBlockStart = d;

		uword val = writeOffset % 8;
		d &= ~((1 << header) - 1);
		d |= val;
	}

	BitStreamWriter* writeGeneric(T)(T x) {
		static if (T.sizeof > uword.sizeof) {
			static assert (uword.sizeof * 2 == T.sizeof);
			writeUWord(*cast(uword*)&x);
			writeUWord(*(cast(uword*)&x+1));
		} else static if (T.sizeof == uword.sizeof) {
			writeUWord(*cast(uword*)&x);
		} else {
			uword y;
			*cast(T*)&y = x;
			writeBits(y, T.sizeof * 8);
		}
		return this;
	}

	BitStreamWriter* writeGenericMinMax(T)(T x, T min, T max) {
		static if (T.sizeof > uword.sizeof) {
			static assert (uword.sizeof * 2 == T.sizeof);
			T diff = max - min;
			x -= min;
			if (diff > uword.max) {
				writeUWord(*cast(uword*)&x);
				writeUWordMinMax(*(cast(uword*)&x+1), 0, *(cast(uword*)&diff+1));
			} else {
				writeUWordMinMax(*cast(uword*)&x, 0, *cast(uword*)&diff);
			}
		} else static if (T.sizeof == uword.sizeof) {
			writeUWordMinMax(*cast(uword*)&x, *cast(uword*)&min, *cast(uword*)&max);
		} else {
			uword y;
			uword ymin;
			uword ymax;
			*cast(T*)&y = x;
			*cast(T*)&ymin = min;
			*cast(T*)&ymax = max;
			writeUWordMinMax(y, ymin, ymax);
		}
		return this;
	}

	void writeFloat(float x) {
		static if (float.sizeof == uword.sizeof) {
			writeUWord(*cast(uword*)&x);
		} else {
			static assert (false, "meh, todo");
		}
	}

	alias writeFloat			opCall;
	alias writeString			opCall;
	alias writeGeneric!(bool)	opCall;
	alias writeGeneric!(byte)	opCall;
	alias writeGeneric!(ubyte)	opCall;
	alias writeGeneric!(short)	opCall;
	alias writeGeneric!(ushort)	opCall;
	alias writeGeneric!(int)	opCall;
	alias writeGeneric!(uint)	opCall;
	alias writeGeneric!(long)	opCall;
	alias writeGeneric!(ulong)	opCall;

	alias writeGenericMinMax!(byte)		opCall;
	alias writeGenericMinMax!(ubyte)	opCall;
	alias writeGenericMinMax!(short)	opCall;
	alias writeGenericMinMax!(ushort)	opCall;
	alias writeGenericMinMax!(int)		opCall;
	alias writeGenericMinMax!(uint)		opCall;
	alias writeGenericMinMax!(long)		opCall;
	alias writeGenericMinMax!(ulong)	opCall;


	int iterBits(int delegate(ref uword b) dg) {
		uword* d = dataBlockStart;
		for (word len = cast(word)writeOffset; len > 0; len -= wordBits, ++d) {
			word l = len;
			if (l > wordBits) l = wordBits;
			for (word i = 0; i < l; ++i) {
				uword b = ((*d & (1 << i)) != 0 ? 1 : 0);
				if (auto r = dg(b)) {
					return r;
				}
			}
		}
		return 0;
	}

	char[] toString() {
		char[] str;
		str ~= '(';
		str ~= Convert.to!(char[])(writeOffset);
		str ~= ") ";
		static assert (header <= 8);
		word i = 8 - header;
		foreach (b; &iterBits) {
			str ~= cast(char)('0' + b);
			if (i++ % 8 == 7) {
				str ~= ' ';
			}
		}
		return str;
	}

	ubyte[] asBytes() {
		return (cast(ubyte*)dataBlockStart)[0 .. (writeOffset + 7) / 8];
	}


	uword*	data;
	uword*	dataBlockStart;
	uword	dataBlockSize;
	uword	writeOffset = header;
}


struct BitStreamReader {
	const header = BitStreamWriter.header;
	const wordBits = uword.sizeof * 8;


	/// storage = must be padded to words
	/// bytes = must be the exact bytes read from the network, not including the padding on storage
	static BitStreamReader opCall(uword* storage, uint bytes) {
		BitStreamReader res;
		res.data = cast(uword*)storage;
		uword lenMod8 = *res.data & 0b111;
		res.dataBlockSize = (bytes * 8) - ((8 - lenMod8) & 0b111);
		assert (res.dataBlockSize % 8 == lenMod8);
		return res;
	}


	void readUWord(uword* w) {
		assert (readOffset + wordBits <= dataBlockSize);

		auto d = data;
		auto off = readOffset % wordBits;
		if (off) {
			uword w1 = *d++;
			uword w2 = *d;
			w1 >>= off;
			w2 <<= wordBits - off;
			*w = w1 | w2;
			data = d;
			readOffset += wordBits;
		} else {
			*w = *d++;
			data = d;
			readOffset += wordBits;
		}
	}

	void readBits(uword* w, uint bits) {
		assert (readOffset + bits <= dataBlockSize);

		auto d = data;
		auto off = readOffset % wordBits;
		uword mask = (1 << bits) - 1;

		if (off) {
			if (off + bits <= wordBits) {
				uword w1 = *d;
				w1 >>= off;
				*w = w1 & mask;
				data = d;
				readOffset += bits;
			} else {
				uword w1 = *d++;
				uword w2 = *d;
				w1 >>= off;
				w2 <<= wordBits - off;
				*w = (w1 | w2) & mask;
				data = d;
				readOffset += bits;
			}
		} else {
			*w = *d++ & mask;
			data = d;
			readOffset += bits;
		}
	}

	void readUWordMinMax(uword* x, uword min, uword max) {
		assert (max > min);
		uword val = 0;
		uword diff = max - min;

		static if (uword.sizeof > 4) {
			if (diff <= 0xFFFF_FFFF) {
				readBits(&val, cast(uint)Intrinsic.bsr(cast(uint)diff)+1);
			} else {
				readBits(&val, cast(uint)Intrinsic.bsr(cast(uint)(diff >> 32))+33);
			}
		} else {
			readBits(&val, cast(uint)Intrinsic.bsr(cast(uint)diff)+1);
		}

		val += min;
		*x = val;
	}

	void readCompact(uword* x) {
		uword val;
		uword w;
again:
		readBits(&w, 1);
		if (w) {
			val <<= 7;
			uword v;
			w = 0;
			readBits(&w, 7);
			val |= w;
			w = 0;
			goto again;
		}
		*x = val;
	}

	void readRaw(void[] raw) {
		int bulk = raw.length / uword.sizeof;
		int rest = raw.length % uword.sizeof;
		ubyte* ptr = cast(ubyte*)raw.ptr;
		while (bulk--) {
			readUWord(cast(uword*)ptr);
			ptr += uword.sizeof;
		}
		while (rest--) {
			uword x;
			readBits(&x, 8);
			*ptr = *cast(ubyte*)&x;
			++ptr;
		}
	}

	void readString(char[]* res, char[] delegate(uword) allocator) {
		uword len;
		readCompact(&len);
		char[] str = allocator(len);
		assert (str.length >= len);
		readRaw(cast(void[])str[0..len]);
		*res = str;
	}


	BitStreamReader* readGeneric(T)(T* x) {
		static if (T.sizeof > uword.sizeof) {
			static assert (uword.sizeof * 2 == T.sizeof);
			readUWord(cast(uword*)x);
			readUWord(cast(uword*)x+1);
		} else static if (T.sizeof == uword.sizeof) {
			readUWord(cast(uword*)x);
		} else {
			uword y;
			readBits(&y, T.sizeof * 8);
			*x = *cast(T*)&y;
		}
		return this;
	}

	BitStreamReader* readGenericMinMax(T)(T* x, T min, T max) {
		static if (T.sizeof > uword.sizeof) {
			static assert (uword.sizeof * 2 == T.sizeof);
			T diff = max - min;
			uword val;
			if (diff > uword.max) {
				readUWord(cast(uword*)&val);
				readUWordMinMax(cast(uword*)&val+1, 0, *(cast(uword*)&diff+1));
			} else {
				readUWordMinMax(cast(uword*)&val, 0, *cast(uword*)&diff);
			}
			val += min;
			*x = val;
		} else static if (T.sizeof == uword.sizeof) {
			readUWordMinMax(cast(uword*)x, *cast(uword*)&min, *cast(uword*)&max);
		} else {
			uword y;
			uword ymin;
			uword ymax;
			*cast(T*)&ymin = min;
			*cast(T*)&ymax = max;
			readUWordMinMax(&y, ymin, ymax);
			*x = *cast(T*)&y;
		}
		return this;
	}

	void readFloat(float* x) {
		static if (float.sizeof == uword.sizeof) {
			readUWord(cast(uword*)x);
		} else {
			static assert (false, "meh, todo");
		}
	}

	bool empty() {
		return readOffset >= dataBlockSize;
	}


	alias readFloat				opCall;
	alias readString			opCall;
	alias readGeneric!(bool)	opCall;
	alias readGeneric!(byte)	opCall;
	alias readGeneric!(ubyte)	opCall;
	alias readGeneric!(short)	opCall;
	alias readGeneric!(ushort)	opCall;
	alias readGeneric!(int)		opCall;
	alias readGeneric!(uint)	opCall;
	alias readGeneric!(long)	opCall;
	alias readGeneric!(ulong)	opCall;

	alias readGenericMinMax!(byte)		opCall;
	alias readGenericMinMax!(ubyte)		opCall;
	alias readGenericMinMax!(short)		opCall;
	alias readGenericMinMax!(ushort)	opCall;
	alias readGenericMinMax!(int)		opCall;
	alias readGenericMinMax!(uint)		opCall;
	alias readGenericMinMax!(long)		opCall;
	alias readGenericMinMax!(ulong)		opCall;


	uword*	data;
	uword	dataBlockSize;
	uword	readOffset = header;
}



unittest {
	new class {
		import tango.core.tools.TraceExceptions;
		import tango.math.random.Kiss;
		import tango.io.Stdout;
		import tango.text.convert.Format;
		import tango.stdc.stdio;

	this() {

	{
		void[] data = new void[1024];
		auto bsw = BitStreamWriter(data);

		bsw.flush();
		Stdout.formatln("{}", bsw);

		bsw.writeBits(0xFF, 8);
		bsw.flush();
		Stdout.formatln("{}", bsw);

		bsw.writeBits(0b1001, 4);
		bsw.flush();
		Stdout.formatln("{}", bsw);

		bsw.writeUWord(0);
		bsw.flush();
		Stdout.formatln("{}", bsw);

		bsw.writeUWord(0x12345678);
		bsw.flush();
		Stdout.formatln("{}", bsw);

		auto bsr = BitStreamReader(cast(uword*)data.ptr, bsw.asBytes.length);
		uword x;
		assert ((bsr.readBits(&x, 8), x == 0xFF));
		assert ((bsr.readBits(&x, 4), x == 0b1001));
		assert ((bsr.readUWord(&x), x == 0));
		assert ((bsr.readUWord(&x), x == 0x12345678));

		assert (bsr.readOffset == bsw.writeOffset);
	}

	{
		void[] data = new void[1024];
		long u = long.max, u2;
		int i = -42, iMin = -50, iMax = -12, i2;
		bool b = true, b2;
		float f = -float.max, f2;
		char[] cs = "sup lol", cs2;
		uint csMax = 47;
		uword lenWritten;

		{
			auto wr = BitStreamWriter(data);
			scope (success) wr.flush();
			wr(u);
			wr(i, iMin, iMax);
			wr(b);
			wr(f);
			wr(cs);
			lenWritten = wr.writeOffset;
		}
		{
			auto re = BitStreamReader(cast(uword*)data.ptr, (lenWritten+7)/8);

			re(&u2);
			assert(u == u2);

			re(&i2, iMin, iMax);
			assert(i == i2);

			re(&b2);
			assert(b == b2);
		
			re(&f2);
			assert(f == f2, Format("f={} f2={}", f, f2));

			re(&cs2, (uword meh) { return new char[meh]; } );
			assert(cs == cs2);

			assert (re.readOffset == lenWritten);
			assert (re.readOffset == re.dataBlockSize, Format("{} != {}", re.readOffset, re.dataBlockSize));
			assert (re.empty);
		}
	}

	{
		uword[] data = new uword[10_000_000];
		auto wr = BitStreamWriter(data);
		wr(true);
		wr(true);
		wr(true);
		
		const int numRandFloats = 100000;
		float[] randFloats = new float[numRandFloats];
		for (int i = 0; i < numRandFloats; ++i) {
			randFloats[i] = cast(float)Kiss.instance.fraction();
		}
		randFloats[0] = 0.f;
		randFloats[1] = -0.f;
		
		const int numRandBools = 100000;
		bool[] randBools = new bool[numRandBools];
		for (int i = 0; i < numRandBools; ++i) {
			randBools[i] = Kiss.instance.natural % 2 == 0;
		}
		
		for(ushort u = 0; u < ushort.max; u++) {
			bool blah = u % 2 == 0;
			wr(blah);
			wr(u);
		}
		for(short u = short.min; u < short.max; u++) {
			wr(u);
		}

		for (int i = 0; i < numRandFloats; ++i) {
			wr(randFloats[i]);
		}
		
		foreach (i, b; randBools) {
			wr(b);
		}
		
		wr(42U);
		wr(75834U);
		wr(473U);
		wr(uint.max);
		wr(-1);
		wr("onoz i can has string"[]);
		wr.flush();

		auto re = BitStreamReader(data.ptr, wr.asBytes.length);
		bool meh;
		re(&meh);
		re(&meh);
		re(&meh);
		assert (meh);

		{
			for(ushort u = 0; u < ushort.max; u++) {
				bool blah;
				re(&blah);
				assert (blah == (u % 2 == 0));
				ushort v = 0;
				re(&v);
				//printf("Testing: %u read as %u\n", u, v);
				if(u != v) {
					printf("FAILED TEST: %u was read as %u\n", u, v);
					assert(false, "Failed exhaustive ushort test");
				}
			}
			for(short u = short.min; u < short.max; u++) {
				short v = 0;
				re(&v);
				//printf("Testing: %u read as %u\n", u, v);
				if(u != v) {
					printf("FAILED TEST: %u was read as %u\n", u, v);
					assert(false, "Failed exhaustive short test");
				}
			}
		}

		for (int i = 0; i < numRandFloats; ++i) {
			float r = 12345;
			re(&r);
			assert (randFloats[i] == r, Format("{}: got {}({:x}) instead of {}({:x})", i, r, *cast(uint*)&r, randFloats[i], *cast(uint*)&randFloats[i]));
		}

		foreach (i, b; randBools) {
			bool b2;
			re(&b2);
			assert (b == b2);
		}

		uint foo, bar, baz, eggs;
		int bacon;
		re(&foo);
		re(&bar);
		re(&baz);
		re(&eggs);
		re(&bacon);
		assert(foo == 42U);
		assert(bar == 75834U);
		assert(baz == 473U);
		assert(eggs == uint.max);
		assert(bacon == -1);
		
		char[] spam;
		re(&spam, (uword meh) { return new char[meh]; } );
		assert("onoz i can has string" == spam);

		assert (wr.writeOffset == re.readOffset);
		assert (re.empty);
	}

	Stdout.formatln("All tests passed");

	}};
}
