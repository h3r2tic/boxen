module Main;

import tango.core.tools.TraceExceptions;

import
	xf.Common,
	xf.gfx.api.gl3.OpenGL,
	xf.gfx.api.gl3.ext.WGL_EXT_swap_control,
	xf.gfx.api.gl3.ext.EXT_framebuffer_sRGB,
	xf.gfx.api.gl3.backend.Native,
	xf.gfx.gl3.Cg;


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
		effect.setArraySize("FragmentProgram.lights", 2);
		effect.setUniformType("FragmentProgram.lights[0]", "AmbientLight");
		effect.setUniformType("FragmentProgram.lights[1]", "PointLight");
		
		effect.compile();
	};
	

	while(context.created) {
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
