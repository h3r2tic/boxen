module xf.utils.GlobalThreadDataRegistry;



// warning: if a thread exits, its thread-locals are gone
template GlobalThreadDataRegistryM(T) {
	struct ThreadDataRegistry {
		private alias ThreadDataRegistry* PtrType;
		
		PtrType	_nextThread;
		bool		_globallyAdded;
		T			_value;		

		void register(T val) {
			//Stdout.formatln("registering");
			synchronized (g_registrationMutex) {
				_nextThread = g_firstThread;
				g_firstThread = this;
			}
			_globallyAdded = true;
			_value = val;
		}
	}
	
	private {
		alias ThreadDataRegistry* PtrType;
		__thread ThreadDataRegistry		t_registry;
	}

	static {
		PtrType								g_firstThread;
		Object								g_registrationMutex;

		void register(T val) {
			auto reg = &t_registry;
			if (!reg._globallyAdded) {
				t_registry.register(val);
			}
		}
		
		struct each {
			static int opApply(int delegate(ref T) dg) {
				for (auto it = g_firstThread; it; it = it._nextThread) {
					if (auto r = dg(it._value)) {
						return r;
					}
				}
				return 0;
			}

			static int opApply(int delegate(ref int, ref T) dg) {
				int i;
				for (auto it = g_firstThread; it; it = it._nextThread) {
					if (auto r = dg(i, it._value)) {
						return r;
					}
					++i;
				}
				return 0;
			}
		}
		
		void clearRegistrations() {
			if (g_firstThread) {
				PtrType it = g_firstThread;
				while (it) {
					PtrType next = it._nextThread;
					it._nextThread = null;
					it._globallyAdded = false;
					it = next;
				}
				g_firstThread = null;
			}
		}
		
		static this() {
			g_registrationMutex = new Object;
		}
	}
}
