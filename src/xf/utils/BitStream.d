module xf.utils.BitStream;

private {
	import Convert = tango.util.Convert;
	import Intrinsic = std.intrinsic;

	alias size_t	uword;
	alias ptrdiff_t	word;

	version (BitStreamSpam) import tango.io.Stdout;
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
		*res.data = 0;
		return res;
	}

	void reset() {
		data = dataBlockStart;
		writeOffset = header;

		// just the first uword, the rest is set as the writing commences
		*data = 0;
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
			*d = w2;
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
			// no need to clear the first word
			
			if (off + bits == wordBits) {
				w <<= off;
				*d++ |= w;
				*d = 0;
				writeOffset += bits;
				data = d;
			} else if (off + bits < wordBits) {
				w <<= off;
				*d |= w;
				writeOffset += bits;
				data = d;
			} else {
				uword w1 = w, w2 = w;
				w1 <<= off;
				w2 >>= wordBits - off;
				*d++ |= w1;
				*d = w2;
				writeOffset += bits;
				data = d;
			}
		} else {
			// must overwrite the first word
			
			if (off + bits == wordBits) {
				w <<= off;
				*d++ = w;
				*d = 0;
				writeOffset += bits;
				data = d;
			} else if (off + bits < wordBits) {
				w <<= off;
				*d = w;
				writeOffset += bits;
				data = d;
			} else {
				assert (false);		// otherwise assert (bits <= wordBits); must fail
			}
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
		static if (is(T == bool)) {
			uword y = x ? 1 : 0;
			writeBits(y, 1);
		} else static if (T.sizeof > uword.sizeof) {
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

	alias opCall write;


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
		res.dataBlockStart = res.data;
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

		if (off + bits == wordBits) {
			uword w1 = *d++;
			w1 >>= off;
			*w = w1 & mask;
			data = d;
			readOffset += bits;
		} else if (off + bits < wordBits) {
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
		static if (is(T == bool)) {
			uword y;
			readBits(&y, 1);
			*x = (1 == y) ? true : false;
		} else static if (T.sizeof > uword.sizeof) {
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

		version (BitStreamSpam) Stdout.formatln("readGeneric({}) -> {}", T.stringof, *x);

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

	bool isEmpty() {
		return readOffset >= dataBlockSize;
	}


	int iterBits(int delegate(ref uword b) dg) {
		uword* d = dataBlockStart;
		for (word len = cast(word)dataBlockSize; len > 0; len -= wordBits, ++d) {
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
		str ~= Convert.to!(char[])(dataBlockSize);
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

	alias opCall read;


	uword*	data;
	uword*	dataBlockStart;
	uword	dataBlockSize;
	uword	readOffset = header;
}
