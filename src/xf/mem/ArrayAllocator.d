module xf.mem.ArrayAllocator;



interface ArrayExpandPolicy {
	template FixedAmount(int count) {
		template FixedAmount(int _count = count) {
			void _expand(size_t num) {
				if (num < _count) {
					_capacity += _count;
				} else {
					_capacity += (num + _count - 1) / _count * _count;
				}
			}
		}
	}

	template Exponential(int _mult) {
		static assert (false, `TODO`);
	}
}


/**
 * Allocators must implement a function of the following signature:
 * void* function(void* old, size_t oldStart, size_t oldEnd, size_t size);
 * @old is the pointer that was previously allocated by this allocator, or null
 * @oldStart and @oldEnd mark the range of data that must be copied from the previously
 *  allocated memory block if reallocation in place fails
 * @size is the size requested for the new allocation.
 *
 * Assuming that bytes > oldEnd, the contents of the previously allocated memory
 * can be copied via: memcpy(n+oldBegin, old+oldBegin, oldEnd-oldBegin); where 'n' is
 * a pointer to the newly allocated memory block
 */
interface ArrayAllocator {
	template MainHeap() {
		private static import xf.mem.MainHeap;


		void* _reallocate(void* old, size_t, size_t, size_t size) {
			assert (size != 0);
			void* res = xf.mem.MainHeap.mainHeap.reallocRaw(old, size);
			assert (res !is null);
			return res;
		}
		
		void _dispose(void* ptr) {
			xf.mem.MainHeap.mainHeap.freeRaw(ptr);
		}
	}
}
