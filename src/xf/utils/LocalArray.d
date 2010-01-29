module xf.utils.LocalArray;

private {
	import xf.mem.StackBuffer;
	import xf.mem.MainHeap;
}



/**
 * An array that exists either in the stack buffer or on a thread-local heap.
 * If there's enough space on the stack buffer to allocate it, it's put there,
 * otherwise it's allocated with mainThreadHeap and needs to be disposed
 * thereafter. For safety, always call the dispose() function as it's smart
 * enough to figure out whether the memory actually needs to be freed
 */
struct LocalArray(T) {
	T[]		data;
	enum	Flags {
		None = 0,
		OnStack = 0b1
	}
	Flags	flags;
	
	
	static LocalArray opCall(size_t n, StackBufferUnsafe sb) {
		LocalArray res;
		if (0 == n) {
			return res;
		}		
		res.data = sb.allocArray!(T)(n, false);
		if (res.data is null) {
			res.data = (cast(T*)mainThreadHeap.allocRaw(T.sizeof * n))[0..n];
		} else {
			res.flags |= Flags.OnStack;
		}
		return res;
	}
	
	void dispose() {
		if (0 == (flags & Flags.OnStack) && data.ptr !is null) {
			mainThreadHeap.freeRaw(data.ptr);
			data = null;
		}
	}
}
