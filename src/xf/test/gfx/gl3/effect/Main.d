module Main;

import
	tango.core.tools.TraceExceptions,
	xf.Common,
	
	xf.gfx.api.gl3.OpenGL,
	xf.gfx.api.gl3.ext.WGL_EXT_swap_control,
	xf.gfx.api.gl3.ext.EXT_framebuffer_sRGB,
	xf.gfx.api.gl3.backend.Native,
	xf.gfx.gl3.Renderer,
	
	xf.omg.core.LinearAlgebra,	
	xf.gfx.misc.Primitives,
	tango.io.Stdout;
	


void main() {
	auto context = GLWindow();
	context
		.title("Effect Test")
		.showCursor(true)
		.fullscreen(false)
		.width(800)
		.height(600)
	.create();
	

	Renderer	renderer;
	Mesh		mesh;

	use(context) in (GL gl) {
		renderer = new Renderer(gl);
		
		gl.SwapIntervalEXT(1);
		gl.Enable(FRAMEBUFFER_SRGB_EXT);
		gl.Enable(DEPTH_TEST);
		
		// Create the effect from a cgfx file
		
		auto effect = renderer.createEffect(
			"sample",
			EffectSource.filePath("sample.cgfx")
		);
		
		// Specialize the shader template with 2 lights
		// - an ambient and a point light

		effect.useGeometryProgram = false;
		effect.setArraySize("lights", 2);
		effect.setUniformType("lights[0]", "AmbientLight");
		effect.setUniformType("lights[1]", "PointLight");
		effect.compile();
		
		// ---- Some debug info printing ----
		{
			with (*effect.uniformParams()) {
				getUniformIndex("lights[0].color");
				try {
					getUniformIndex("lights[0].error");
					Stdout.formatln("Effect error reporting FAIL. This was supposed to throw.");
				}
				catch (Exception e) {
					Stdout.formatln("Effect error reporting OK.");
				}
				
				Stdout.formatln("Effect uniforms:");
				for (int i = 0; i < params.length; ++i) {
					Stdout.formatln("\t{}", params.name[i]);
				}
			}

			Stdout.formatln("Effect varyings:");
			for (int i = 0; i < effect.varyingParams.length; ++i) {
				Stdout.formatln("\t{}", effect.varyingParams.name[i]);
			}
		}
		
		// Instantiate the effect and initialize its uniforms

		final efInst = renderer.instantiateEffect(effect);
		
		efInst.setUniform("lights[0].color",
			vec4(0.0f, 0.0f, 0.01f)
		);
		efInst.setUniform("lights[1].color",
			vec4(1.0f, 0.7f, 0.4f) * 2.f
		);
		
		efInst.setUniform("modelToWorld",
			mat4.translation(vec3(0, 0, -3)) *
			mat4.xRotation(30.0f) *
			mat4.yRotation(30.0f)
		);
		
		effect.setUniform("worldToScreen",
			mat4.perspective(
				90.0f,	// fov
				cast(float)context.width / context.height,	// aspect
				0.1f,	// near
				100.0f	// far
			)
		);
		
		// Create a vertex buffer and bind it to the shader
		
		auto vb = renderer.createVertexBuffer();
		
		struct Vertex {
			vec3	pos;
			vec3	norm;
		}

		efInst.setVarying(
			"VertexProgram.input.position",
			vb,
			VertexAttrib(
				0,	// offset
				vec3.sizeof*2,	// stride
				VertexAttrib.Type.Vec3
			)
		);

		efInst.setVarying(
			"VertexProgram.input.normal",
			vb,
			VertexAttrib(
				vec3.sizeof,	// offset
				vec3.sizeof*2,	// stride
				VertexAttrib.Type.Vec3
			)
		);
		
		// Initialize the vertex data to a cube primitive
		
		Vertex[] vertices;
		vertices.length = Cube.positions.length;
		
		foreach (i, ref v; vertices) {
			v.pos = Cube.positions[i];
			v.norm = Cube.normals[i];
		}
		
		vb.setData(
			cast(void[])vertices,
			BufferUsage.StaticDraw
		);
		
		delete vertices;
		
		// Finalize the mesh
		
		mesh.indices = Cube.indices;
		mesh.effect = efInst;
	};
	
	
	float lightRot = 0.0f;

	while (context.created) {
		use(context) in (GL gl) {
			lightRot += 2.0f;
			mesh.effect.setUniform("lights[1].position",
				quat.yRotation(lightRot).xform(vec3(2, 2, 0))
			);

			gl.Clear(COLOR_BUFFER_BIT | DEPTH_BUFFER_BIT);
			renderer.render(mesh);
		};
		
		context.update().show();
		Thread.yield();
	}
}
