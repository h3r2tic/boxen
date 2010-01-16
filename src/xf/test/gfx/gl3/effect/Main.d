module Main;

import tango.core.tools.TraceExceptions;

import
	xf.Common,
	
	xf.gfx.api.gl3.OpenGL,
	xf.gfx.api.gl3.ext.WGL_EXT_swap_control,
	xf.gfx.api.gl3.ext.EXT_framebuffer_sRGB,
	xf.gfx.api.gl3.backend.Native,
	xf.gfx.gl3.Cg,
	xf.omg.core.LinearAlgebra,
	
	tango.io.Stdout;


void main() {
	auto context = GLWindow();
	context
		.title("Effect Test")
		.showCursor(true)
		.fullscreen(false)
		.width(320)
		.height(240)
	.create();
	

	CgCompiler compiler;

	use(context) in (GL gl) {
		gl.SwapIntervalEXT(1);
		gl.Enable(FRAMEBUFFER_SRGB_EXT);
		
		compiler = new CgCompiler;
		
		auto effect = compiler.createEffect(
			"sample",
			EffectSource.filePath("sample.cgfx")
		);

		effect.useGeometryProgram = false;
		effect.setArraySize("lights", 2);
		effect.setUniformType("lights[0]", "AmbientLight");
		effect.setUniformType("lights[1]", "PointLight");
		effect.compile();
		
		effect.getUniformIndex("lights[0].color");
		try {
			effect.getUniformIndex("lights[0].error");
			Stdout.formatln("Effect error reporting FAIL. This was supposed to throw.");
		}
		catch (Exception e) {
			Stdout.formatln("Effect error reporting OK.");
		}
		
		Stdout.formatln("Effect uniforms:");
		for (int i = 0; i < effect.uniformParams.length; ++i) {
			Stdout.formatln("\t{}", effect.uniformParams.name[i]);
		}

		Stdout.formatln("Effect varyings:");
		for (int i = 0; i < effect.varyingParams.length; ++i) {
			Stdout.formatln("\t{}", effect.varyingParams.name[i]);
		}
		
		auto efInst = effect.instantiate();
		
		efInst.setUniform("lights[0].color", vec4.one);
	};
	

	while (context.created) {
		use(context) in (GL gl) {
			draw(gl);
		};
		
		context.update().show();
		Thread.yield();
	}
}


void draw(GL gl) {
	gl.Clear(COLOR_BUFFER_BIT | DEPTH_BUFFER_BIT);
	// TODO
}
