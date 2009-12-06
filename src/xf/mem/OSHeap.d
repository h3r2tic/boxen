module xf.mem.OSHeap;

private {
	import xf.mem.Common;
	
	struct winapi {
		import xf.platform.win32.winbase;
		import xf.platform.win32.windef;
		import xf.platform.win32.winnt;
	}
	static import tango.core.Exception;
	
	//import tango.util.log.Trace;
}



private struct OSHeap {
	private template RefType(T) {
		static if (is(T == class)) {
			alias T RefType;
		} else {
			alias T* RefType;
		}
	}


	template alloc(T) {
		RefType!(T) alloc(Args ...)(Args args) {
			size_t size = void;
			
			static if (is(T == class)) {
				size = T.classinfo.init.length;
			} else {
				size = T.sizeof;
			}
			
			auto buf = allocRaw(size)[0..size];
			
			static if (is(T == class)) {
				buf[] = T.classinfo.init[];
				auto res = cast(T)cast(void*)buf.ptr;
				res._ctor(args);
				return res;
			} else static if (is(T == struct)) {
				T* res = cast(T*)buf.ptr;
				*res = T(args);
				return res;
			} else {
				T* res = cast(T*)buf.ptr;
				static if (1 == args.length) {
					*res = args[0];
				} else {
					static assert (0 == args.length);
					*res = T.init;
				}
				return res;
			}
		}
	}
	
	
	T[] allocArray(T)(size_t len) {
		auto res = allocArrayNoInit!(T)(len);
		foreach (ref r; res) {
			r = T.init;
		}
		return res;
	}
	

	T[] allocArrayNoInit(T)(size_t len) {
		size_t size = len * T.sizeof;
		return cast(T[])(allocRaw(size)[0..size]);
	}


	void* allocRaw(size_t size) {
		if (_heapId is null) {
			initialize();
		}
		return .winapi.HeapAlloc(_heapId, 0, size);
	}
	

	void freeRaw(void* ptr) {
		assert (_heapId !is null);
		.winapi.HeapFree(_heapId, 0, ptr);
	}


	bool initialized() {
		return _heapId !is null;
	}
	
	
	static size_t pageSize() {
		return _pageSize;
	}


	private {
		.winapi.HANDLE	_heapId;
		bool					serialize = false;

		void initialize() {
			// 1 MB by default
			_heapId = .winapi.HeapCreate(serialize ? 0 : .winapi.HEAP_NO_SERIALIZE, 1024 * 1024, 0);
			assert (_heapId !is null);
		}
		
		static {
			size_t _pageSize;
		}
	}
}


__thread OSHeap	threadHeap;
OSHeap				osHeap;

static this() {
	osHeap.serialize = true;
	.winapi.SYSTEM_INFO info;
	.winapi.GetSystemInfo(&info);
	OSHeap._pageSize = info.dwPageSize;
}
