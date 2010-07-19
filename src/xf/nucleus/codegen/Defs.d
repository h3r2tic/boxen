module xf.nucleus.codegen.Defs;

private {
	import
		xf.Common,
		xf.mem.Array,
		xf.mem.ArrayAllocator;
	import
		xf.gfx.Defs : GPUDomain;
	import
		xf.nucleus.graph.KernelGraph,
		xf.nucleus.Function,
		xf.nucleus.Param;

	import tango.io.stream.Format;
}



alias FormatOutput!(char) CodeSink;
template ScrapArray(T) {
	alias Array!(
		T,
		ArrayExpandPolicy.FixedAmount!(64),
		ArrayAllocator.ScrapDg
	)
	ScrapArray;
}

struct EmittedFunc {
	Function	func;
	ParamList	params;
	cstring		name;
}

struct CodegenContext {
	CodeSink	sink;
	GPUDomain	domain;
	/+KernelGraph	graph;
	GPUDomain[]	nodeDomains;+/
	uint		indentSize;
	bool		delegate(cstring name, AbstractFunction*) getInterface;

	ScrapArray!(EmittedFunc)	emittedFuncs;
	ScrapArray!(cstring)		emittedComps;

	static CodegenContext opCall(DgAllocator alloc) {
		CodegenContext res;
		res.emittedFuncs._outerAllocator = alloc;
		res.emittedComps._outerAllocator = alloc;
		return res;
	}

	CodeSink	indent(uint extra = 0) {
		for (uint i = 0; i < indentSize+extra; ++i) {
			sink('\t');
		}
		return sink;
	}
}


struct CodegenSetup {
	KernelGraph	graph;
	GraphNodeId	inputNode;
	GraphNodeId	outputNode;
}
