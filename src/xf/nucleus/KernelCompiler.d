module xf.nucleus.KernelCompiler;

private {
	import
		xf.nucleus.graph.KernelGraph,
		xf.nucleus.codegen.Codegen,
		xf.nucleus.codegen.Defs,
		xf.nucleus.KernelImpl,
		xf.nucleus.kernel.KernelDef,
		xf.nucleus.kdef.model.IKDefRegistry;
		
	import
		xf.gfx.Effect,
		xf.gfx.IRenderer,
		xf.gfx.Effect : GeomProgramInput, GeomProgramOutput;
		
	import xf.mem.StackBuffer;

	import
		tango.io.stream.Format,
		tango.io.device.Array,
		tango.text.convert.Layout,
		tango.io.device.File;
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
	IKDefRegistry registry,
	void delegate(CodeSink) extraCodegen = null,
	EffectCompilationOptions opts = EffectCompilationOptions.init,
) {
	scope stack = new StackBuffer;
	const prealloc = 128 * 1024;	// 128KB should be enough for anyone :P
	
	auto layout = Layout!(char).instance;
	auto mem = stack.allocArrayNoInit!(char)(prealloc);
	
	scope arrrr = new Array(mem, 0);

	if (!setup.gsNode.isValid) {
		foreach (nid, node; kernel.iterNodes) {
			if (
					KernelGraph.NodeType.Func == node.type
				&&	node.func.func.kernelDef
				&&	registry.isSubKernelOf(
						KernelImpl(cast(KernelDef)node.func.func.kernelDef),
						"GeometryShader"
					)
			) {
				setup.gsNode = nid;
				bool hasInTypeTag = false;
				bool hasOutTypeTag = false;
				
				foreach (t; node.func.func.tags) {
					cstring pt;
					if (t.startsWith(`gsin.`, &pt)) {
						hasInTypeTag = true;
						switch (pt) {
							case "POINT": opts.geomProgramInput = GeomProgramInput.Point; break;
							case "LINE": opts.geomProgramInput = GeomProgramInput.Line; break;
							case "LINE_ADJ": opts.geomProgramInput = GeomProgramInput.LineAdj; break;
							case "TRIANGLE": opts.geomProgramInput = GeomProgramInput.Triangle; break;
							case "TRIANGLE_ADJ": opts.geomProgramInput = GeomProgramInput.TriangleAdj; break;
							default:
								error("Unknown geometry shader input type: '{}'.", pt);
						}
					}
					if (t.startsWith(`gsout.`, &pt)) {
						hasOutTypeTag = true;
						switch (pt) {
							case "POINT": opts.geomProgramOutput = GeomProgramOutput.Point; break;
							case "LINE": opts.geomProgramOutput = GeomProgramOutput.Line; break;
							case "TRIANGLE": opts.geomProgramOutput = GeomProgramOutput.Triangle; break;
							default:
								error("Unknown geometry shader output type: '{}'.", pt);
						}
					}
				}

				if (!hasInTypeTag) {
					error(
						"Geometry shader func in kernel {}
						has no input primitive type specifier",
						name
					);
				}
				
				if (!hasOutTypeTag) {
					error(
						"Geometry shader func in kernel {}
						has no output primitive type specifier",
						name
					);
				}

				opts.useGeometryProgram = true;

				break;
			}
		}
	}

	{
		scope fmt = new FormatOutput!(char)(layout, arrrr, "\n");
		if (ctx.sink is null) {
			ctx.sink = fmt;
		}

		if (extraCodegen) {
			extraCodegen(ctx.sink);
		}
		
		codegen(stack, kernel, setup, ctx, registry);
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
