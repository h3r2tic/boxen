module xf.nucleus.KernelCompiler;

private {
	import xf.nucleus.graph.KernelGraph;
	import xt.nucleus.codegen.Codegen;
	import xf.gfx.Effect;
	import xf.gfx.IRenderer;
}



Effect compileKernelGraph(
	KernelGraph kernel,
	IRenderer renderer
) {
	codegen(kernel);
	// TODO
	return null;
}
