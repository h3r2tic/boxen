module Main;

import tango.core.tools.TraceExceptions;
import xf.test.Common;

import xf.mem.StackBuffer;


void main() {
	int* addr1 = void;
	
	{
		scope buf = new StackBuffer;
		
		int* i1 = addr1 = buf.alloc!(int)(123);
		assertEqual(123, *i1);
		
		int* i2 = buf.alloc!(int)();
	}

	{
		void delegate()[] _tests;
		void test(void delegate() dg) {
			_tests ~= dg;
			// yes, all of them to verify there's no overwriting
			foreach (t; _tests) {
				t();
			}
		}
		
		scope buf = new StackBuffer;
		
		int* i1 = buf.alloc!(int)(456);
		test = {
			assertEqual(456, *i1);
			assertEqual(i1, addr1);
		};
		
		auto arr = buf.allocArray!(int)(100);
		test = {
			foreach (i; arr) {
				assertEqual(0, i);
			}
		};
	
		struct Foo {
			int a;
			float b;
			char[] c;
		}
		
		auto foo = buf.alloc!(Foo)(42, 3.14f, "poop");
		
		test = {
			assertEqual(foo.a, 42);
			assertEqual(foo.b, 3.14f);
			assertEqual(foo.c, "poop");
		};
		
		class Bar {
			int a = 42;
			float b;
			char[] c;
			this(float B, char[] C) {
				this.b = B;
				this.c = C;
			}
		}

		auto bar = buf.alloc!(Bar)(3.14f, "poop");
		
		test = {
			assertEqual(bar.a, 42);
			assertEqual(bar.b, 3.14f);
			assertEqual(bar.c, "poop");
		};
	}
	
	{
		scope buf = new StackBuffer;

		for (int x = 0; x < 4; ++x) {
			int*[] arr = buf.allocArray!(int*)(500_000);
			
			int* prev = null;
			for (int i = 0; i < 500_000; ++i) {
				int* cur = buf.alloc!(int)(i);
				assert (cur > prev);
				prev = cur;
				assertEqual(*cur, i);
				arr[i] = cur;
			}
			
			foreach (int i, p; arr) {
				assertEqual(*p, i);
			}
		}
	}

	{
		int* p1, p2, p3, p4, p5, p6;
		
		scope b1 = new StackBuffer;
		p1 = b1.alloc!(int)(1);
		{
			scope b2 = new StackBuffer;
			p2 = b2.alloc!(int)(2);
			b2.mergeWith(b1);
		}
		{
			scope b3 = new StackBuffer;
			p3 = b3.alloc!(int)(3);
			b3.mergeWith(b1);
		}
		{
			scope b4 = new StackBuffer;
			p4 = b4.alloc!(int)(4);
		}
		{
			scope b5 = new StackBuffer;
			p5 = b5.alloc!(int)(5);
		}
		{
			scope b6 = new StackBuffer;
			p6 = b6.alloc!(int)(6);
			b6.mergeWith(b1);
		}

		assert (1 == *p1);
		assert (2 == *p2);
		assert (3 == *p3);

		assert (p4 is p5);
		assert (p5 is p6);
		assert (6 == *p6);
	}
	
	{
		int* p2, p3, p4, p5, p6;
		
		scope b1 = new StackBuffer;
		{
			scope b2 = new StackBuffer;
			p2 = b2.alloc!(int)(2);
			b2.mergeWith(b1);
		}
		{
			scope b3 = new StackBuffer;
			p3 = b3.alloc!(int)(3);
			b3.mergeWith(b1);
		}
		{
			scope b4 = new StackBuffer;
			p4 = b4.alloc!(int)(4);
		}
		{
			scope b5 = new StackBuffer;
			p5 = b5.alloc!(int)(5);
		}
		{
			scope b6 = new StackBuffer;
			p6 = b6.alloc!(int)(6);
			b6.mergeWith(b1);
		}

		assert (2 == *p2);
		assert (3 == *p3);

		assert (p4 is p5);
		assert (p5 is p6);
		assert (6 == *p6);
	}

	{
		int* p1, p2, p3, p4, p5, p6, p7;
		
		scope b1 = new StackBuffer;
		{
			scope b2 = new StackBuffer;
			p2 = b2.alloc!(int)(2);
			b2.mergeWith(b1);
		}
		{
			scope b3 = new StackBuffer;
			p3 = b3.alloc!(int)(3);
			p7 = b1.alloc!(int)(7);
			b3.mergeWith(b1);
		}
		{
			scope b4 = new StackBuffer;
			p4 = b4.alloc!(int)(4);
		}
		{
			scope b5 = new StackBuffer;
			p5 = b5.alloc!(int)(5);
		}
		p1 = b1.alloc!(int)(1);
		{
			scope b6 = new StackBuffer;
			p6 = b6.alloc!(int)(6);
			b6.mergeWith(b1);
		}

		assert (1 == *p1);
		assert (2 == *p2);
		assert (3 == *p3);

		assert (p4 is p5);
		assert (p5 is p1);
		
		assert (6 == *p6);
		assert (7 == *p7);
	}

	StackBuffer.releaseThreadData();
	Trace.formatln("Test completed!");
}
