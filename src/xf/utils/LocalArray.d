module xf.utils.LocalArray;

private {
	import xf.Common;
	import xf.mem.StackBuffer;
	import xf.mem.MainHeap;
	import xf.mem.Array;
	import xf.mem.ArrayAllocator;
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
	Flags	_flags;
	
	
	static LocalArray opCall(size_t n, StackBufferUnsafe sb) {
		LocalArray res;
		if (0 == n) {
			return res;
		}
		res.data = sb.allocArrayNoInit!(T)(n, false);
		if (res.data is null) {
			res.data = (cast(T*)mainThreadHeap.allocRaw(T.sizeof * n))[0..n];
		} else {
			res._flags |= Flags.OnStack;
		}
		assert (res.data !is null);
		return res;
	}
	
	void dispose() {
		if (0 == (_flags & Flags.OnStack) && data.ptr !is null) {
			mainThreadHeap.freeRaw(data.ptr);
			data = null;
		}
	}
}


template LocalDynArrayAlloc() {
	private static import xf.mem.StackBuffer;
	private static import xf.mem.MainHeap;
	private static import tango.stdc.string;

	xf.mem.StackBuffer.StackBufferUnsafe	_stack;

	enum	Flags {
		None = 0,
		OnHeap = 0b1
	}
	Flags	_flags;


	static typeof(*this) opCall(xf.mem.StackBuffer.StackBufferUnsafe stack) {
		assert (stack !is null);
		typeof(*this) res;
		res._stack = stack;
		return res;
	}


	void* _reallocate(void* old, size_t oldBegin, size_t oldEnd, size_t size) {
		void* n;
		
		if (old !is null && (_flags & Flags.OnHeap)) {
			n = xf.mem.MainHeap.mainThreadHeap.reallocRaw(old, size);
		} else {
			n = _stack.allocArray!(ubyte)(size, false).ptr;
			if (n is null) {
				n = xf.mem.MainHeap.mainThreadHeap.allocRaw(size);
				_flags |= Flags.OnHeap;
			}

			if (old !is null) {
				tango.stdc.string.memcpy(n+oldBegin, old+oldBegin, oldEnd-oldBegin);
			}
		}

		return n;
	}
	
	void _dispose(void* ptr) {
		if (ptr !is null && (_flags & Flags.OnHeap) != 0) {
			xf.mem.MainHeap.mainThreadHeap.freeRaw(ptr);
		}
	}
}



template LocalDynArray(
		T,
		alias ExpandPolicy = ArrayExpandPolicy.FixedAmount!(64)
) {
	alias Array!(T, ExpandPolicy, LocalDynArrayAlloc) LocalDynArray;
}
