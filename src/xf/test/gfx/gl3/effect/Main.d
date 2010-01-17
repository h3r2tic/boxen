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
	

	Renderer renderer;
	GPUEffectInstance* efInst;

	use(context) in (GL gl) {
		renderer = new Renderer(gl);
		
		gl.SwapIntervalEXT(1);
		gl.Enable(FRAMEBUFFER_SRGB_EXT);
		
		auto effect = renderer.createEffect(
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
		
		efInst = renderer.instantiateEffect(effect);
		efInst.setUniform("lights[0].color", vec4.one);
		
		auto vb = renderer.createVertexBuffer();
		
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
	};
	

	while (context.created) {
		use(context) in (GL gl) {
			draw(gl, efInst);
		};
		
		context.update().show();
		Thread.yield();
	}
}


void draw(GL gl, GPUEffectInstance*[] objects ...) {
	gl.Clear(COLOR_BUFFER_BIT | DEPTH_BUFFER_BIT);
	
	render(objects);
}


void render(GPUEffectInstance*[] objects ...) {
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
		// TODO: render obj
	}
}
