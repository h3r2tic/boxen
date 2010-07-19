module xf.nucleus.KernelCompiler;

private {
	import xf.nucleus.graph.KernelGraph;
	import xf.nucleus.codegen.Codegen;
	import xf.nucleus.codegen.Defs;
	import xf.gfx.Effect;
	import xf.gfx.IRenderer;
	import xf.mem.StackBuffer;

	import tango.io.stream.Format;
	import tango.io.device.Array;
	import tango.text.convert.Layout;

	import tango.io.device.File;
}

alias xf.nucleus.codegen.Defs.CodeSink CodeSink;
alias xf.nucleus.codegen.Defs.CodegenSetup CodegenSetup;
alias xf.nucleus.codegen.Defs.CodegenContext CodegenContext;



Effect compileKernelGraph(
	cstring name,
	KernelGraph kernel,
	CodegenSetup setup,
	CodegenContext* ctx,
	IRenderer renderer,
	void delegate(CodeSink) extraCodegen = null,
	EffectCompilationOptions opts = EffectCompilationOptions.init,
) {
	scope stack = new StackBuffer;
	const prealloc = 128 * 1024;	// 128KB should be enough for anyone :P
	
	auto layout = Layout!(char).instance;
	auto mem = stack.allocArrayNoInit!(char)(prealloc);
	
	scope arrrr = new Array(mem, 0);

	{
		scope fmt = new FormatOutput!(char)(layout, arrrr, "\n");
		if (ctx.sink is null) {
			ctx.sink = fmt;
		}

		if (extraCodegen) {
			extraCodegen(ctx.sink);
		}
		
		codegen(stack, kernel, setup, ctx);
		ctx.sink.flush();
	}
	
	char[1] zero = '\0';
	arrrr.write(zero[]);

	File.set("shader.tmp.cgfx", arrrr.slice());

	return renderer.createEffect(
		name,
		EffectSource.stringz(cast(char*)arrrr.slice().ptr),
		opts
	);
}
