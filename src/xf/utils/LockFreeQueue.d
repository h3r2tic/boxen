module xf.utils.LockFreeQueue;



/// multi-write sequential-reading queue
struct MWSRQueue(T) {
	struct Node {
		Node*	next;
		T			value;
	}

	Node*	tail = null;
	Node*	head = null;


	void append(Node* newItem) {
		asm {
			naked;

			mov EDX, EAX;		// thisptr and &tail
			mov ECX, [ESP+4];	// newItem

			mov EAX, [EDX];		// the value of 'tail'
	retry:
			// if the value of 'tail' is what we previously read,
			// set it to the new value and know the old one in EAX
			// if the value changed since the last test, its value is
			// moved to EAX so we can just continue trying
			lock; cmpxchg [EDX], ECX;
			jnz retry;

			// if the value of 'tail' that we managed to change was 0,
			// then we just added the first item to the queue
			// otherwise (the more probable choice) is that we added
			// another item and must fix up the previous one's next ptr
			cmp EAX, 0;
			je setHead;

			mov [EAX], ECX;			// (previous tail).next = ECX;
			ret 4;
	setHead:
			mov [EDX+4], ECX;		// head = ECX;
			ret 4;
		}
	}


	/// NOT safe to use when appending items. NOT thread-safe.
	int opApply(int delegate(ref T) dg) {
		for (auto it = head; it; it = it.next) {
			if (auto r = dg(it.value)) {
				return r;
			}
		}
		return 0;
	}

	/// ditto
	int opApply(int delegate(ref int, ref T) dg) {
		int i = 0;
		for (auto it = head; it; ++i, it = it.next) {
			if (auto r = dg(i, it.value)) {
				return r;
			}
		}
		return 0;
	}
}
