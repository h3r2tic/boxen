module xf.nucleus.codegen.Defs;

private {
	import xf.Common;
	import xf.gfx.Defs : GPUDomain;
	import xf.nucleus.graph.KernelGraph;
	import xf.nucleus.Function;

	import tango.io.stream.Format;
}



alias FormatOutput!(char) CodeSink;

struct CodegenContext {
	CodeSink	sink;
	GPUDomain	domain;
	KernelGraph	graph;
	GPUDomain[]	nodeDomains;
	uint		indentSize;

	CodeSink	indent() {
		for (uint i = 0; i < indentSize; ++i) {
			sink('\t');
		}
		return sink;
	}
}


struct CodegenSetup {
	GraphNodeId	inputNode;
	GraphNodeId	outputNode;
	bool		delegate(cstring name, AbstractFunction*) getInterface;
}
