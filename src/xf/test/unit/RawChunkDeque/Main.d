module Main;

import tango.core.tools.TraceExceptions;

import xf.Common;
import xf.mem.ChunkQueue;
import tango.io.Stdout;
import tango.text.convert.Format;



void main() {
	{
		auto q = RawChunkDeque(word.sizeof);
		scope (success) q.dispose();

		word head = 1;
		word tail = 0;
		const perIter = 100_000;
		const iters = 30;

		assert (q.isEmpty);

		for (auto i = 0; i < iters/2; ++i) {
			*cast(word*)q.pushFront() = --head;
			*cast(word*)q.pushBack() = ++tail;
		}

		assert (*cast(word*)q.popFront() == -iters/2+1);
		assert (*cast(word*)q.popBack() == iters/2);

		Stdout.formatln("Queue contents:");
		foreach (void* p; q) {
			Stdout.format(" {}", *cast(word*)p);
		}
		Stdout.formatln("\n");

		q.clear();

		head = 1;
		tail = 0;

		for (auto i = 0; i < iters/2; ++i) {
			for (auto j = 0; j < perIter; ++j) {
				*cast(word*)q.pushFront() = --head;
				*cast(word*)q.pushBack() = ++tail;
			}
		}

		void verify() {
			word x = head;
			foreach (void* p; q) {
				assert (*cast(word*)p == x, Format("expected {}, got {}", x, *cast(word*)p));
				++x;
			}
			foreach_reverse (void* p; q) {
				--x;
				assert (*cast(word*)p == x, Format("expected {}, got {}", x, *cast(word*)p));
			}
		}

		verify();

		for (auto i = 0; i < iters/2; ++i) {
			for (auto j = 0; j < perIter; ++j) {
				*cast(word*)q.pushFront() = --head;
			}
		}

		for (auto i = 0; i < iters/2; ++i) {
			for (auto j = 0; j < perIter; ++j) {
				*cast(word*)q.pushBack() = ++tail;
			}
		}

		verify();

		for (auto i = 0; i < iters/2; ++i) {
			for (auto j = 0; j < perIter; ++j) {
				assert (*cast(word*)q.popFront() == head++);
				assert (*cast(word*)q.popBack() == tail--);
			}
		}

		for (auto i = 0; i < iters/2; ++i) {
			for (auto j = 0; j < perIter; ++j) {
				assert (*cast(word*)q.popFront() == head++);
			}
		}

		for (auto i = 0; i < iters/2; ++i) {
			for (auto j = 0; j < perIter; ++j) {
				assert (*cast(word*)q.popBack() == tail--);
			}
		}

		assert (q.isEmpty());
	}

	Stdout.formatln("Test passed!");
}
