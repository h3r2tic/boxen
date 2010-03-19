module Main;

import tango.core.tools.TraceExceptions;
import xf.utils.BitStream;

import tango.math.random.Kiss;
import tango.io.Stdout;
import tango.text.convert.Format;
import tango.stdc.stdio;


char[] genProlog(char[] wrName) {
	return `
		for (int bo = 0; bo < bitOffset; ++bo) {
			`~wrName~`.write(bo % 2 == 0);
		}
	`;
}


char[] genEpilog(char[] rName) {
	return `
		for (int bo = 0; bo < bitOffset; ++bo) {
			`~rName~`.read(&_poop);
			assert (_poop == (bo % 2 == 0));
		}
	`;
}


void main() {
	bool _poop;
	int globalRepeats = 3;

	while (globalRepeats--)
	for (int bitOffset = 0; bitOffset < size_t.sizeof * 8; ++bitOffset) {
	
	{
		void[] data = new void[1024];
		foreach (ref uint x; cast(uint[])data) {
			x = Kiss.instance.natural();
		}
		
		auto bsw = BitStreamWriter(data);
		mixin(genProlog("bsw"));

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
		mixin(genEpilog("bsr"));
		uword x;
		assert ((bsr.readBits(&x, 8), x == 0xFF));
		assert ((bsr.readBits(&x, 4), x == 0b1001));
		assert ((bsr.readUWord(&x), x == 0));
		assert ((bsr.readUWord(&x), x == 0x12345678));

		assert (bsr.readOffset == bsw.writeOffset);

		delete data;
	}

	{
		void[] data = new void[1024];
		foreach (ref uint x; cast(uint[])data) {
			x = Kiss.instance.natural();
		}

		long u = long.max, u2;
		int i = -42, iMin = -50, iMax = -12, i2;
		bool b = true, b2;
		float f = -float.max, f2;
		char[] cs = "sup lol", cs2;
		uint csMax = 47;
		uword lenWritten;

		{
			auto wr = BitStreamWriter(data);
			mixin(genProlog("wr"));
			scope (success) wr.flush();
			wr(u);
			wr(i, iMin, iMax);
			wr(b);
			wr(f);
			wr(cs);
			lenWritten = wr.writeOffset;

			Stdout.formatln("{}", wr.toString);
		}
		{
			auto re = BitStreamReader(cast(uword*)data.ptr, (lenWritten+7)/8);
			mixin(genEpilog("re"));

			re(&u2);
			assert(u == u2);

			re(&i2, iMin, iMax);
			assert(i == i2);

			re(&b2);
			assert(b == b2);
		
			re(&f2);
			assert(f == f2, Format("f={} f2={}", f, f2));

			re(&cs2, (uword meh) { return new char[meh]; } );
			assert(cs == cs2, Format("cs='{}' cs2='{}'", cs, cs2));

			assert (re.readOffset == lenWritten);
			assert (re.readOffset == re.dataBlockSize, Format("{} != {}", re.readOffset, re.dataBlockSize));
			assert (re.isEmpty);
		}

		delete data;
	}

	{
		uword[] data = new uword[10_000_000];
		foreach (ref uint x; cast(uint[])data) {
			x = Kiss.instance.natural();
		}

		auto wr = BitStreamWriter(data);
		mixin(genProlog("wr"));
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
		mixin(genEpilog("re"));
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
		assert (re.isEmpty);

		delete data;
	}

	}

	Stdout.formatln("All tests passed");
}
