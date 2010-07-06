module xf.nucleus.DepTracker;

private {
	import xf.Common;
	import xf.mem.SmallTempArray;
	import xf.mem.ChunkQueue;
}



struct DepTracker {
	struct DepArray {
		mixin MSmallTempArray!(DepTracker*);
	}

	static DepTracker opCall(DgAllocator allocator) {
		DepTracker res;
		res.allocator = allocator;
		return res;
	}

	DepArray	depArray;
	DgAllocator	allocator;
	bool		valid = true;

	void add(DepTracker* t) {
		depArray.pushBack(t, allocator);
	}
}


void invalidateGraph(Generator!(DepTracker*) genDepTrackers) {
	ChunkQueue!(DepTracker*) queue;
	scope (exit) {
		queue.dispose();
	}
	
	genDepTrackers((DepTracker* item) {
		queue.pushBack(item);
		item.valid = false;
	});

	while (!queue.isEmpty) {
		DepTracker* tracker;
		queue.popFront(&tracker);
		
		foreach (ref next; tracker.depArray.items()) {
			if (next.valid) {
				next.valid = false;
				queue.pushBack(next);
			}
		}
	}
}
