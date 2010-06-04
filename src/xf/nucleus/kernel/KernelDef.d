module xf.nucleus.kernel.KernelDef;

private {
	import xf.Common;
	import xf.nucleus.Defs;
	import xf.nucleus.Param;
	import xf.nucleus.Function;
}



class KernelDef {
	cstring				name;
	AbstractFunction[]	functions;
	KernelDef[]			superKernels;
	Param[]				attribs;
	word				renderingOrdinal = -1;
	Domain				domain;
	
	void*				bestImpl;		// QuarkDef
	word				bestImplScore;


	bool isSubkernelOf(KernelDef k) {
		foreach (s; superKernels) {
			if (s is k) {
				return true;
			}
		}

		foreach (s; superKernels) {
			if (s.isSubkernelOf(k)) {
				return true;
			}
		}
		
		return false;
	}
	

	AbstractFunction getFunction(cstring name) {
		foreach (f; functions) {
			if (f.name == name) {
				return f;
			}
		}
		return null;
	}
	
	
	/// Does not recompute superKernels!
	void overrideInheritList(cstring[] list) {
		this.inheritList = list;
	}
	
	
	cstring[] getInheritList() {
		return inheritList;
	}
	
	
	void overrideOrdering(cstring[] before, cstring[] after) {
		this.before = before;
		this.after = after;
	}
	
	
	cstring[] getKernelsBefore() {
		return before;
	}
	
	
	cstring[] getKernelsAfter() {
		return after;
	}
	
	
	// used by KDefProcessor
	void inherit(KernelDef supk) {
		superKernels ~= supk;
		before ~= supk.before;
		after ~= supk.after;
	}
	
	
	private {
		cstring[] inheritList;
		cstring[] before;
		cstring[] after;
	}
}
