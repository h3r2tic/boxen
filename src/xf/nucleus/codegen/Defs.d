module xf.nucleus.codegen.Defs;

private {
	import xf.gfx.Defs : GPUDomain;
	import xf.nucleus.graph.KernelGraph;

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

