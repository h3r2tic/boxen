module xf.nucleus.KernelImpl;

private {
	import xf.Common;
	import xf.nucleus.Defs;
	import xf.nucleus.graph.GraphDef;
	import xf.nucleus.kernel.KernelDef;
	import xf.nucleus.DepTracker;
}


struct KernelImpl {
	enum Type {
		Kernel,
		Graph
	}

	union {
		IGraphDef	graph;
		KernelDef	kernel;
	}
	
	KernelImplId	id;
	Type			type;


	static KernelImpl opCall(IGraphDef g) {
		KernelImpl res = void;
		res.graph = g;
		res.id = KernelImplId.invalid;
		res.type = Type.Graph;
		return res;
	}

	static KernelImpl opCall(KernelDef k) {
		KernelImpl res = void;
		res.kernel = k;
		res.id = KernelImplId.invalid;
		res.type = Type.Kernel;
		return res;
	}


	bool opEquals(ref KernelImpl other) {
		if (type != other.type) {
			return false;
		}

		switch (type) {
			case KernelImpl.Type.Graph: {
				return graph.opEquals(other.graph);
			}
			
			case KernelImpl.Type.Kernel: {
				return kernel.opEquals(other.kernel);
			}
			
			default: assert (false);
		}
	}


	DepTracker* dependentOnThis() {
		switch (type) {
			case KernelImpl.Type.Graph: {
				return graph.dependentOnThis();
			}
			
			case KernelImpl.Type.Kernel: {
				return kernel.dependentOnThis();
			}
			
			default: assert (false);
		}
	}


	void invalidate() {
		dependentOnThis.valid = false;
	}

	bool isValid() {
		return dependentOnThis.valid;
	}
	

	bool isNull() {
		return graph is null;
	}


	char[] name() {
		switch (type) {
			case KernelImpl.Type.Graph: {
				return graph.name;
			}
			
			case KernelImpl.Type.Kernel: {
				return kernel.func.name;
			}
			
			default: assert (false);
		}
	}
}
