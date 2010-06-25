module xf.nucleus.KernelImpl;

private {
	import xf.Common;
	import xf.nucleus.graph.GraphDef;
	import xf.nucleus.kernel.KernelDef;
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
	
	Type type;


	static KernelImpl opCall(IGraphDef g) {
		KernelImpl res = void;
		res.graph = g;
		res.type = Type.Graph;
		return res;
	}

	static KernelImpl opCall(KernelDef k) {
		KernelImpl res = void;
		res.kernel = k;
		res.type = Type.Kernel;
		return res;
	}


	bool valid() {
		return graph !is null;
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