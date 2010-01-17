module Main;

import tango.core.tools.TraceExceptions;

import
	xf.Common,
	
	xf.gfx.api.gl3.OpenGL,
	xf.gfx.api.gl3.ext.WGL_EXT_swap_control,
	xf.gfx.api.gl3.ext.EXT_framebuffer_sRGB,
	xf.gfx.api.gl3.backend.Native,
	xf.gfx.gl3.Renderer,
	xf.gfx.gl3.Cg,
	xf.omg.core.LinearAlgebra,
	
	xf.gfx.api.gl3.Cg,
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
	

	Renderer renderer;
	GPUEffectInstance* efInst;

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
		}
		
		// Instantiate the effect and initialize its uniforms

		efInst = renderer.instantiateEffect(effect);
		
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
		
		efInst.setUniform("worldToScreen",
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
	};
	
	
	float lightRot = 0.0f;

	while (context.created) {
		use(context) in (GL gl) {
			lightRot += 2.0f;
			efInst.setUniform("lights[1].position",
				quat.yRotation(lightRot).xform(vec3(2, 2, 0))
			);

			draw(gl, efInst);
		};
		
		context.update().show();
		Thread.yield();
	}
}


void draw(GL gl, GPUEffectInstance*[] objects ...) {
	gl.Clear(COLOR_BUFFER_BIT | DEPTH_BUFFER_BIT);
	
	render(gl, objects);
}


void render(GL gl, GPUEffectInstance*[] objects ...) {
	if (0 == objects.length) {
		return;
	}
	
	GPUEffect effect = objects[0]._proto;
	
	assert ({
		foreach (o; objects[1..$]) {
			if (o._proto !is effect) {
				return false;
			}
		}
		return true;
	}(), "All objects must have the same GPUEffect");

	effect.bind();
	
	void setObjUniforms(GPUEffectInstance* obj) {
		final up = &effect.uniformParams;
		final numUniforms = up.length;
		void* base = obj.getUniformsDataPtr();
		
		for (int ui = 0; ui < numUniforms; ++ui) {
			switch (up.baseType[ui]) {
				case ParamBaseType.Float: {
					cgSetParameterValuefc(
						cast(CGparameter)up.param[ui],
						up.numFields[ui],
						cast(float*)(base + up.dataSlice[ui].offset)
					);
				} break;

				case ParamBaseType.Int: {
					cgSetParameterValueic(
						cast(CGparameter)up.param[ui],
						up.numFields[ui],
						cast(int*)(base + up.dataSlice[ui].offset)
					);
				} break;
				
				default: assert (false);
			}
		}
	}
	
	void setObjVaryings(GPUEffectInstance* obj) {
		final vp = &effect.varyingParams;
		final numVaryings = vp.length;
		
		auto flags = obj.getVaryingParamDirtyFlagsPtr();
		auto varyingData = obj.getVaryingParamDataPtr();
		
		alias typeof(*flags) flagFieldType;
		const buffersPerFlag = flagFieldType.sizeof * 8;
		
		for (
			int varyingBase = 0;
			
			varyingBase < numVaryings;
			
			varyingBase += buffersPerFlag,
			++flags,
			varyingData += buffersPerFlag
		) {
			if (*flags != 0) {
				// one of the buffers in varyingBase .. varyingBase + buffersPerFlag
				// needs to be updated
				
				static if (
					ParameterTupleOf!(intrinsic.bsf)[0].sizeof
					==
					flagFieldType.sizeof
				) {
					auto flag = *flags;

				updateSingle:
					final idx = intrinsic.bsf(flag);
					final data = varyingData + idx;
					
					if (data.currentBuffer.valid) {
						data.currentBuffer.dispose();
					}
					
					final buf = &data.currentBuffer;
					final attr = &data.currentAttrib;

					*buf = data.newBuffer;
					*attr = data.newAttrib;
					
					GLenum glType = void;
					switch (attr.scalarType) {
						case attr.ScalarType.Float: {
							glType = FLOAT;
						} break;
						
						default: {
							error("Unhandled scalar type: {}", attr.scalarType);
						}
					}
					
					final param = cast(CGparameter)
						obj._proto.varyingParams.param[varyingBase+idx];

					buf.bind();
					cgGLEnableClientState(param);
					cgGLSetParameterPointer(
						param,
						attr.numFields(),
						glType,
						attr.stride,
						cast(void*)attr.offset
					);
					
					defaultHandleCgError();
					
					// should be a SUB instruction followed by JZ
					flag -= cast(flagFieldType)1 << idx;
					if (flag != 0) {
						goto updateSingle;
					}
					
					// write back the flag
					*flags = flag;
				} else {
					static assert (false, "TODO");
				}
			}
		}
	}
	
	foreach (obj; objects) {
		setObjUniforms(obj);
		obj._vertexArray.bind();
		setObjVaryings(obj);
		
		// HACK
		gl.DrawElements(TRIANGLES, 36, UNSIGNED_INT, Cube.indices.ptr);
	}
}
