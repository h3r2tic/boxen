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
	xf.omg.core.CoordSys,
	xf.omg.core.Misc,
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
	

	Renderer		renderer;
	UniformBuffer	envUB;
	GPUEffect		effect;
	
	Mesh[]				meshes;
	MeshRenderData*[]	renderList;

	use(context) in (GL gl) {
		renderer = new Renderer(gl);
		
		gl.SwapIntervalEXT(0);	// no vsync
		gl.Enable(FRAMEBUFFER_SRGB_EXT);
		gl.Enable(DEPTH_TEST);
		gl.Enable(CULL_FACE);
		
		// Create the effect from a cgfx file
		
		effect = renderer.createEffect(
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
		


		struct Vertex {
			vec3 pos;
			vec3 norm;
		}

		// Initialize vertex data to a cube primitive
		
		Vertex[] vertices;
		vertices.length = Cube.positions.length;
		
		foreach (i, ref v; vertices) {
			v.pos = Cube.positions[i];
			v.norm = Cube.normals[i];
		}

		auto vb = renderer.createVertexBuffer(
			BufferUsage.StaticDraw,
			cast(void[])vertices
		);
		delete vertices;



		int objId = 0;
		void createObject(Mesh* mesh) {
			// Instantiate the effect and initialize its uniforms

			final efInst = renderer.instantiateEffect(effect);
			
			efInst.setUniform("lights[0].color",
				vec4(0.0f, 0.0f, 0.01f)
			);
			efInst.setUniform("lights[1].color",
				vec4(1.0f, 0.7f, 0.4f) * 100.f
			);
			
			// this one is an effect-scoped parameter. these are faster.
			effect.setUniform("worldToScreen",
				mat4.perspective(
					90.0f,		// fov
					cast(float)context.width / context.height,	// aspect
					0.5f,		// near
					10000.0f	// far
				)
			);
			
			// Create a vertex buffer and bind it to the shader

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
			
			// Create a uniform buffer for the environment and bind it to the effect
			
			if (!envUB.valid) {
				final envUBData = &effect.uniformBuffers[0];
				final envUBSize = envUBData.totalSize;
				
				log.info("Environment uniform buffer size: {} bytes.", envUBSize);
				
				envUB = renderer.createUniformBuffer(
					BufferUsage.StaticDraw,
					envUBSize,
					null
				);
				
				// Initialize the uniform buffer
				
				envUB.mapRange(
					0,
					envUBSize,
					BufferAccess.Write | BufferAccess.InvalidateBuffer,
					(void[] data) {
						*cast(vec4*)(
							data.ptr + envUBData.params.dataSlice[
								envUBData.getUniformIndex("envData.ambientColor")
							].offset
						) = vec4(0.01, 0, 0, 1);

						*cast(float*)(
							data.ptr + envUBData.params.dataSlice[
								envUBData.getUniformIndex("envData.lightScale")
							].offset
						) = 2.0f;
					}
				);

				effect.bindUniformBuffer(0, *envUB.asBuffer);
			}
			
			// Create and set the index buffer
			
			mesh.numIndices = Cube.indices.length;
			mesh.minIndex = min(Cube.indices.length);
			mesh.maxIndex = max(Cube.indices.length);
			
			(mesh.indexBuffer = renderer.createIndexBuffer(
				BufferUsage.StaticDraw,
				Cube.indices
			)).dispose();
			
			// Finalize the mesh
			
			mesh.effectInstance = efInst;
			mesh.numInstances = 31;
		}
		
		const int numMeshes = 1000;
		
		meshes = renderer.createMeshes(numMeshes);
		renderList.length = numMeshes;
		
		foreach (int i, ref mesh; meshes) {
			createObject(&mesh);
			mesh.modelToWorld = CoordSys(vec3fi[-3 * 15, -5, -i*3]);
			renderList[i] = mesh.renderData;
		}
	};
	
	
	float lightRot = 0.0f;
	float lightPulse = 0.0f;

	while (context.created) {
		use(context) in (GL gl) {
			lightRot += 2.0f;
			lightPulse += 0.9f;

			// update the shared environment params
			{
				final envUBData = &effect.uniformBuffers[0];
				final envUBSize = envUBData.totalSize;

				envUB.mapRange(
					0,
					envUBSize,
					BufferAccess.Write,
					(void[] data) {
						*cast(float*)(
							data.ptr + envUBData.params.dataSlice[
								envUBData.getUniformIndex("envData.lightScale")
							].offset
						) = abs(cos(deg2rad * lightPulse)) * 2.0f;
					}
				);
			}

			// update light positions
			foreach (mesh; renderList) {
				mesh.effectInstance.setUniform("lights[1].position",
					vec3(0, 0, -30) + quat.yRotation(lightRot).xform(vec3(20, 2, 0))
				);
			}

			gl.Clear(COLOR_BUFFER_BIT | DEPTH_BUFFER_BIT);
			
			foreach (i, ref m; meshes) {
				if (m.worldMatricesDirty) {
					auto rd = m.renderData;
					auto cs = m.modelToWorld;
					rd.modelToWorld = cs.toMatrix34;
					cs.invert;
					rd.worldToModel = cs.toMatrix34;
				}
			}
			
			renderer.render(renderList);
		};
		
		context.update().show();
		Thread.yield();
	}
}
