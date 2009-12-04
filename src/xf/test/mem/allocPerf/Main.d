module Main;

import xf.test.Common;

import xf.mem.ThreadChunkAllocator;
import xf.mem.ChunkCache;
import tango.stdc.stdlib : malloc, free;


void main() {
	const int numTests = 2_000_000;
	const int chunkSize = 4 * 1024;
	
	Trace.formatln("Testing memory allocation and release performance");
	Trace.formatln("");
	
	for (int i = 1; i <= 4; i *= 2) {
		measure({
			auto chunk = threadChunkAllocator.alloc();
			chunk.dispose();
		}, numTests / i, i, "ThreadChunkAllocator");

		measure({
			auto chunk = chunkCache!(
				chunkSize - threadChunkAllocator.maxChunkOverhead,
				threadChunkAllocator
			).alloc();
			chunk.dispose();
		}, numTests / i, i, "ChunkCache");

		measure({
			auto chunk = malloc(chunkSize);
			free(chunk);
		}, numTests / i, i, "malloc");

		measure({
			auto chunk = new ubyte[](chunkSize);
			delete chunk;
		}, numTests / i, i, "new");
	}
}
