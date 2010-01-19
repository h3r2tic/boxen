module Main;

import
	tango.core.tools.TraceExceptions,
	xf.Common,
	
	xf.gfx.api.gl3.OpenGL,
	xf.gfx.api.gl3.ext.WGL_EXT_swap_control,
	xf.gfx.api.gl3.ext.EXT_framebuffer_sRGB,
	xf.gfx.api.gl3.backend.Native,
	xf.gfx.gl3.Renderer,
	
	assimp.api,
	assimp.postprocess,
	assimp.loader,
	assimp.scene,
	assimp.mesh,
	
	xf.omg.core.LinearAlgebra,
	xf.omg.core.CoordSys,
	xf.omg.core.Misc,
	tango.io.Stdout,
	tango.time.StopWatch;
	
	

Mesh[] loadModel(
		Renderer renderer,
		GPUEffect effect,
		cstring path,
		CoordSys modelCoordSys,
		float scale = 1.0f,
		int numInstances = 1
) {
	final scene = aiImportFile(
		toStringz(path),
		(AI_PROCESS_PRESET_TARGET_REALTIME_QUALITY |
		aiPostProcessSteps.PreTransformVertices |
		aiPostProcessSteps.OptimizeMeshes |
		aiPostProcessSteps.OptimizeGraph)
		& ~aiPostProcessSteps.SplitLargeMeshes
	);
	
	final err = aiGetErrorString();
	if (err) {
		Stdout.formatln("assImp error: {}", fromStringz(err));
	}
	
	assert (scene !is null);
	assert (scene.mNumMeshes > 0);
	
	final root = scene.mRootNode;

	void iterAssetMeshes(void delegate(int, aiMesh*) dg) {
		int meshI = 0;
		
		void recurse(aiNode* node) {
			foreach (assetMeshIdx; node.mMeshes[0..node.mNumMeshes]) {
				dg(meshI++, scene.mMeshes[assetMeshIdx]);
			}
			
			foreach (ch; node.mChildren[0..node.mNumChildren]) {
				recurse(ch);
			}
		}
		
		recurse(root);
	}
	
	int numMeshes = 0;
	iterAssetMeshes((int, aiMesh*) {
		++numMeshes;
	});
	
	Mesh[] meshes = renderer.createMeshes(numMeshes);

	struct Vertex {
		vec3 pos;
		vec3 norm;
	}

	iterAssetMeshes((int meshIdx, aiMesh* assetMesh) {
		assert (assetMesh.mVertices !is null);
		assert (assetMesh.mNormals !is null);
		
		// Initialize vertex data
		
		Vertex[] vertices;
		vertices.length = assetMesh.mNumVertices;
		
		foreach (i, ref v; vertices) {
			v.pos = vec3.from(assetMesh.mVertices[i]) * scale;
			
			auto norm = assetMesh.mNormals[i];
			if (norm.x <>= 0 && norm.y <>= 0 && norm.z <>= 0) {
				v.norm = vec3.from(norm);
			} else {
				v.norm = vec3.unitY;
			}
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
				vec4(1.0f, 0.7f, 0.4f) * 10.f
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
						) = vec4(0.001, 0.001, 0.001, 1);

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
			
			uword[] indices;
			foreach (ref face; assetMesh.mFaces[0 .. assetMesh.mNumFaces]) {
				if (3 == face.mNumIndices) {
					indices ~= face.mIndices[0..3];
				}
			}
			
			mesh.numIndices = indices.length;
			// assert (indices.length > 0 && indices.length % 3 == 0);
			
			uword minIdx = uword.max;
			uword maxIdx = uword.min;
			
			foreach (i; indices) {
				if (i < minIdx) minIdx = i;
				if (i > maxIdx) maxIdx = i;
			}

			mesh.minIndex = minIdx;
			mesh.maxIndex = maxIdx;
			
			(mesh.indexBuffer = renderer.createIndexBuffer(
				BufferUsage.StaticDraw,
				indices
			)).dispose();
			
			// Finalize the mesh
			
			mesh.effectInstance = efInst;
			mesh.numInstances = numInstances;
		}
		
		auto mesh = &meshes[meshIdx];
		createObject(mesh);
		mesh.modelToWorld = modelCoordSys;
	});
	
	return meshes;
}


UniformBuffer envUB;


void main() {
	auto context = GLWindow();
	context
		.title("Effect Test")
		.showCursor(true)
		.fullscreen(false)
		.width(800)
		.height(600)
	.create();
	
	Assimp.load(Assimp.LibType.Release);
	

	Renderer		renderer;
	GPUEffect		effect;
	
	Mesh[]				meshes;
	MeshRenderData*[]	renderList;
	
	use(context) in (GL gl) {
		renderer = new Renderer(gl);
		
		bool vsync = false;
		
		gl.SwapIntervalEXT(vsync ? 1 : 0);
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
		
		
		meshes ~= loadModel(
			renderer,
			effect,
			`MTree/MonsterTree.3ds`,
			CoordSys(vec3fi[1, -1, -1.5]),
			0.01f
		);
		
		meshes ~= loadModel(
			renderer,
			effect,
			`cia/cia_mesh_low.obj`,
			CoordSys(vec3fi[-1, -1, -1.5]),
			0.01f
		);
		
		meshes ~= loadModel(
			renderer,
			effect,
			`Eland 90/Eland 90.obj`,
			CoordSys(
				vec3fi[-3.5 * 5, 0.2, -14],
				quat.yRotation(45) * quat.xRotation(30)
			),
			0.04f,
			11
		);

		if (0 == meshes.length) {
			throw new Exception("No meshes in the scene :(");
		} else {
			uword numTris = 0;
			uword numMeshes = 0;
			
			foreach (m; meshes) {
				numTris += m.getNumInstances * m.getNumIndices / 3;
				numMeshes += m.getNumInstances;
			}
			
			Stdout.formatln(
				"{} Meshes with a total of {} triangles in the scene.",
				numMeshes,
				numTris
			);
		}

		foreach (ref mesh; meshes) {
			// this one is an effect-scoped parameter. these are faster.
			mesh.effect.setUniform("worldToScreen",
				mat4.perspective(
					90.0f,		// fov
					cast(float)context.width / context.height,	// aspect
					0.5f,		// near
					10000.0f	// far
				)
			);
		}
		
		foreach (ref m; meshes) {
			renderList ~= m.renderData;
		}
	};
	
	
	float lightRot = 0.0f;
	float lightPulse = 0.0f;
	
	StopWatch timer;
	timer.start();

	while (context.created) {
		use(context) in (GL gl) {
			final timeDelta = timer.stop();
			timer.start();
			
			lightRot += timeDelta * 90.f;
			lightPulse += timeDelta * 25.f;

			// update the shared environment params
			{
				final envUBData = &effect.uniformBuffers[0];
				
				size_t lightScaleOffset = envUBData.params.dataSlice[
					envUBData.getUniformIndex("envData.lightScale")
				].offset;
				
				float lightScale = abs(cos(deg2rad * lightPulse)) * 2.0f;
				envUB.setSubData(lightScaleOffset, cast(void[])(&lightScale)[0..1]);
			}

			// update light positions
			foreach (mesh; renderList) {
				mesh.effectInstance.setUniform("lights[1].position",
					vec3(0, 0, -4) + quat.yRotation(lightRot).xform(vec3(5, 2, 0))
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
