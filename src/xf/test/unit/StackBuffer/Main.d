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
	
	StackBuffer.releaseThreadData();
	Trace.formatln("Test completed!");
}
