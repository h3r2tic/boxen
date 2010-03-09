// just a proof of concept at the moment; needs refactoring into a proper module
module xf.utils.PMC;

private {
	import xf.platform.win32.windef;
	import xf.platform.win32.winbase;
}




union MSR {
	ulong val;
	struct {
		uint lo;
		uint hi;
	}
}

struct WinRing0 {
static:
	bool	initialized;

	bool wrmsr(uint addr, MSR r) {
		assert (initialized);
		return 1 == Wrmsr(addr, r.lo, r.hi);
	}

	bool rdmsr(uint addr, MSR* r) {
		assert (initialized);
		return 1 == Rdmsr(addr, &r.lo, &r.hi);
	}

private:
	HMODULE lib;

	extern (Windows) {
		BOOL function() InitializeOls;
		void function() DeinitializeOls;
		uint function() GetDllStatus;
		BOOL function(uint, uint*, uint*) Rdmsr;
		BOOL function(uint, uint, uint) Wrmsr;
	}

	static this() {
		lib = LoadLibrary("WinRing0.dll");
		InitializeOls = cast(typeof(InitializeOls))GetProcAddress(lib, "InitializeOls");
		assert (InitializeOls !is null);
		DeinitializeOls = cast(typeof(DeinitializeOls))GetProcAddress(lib, "DeinitializeOls");
		assert (DeinitializeOls !is null);
		GetDllStatus = cast(typeof(GetDllStatus))GetProcAddress(lib, "GetDllStatus");
		assert (GetDllStatus !is null);
		Rdmsr = cast(typeof(Rdmsr))GetProcAddress(lib, "Rdmsr");
		assert (Rdmsr !is null);
		Wrmsr = cast(typeof(Wrmsr))GetProcAddress(lib, "Wrmsr");
		assert (Wrmsr !is null);

		InitializeOls();
		uint err = GetDllStatus();
		if (0 == err) {
			printf("WinRing0 initialized.\n");
			initialized = true;
		} else {
			char* errMsg;
			switch (err) {
				case 1: errMsg = "Unsupported platform"; break;
				case 2: errMsg = "Driver not loaded"; break;
				case 3: errMsg = "Driver not found"; break;
				case 4: errMsg = "Driver unloaded"; break;
				case 5: errMsg = "Driver not loaded on network"; break;
				default: errMsg = "Unknown error"; break;
			}
			printf("WinRing0 failed to initialize: %s.\n", errMsg);
		}
	}

	static ~this() {
		if (DeinitializeOls) {
			DeinitializeOls();
		}
	}
}

extern (Windows) extern int MessageBoxA(      
    HWND hWnd,
    LPCTSTR lpText,
    LPCTSTR lpCaption,
    UINT uType
);


// these occupy a contiguous block
const IA32_PMC0 = 0xC1;
const IA32_PERFEVTSEL0 = 0x186;
const IA32_PERF_FIXED_CTR0 = 0x309;
const IA32_FIXED_CTR_CTRL = 0x38d;



struct ThreadInfo {
	struct Perf {
		ulong		tsc;
		ulong		instRetired;
		ulong		clkUnhaltedCore;
		ulong		clkUnhaltedRef;
		ulong[4]	archCntr;
	}
	Perf	prev;
	Perf	cur;


	void worker() {
		auto perfInfo = PerfInfo();
		final MSR zero;

		void startArchCntr(int idx, ubyte uMask, ubyte evSel) {
			MSR ctrl;
			ctrl.val |= evSel;
			ctrl.val |= (cast(ulong)uMask) << 8;
			ctrl.val |= (cast(ulong)1) << 16;		// rings 1..3
			ctrl.val |= (cast(ulong)1) << 22;		// enable

			if (WinRing0.wrmsr(IA32_PERFEVTSEL0+idx, ctrl)) {
			} else {
				synchronized (Object.classinfo) printf("Failed to enable architectural counter.\n");
			}
		}

		if (perfInfo.ver >= 1) {
			// start the architectural counters
			startArchCntr(0, 0x41, 0x2e);	// llc misses
			startArchCntr(1, 0x4f, 0x2e);	// llc references
//			startArchCntr(0, 0x00, 0xc5);	// branch misses retired
//			startArchCntr(1, 0x00, 0xc4);	// branches retired
		}

		if (perfInfo.ver >= 2) {
			// start the fixed-function counters
			MSR fixedCtrl;

			for (int i = 0; i < perfInfo.numFixedCntrs; ++i) {
				fixedCtrl.val <<= 4;
				fixedCtrl.val |= 0b10;	// enable in rings 1..3
			}

			if (WinRing0.wrmsr(IA32_FIXED_CTR_CTRL, fixedCtrl)) {
//				synchronized (Object.classinfo) printf("Enabled fixed-function counters.\n");
			} else {
				synchronized (Object.classinfo) printf("Failed to enable fixed-function counters.\n");
			}
		}


		while (!PMCInfo.deactivating) {
			MSR msr;
			if (WinRing0.rdmsr(IA32_PERF_FIXED_CTR0, &msr)) {
				cur.instRetired = msr.val & perfInfo.fixedFunctionCounterMask;
			}
			if (WinRing0.rdmsr(IA32_PERF_FIXED_CTR0+1, &msr)) {
				cur.clkUnhaltedCore = msr.val & perfInfo.fixedFunctionCounterMask;
			}
			if (WinRing0.rdmsr(IA32_PERF_FIXED_CTR0+2, &msr)) {
				cur.clkUnhaltedRef = msr.val & perfInfo.fixedFunctionCounterMask;
			}

			if (WinRing0.rdmsr(IA32_PMC0, &msr)) {
				cur.archCntr[0] = msr.val & perfInfo.architecturalCounterMask;
			}
			if (WinRing0.rdmsr(IA32_PMC0+1, &msr)) {
				cur.archCntr[1] = msr.val & perfInfo.architecturalCounterMask;
			}

			uint tscLo, tscHi;
			asm {
				rdtsc;
				mov [tscLo], EAX;
				mov [tscHi], EDX;
			}

			cur.tsc = cast(ulong)tscLo | ((cast(ulong)tscHi) << 32);

			Sleep(1);
		}
	}
}


struct PMCInfo {
static:
	ThreadInfo[] threads;

	private {
		const maxThreads = 32;
		ThreadInfo[maxThreads] _threads;

		extern (Windows) static uint threadProc(void* param) {
			(cast(ThreadInfo*)param).worker();
			return 0;
		}

		static this() {
			uint procAffinity, sysAffinity;
			GetProcessAffinityMask(GetCurrentProcess(), &procAffinity, &sysAffinity);

			uint usedThreads = 0;
			for (int i = 0; i < maxThreads; ++i) {
				if (procAffinity & (1 << i)) {
					ThreadInfo* tInfo = &_threads[usedThreads++];
					auto th = CreateThread(
						null,
						64 * 1024,
						&threadProc,
						tInfo,
						CREATE_SUSPENDED,
						null
					);
					assert (th !is null);
					int res = SetThreadAffinityMask(th, 1 << i);
					assert (res != 0);
					ResumeThread(th);
				}
			}

			threads = _threads[0..usedThreads];
		}

		bool deactivating = false;
		static ~this() {
			deactivating = true;
		}
	}
}


struct PerfInfo {
	uint ver;
	uint countersPerProc;
	uint counterBitWidth;
	uint featureBitVecLen;
	uint featureBitVec;
	uint numFixedCntrs;
	uint fixedCounterBitWidth;
	ulong fixedFunctionCounterMask = 0;
	ulong architecturalCounterMask = 0;


	static PerfInfo opCall() {
		PerfInfo res;

		uint eax, ebx, ecx, edx;
		asm {
			mov EAX, 0xa;
			cpuid;
			mov [eax], EAX;
			mov [ebx], EBX;
			mov [ecx], ECX;
			mov [edx], EDX;
		}

		res.featureBitVecLen = (eax >> 24) & 0xff;
		res.featureBitVec = ebx;

		res.ver = eax & 0xff;
		if (res.ver > 0) {
			res.countersPerProc = (eax >> 8) & 0xff;
			res.counterBitWidth = (eax >> 16) & 0xff;

			res.architecturalCounterMask = 1;
			res.architecturalCounterMask <<= res.counterBitWidth;
			res.architecturalCounterMask -= 1;

			if (res.ver > 1) {
				res.numFixedCntrs = edx & 0b11111;
				res.fixedCounterBitWidth = (edx >> 5) & 0xff;
				res.fixedFunctionCounterMask = 1;
				res.fixedFunctionCounterMask <<= res.fixedCounterBitWidth;
				res.fixedFunctionCounterMask -= 1;
			}
		}

		return res;
	}


	void print() {
		if (ver > 0) {
			printf("Architectural performance monitoring version %d supported.\n", ver);
			printf("\tCounters per logical processor: %d.\n", countersPerProc);
			printf("\tCounter bit width: %d.\n", counterBitWidth);

			char*[] featureNames = [
				"Core cycle",
				"Instruction retired",
				"Reference cycles",
				"Last-level cache reference",
				"Last-level cache misses",
				"Branch instruction retired",
				"Branch mispredict retired"
			];

			printf("\tFeatures:\n");

			for (int i = 0; i < featureBitVecLen; ++i) {
				char* name = "Unknown feature";
				if (i < featureNames.length) {
					name = featureNames[i];
				}
				char* support = 0 == (featureBitVec & (1 << i)) ? "supported".ptr : "NOT supported".ptr;
				printf("\t\t%s %s.\n", name, support);
			}

			if (ver > 1) {
				printf("\tNumber of fixed-function counters: %d\n", numFixedCntrs);
				printf("\tBit-width of fixed-function counters: %d\n", fixedCounterBitWidth);
			}
		} else {
			printf("Architectural performance monitoring NOT supported.\n");
		}
	}
}


import tango.stdc.stdio;

void main() {
	printf("Created %d PMC loggers\n", PMCInfo.threads.length);
	PerfInfo().print();
	printf("\n\n");

	while (true) {
		printf("\r");
		foreach (ref th; PMCInfo.threads) {
			ulong retired = th.cur.instRetired - th.prev.instRetired;
			ulong cycles = th.cur.clkUnhaltedCore - th.prev.clkUnhaltedCore;
			ulong clk = th.cur.tsc - th.prev.tsc;
			ulong llcMisses = th.cur.archCntr[0] - th.prev.archCntr[0];
			ulong llcRefs = th.cur.archCntr[1] - th.prev.archCntr[1];
//			float metric = cast(float)(cast(real)retired / cycles);
//			float metric = cast(float)(cast(real)llcMisses / retired);
			float metric = cast(float)(cast(real)llcMisses / llcRefs);
			printf(" (%1.1f%%)%2.2f", cast(float)cycles*100/clk, metric);
			th.prev = th.cur;
		}

		printf("     ");
		fflush(stdout);
		Sleep(1000);
	}
}

