module Main;

version (StackTracing) import tango.core.tools.TraceExceptions;

import
	xf.Common,
	xf.utils.GfxApp,
	xf.utils.SimpleCamera,
	xf.test.gfx.Common,
	
	xf.img.Image,
	xf.img.FreeImageLoader,
	
	xf.omg.core.LinearAlgebra,
	xf.omg.core.CoordSys,
	xf.omg.core.Misc,
	
	xf.utils.Memory,
	
	tango.io.Stdout,
	tango.time.StopWatch;
	
import Float = tango.text.convert.Float;
import Path = tango.io.Path;
import tango.stdc.stdlib : exit;
	
import xf.loader.scene.model.all
	: LoaderNode = Node, LoaderMesh = Mesh, LoaderScene = Scene;


// temp
	import xf.terrain.HeightmapChunkLoader;
	import xf.terrain.ChunkedTerrain;
	import xf.terrain.ChunkData;
	import xf.terrain.ChunkLoader;
	import xf.terrain.Chunk;
// ----


UniformBuffer envUB;


void main(cstring[] args) {
	(new TestApp(args)).run;
}


class MyChunkHandler : IChunkHandler {
	void alloc(int cnt) {
		.alloc(data, cnt);
	}
	
	bool loaded(int idx) {
		return data[idx].loaded;
	}
	
	void load(int idx, Chunk*, ChunkData data) {
		with (this.data[idx]) {
			.alloc(positions, data.numPositions);
			data.getPositions(positions);
			.alloc(indices, data.numIndices);
			data.getIndices(indices);
			loaded = true;

			efInst = renderer.instantiateEffect(effect);
			auto vb = renderer.createVertexBuffer(
				BufferUsage.StaticDraw,
				cast(void[])positions
			);
			efInst.setVarying(
				"VertexProgram.input.position",
				vb,
				VertexAttrib(
					0,
					vec3.sizeof,
					VertexAttrib.Type.Vec3
				)
			);
			mesh = renderer.createMeshes(1);
			auto m = &mesh[0];

			m.numIndices = indices.length;
			// assert (indices.length > 0 && indices.length % 3 == 0);
			
			uword minIdx = uword.max;
			uword maxIdx = uword.min;
			
			foreach (i; indices) {
				if (i < minIdx) minIdx = i;
				if (i > maxIdx) maxIdx = i;
			}

			m.minIndex = minIdx;
			m.maxIndex = maxIdx;
			
			(m.indexBuffer = renderer.createIndexBuffer(
				BufferUsage.StaticDraw,
				indices
			)).dispose();
			
			// Finalize the mesh
			
			m.effectInstance = efInst;
		}
	}
	
	void unload(int) {
		// TODO
	}
	
	void free() {
		// TODO
	}


	struct UserData {
		EffectInstance	efInst;
		Mesh[]			mesh;
		
		vec3[]		positions;
		ushort[]	indices;
		bool		loaded;
	}
	
	UserData[]	data;
	Effect		effect;
	IRenderer	renderer;
}


class TestApp : GfxApp {
	Effect				effect;
	Mesh[]				meshes;
	float				lightRot = 0.0f;
	float				lightPulse = 0.0f;
	StopWatch			timer;
	SimpleCamera		camera;
	
	float				_sceneScale = 1.0f;
	cstring				_sceneToLoad;
	
	const int			chunkSize = 16;
	Effect				terrainEffect;
	ChunkedTerrain		terrain;
	MyChunkHandler		chunkData;
	Texture				albedo, lightmap, detail;
	

	this(cstring[] args) {
		version (Demo) {
			if (args.length < 2) {
				Stdout.formatln(
					"Usage: {0} [sceneFile] {[scaleFactor]}\n"
					"\n"
					"Example: {0} foo.hsf 0.1",
					args[0]
				);
				exit(1);
			} else {
				if (args.length >= 3) {
					_sceneScale = Float.parse(args[2]);
				}
				
				_sceneToLoad = Path.normalize(args[1]);
			}
		}
	}
	
	
	override void configureWindow(Window wnd) {
		super.configureWindow(wnd);
		wnd.title = "Dumb model viewer";
	}
	
	
	override void initialize() {
		auto ldr = new HeightmapChunkLoader;
		ldr.load("height.png", chunkSize);
		terrain = new ChunkedTerrain(ldr);
		chunkData = new MyChunkHandler;
		terrain.addChunkHandler(chunkData);
		terrain.scale = vec3(10.f, 3.f, 10.f);

		camera = new SimpleCamera(vec3.zero, 0.0f, 0.0f, inputHub.mainChannel);
		window.interceptCursor = true;
		window.showCursor = false;
		
		// Create the effect from a cgfx file
		
		effect = renderer.createEffect(
			"sample",
			EffectSource.filePath("sample.cgfx")
		);
		
		// Specialize the shader template

		effect.useGeometryProgram = false;
		effect.setArraySize("lights", 3);
		effect.setUniformType("lights[0]", "PointLight");
		effect.setUniformType("lights[1]", "PointLight");
		effect.setUniformType("lights[2]", "PointLight");
		effect.compile();
		
		// ---- Some debug info printing ----
		{
			with (*effect.uniformParams()) {
				Stdout.formatln("Object uniforms:");
				for (int i = 0; i < params.length; ++i) {
					Stdout.formatln("\t{}", params.name[i]);
				}
			}

			Stdout.formatln("Object varyings:");
			for (int i = 0; i < effect.varyingParams.length; ++i) {
				Stdout.formatln("\t{}", effect.varyingParams.name[i]);
			}
		}


		scope imgLoader = new FreeImageLoader;

		version (Demo) {
			const cstring mediaDir = `media/`;
		} else {
			const cstring mediaDir = `../../../media/`;
		}

		/+final img2 = imgLoader.load(mediaDir~"img/Walk_Of_Fame/Mans_Outside_2k.hdr");
		assert (img2.valid);
		TextureRequest req;
		req.internalFormat = TextureInternalFormat.RGBA_FLOAT16;
		final tex2 = renderer.createTexture(img2, req);
		assert (tex2.valid);+/
		
		Texture loadTex(cstring path) {
			return renderer.createTexture(
				imgLoader.load(path)
			);
		}

		final testgrid = loadTex(mediaDir~"img/testgrid.png");
		assert (testgrid.valid);

		final whiteTexture = loadTex(mediaDir~"img/white.bmp");
		assert (whiteTexture.valid);
		
		albedo = loadTex("albedo.png");
		lightmap = loadTex("light.png");
		
		auto detailImg = imgLoader.load("detail.jpg");
		detailImg.colorSpace = Image.ColorSpace.Linear;
		TextureRequest req;
		req.internalFormat = TextureInternalFormat.RGBA8;
		detail = renderer.createTexture(detailImg, req);
		
		terrainEffect = renderer.createEffect(
			"terrain",
			EffectSource.filePath("terrain.cgfx")
		);
		
		// Specialize the shader template

		terrainEffect.useGeometryProgram = false;
		terrainEffect.compile();
		chunkData.effect = terrainEffect;
		chunkData.renderer = renderer;

		
		// HACK: this needs to be done somewhere in a texture manager
		Texture[cstring] loadedTextures;
		
		auto tm = TextureMatcher(
			(cstring matName) {
				switch (matName) {
					case "diffuse": return whiteTexture;
					case "specular": return whiteTexture;
					default: return testgrid;
				}					
			},
			(cstring path) {
				if (auto meh = path in loadedTextures) {
					return *meh;
				}
				
				if (Path.exists(path)) {
					final img = imgLoader.load(path);
					if (img.valid) {
						auto meh = renderer.createTexture(img);
						loadedTextures[path.dup] = meh;
						return meh;
					}
				}
				return Texture.init;
			},
			(bool delegate(cstring) dg) {
				if (dg("tex")) return;
				if (dg(".")) return;
			}
		);
		
		version (Demo) {
			meshes ~= loadHsfModel(
				renderer,
				effect,
				_sceneToLoad,
				envUB,
				CoordSys.identity,
				tm,
				_sceneScale
			);
		} else {
			/+meshes ~= loadHsfModel(
				renderer,
				effect,
				`C:\Users\h3r3tic\Documents\3dsMax\export\dozer.hsf`,
				envUB,
				CoordSys(vec3fi[0, -1, -0.5]),
				tm,
				0.02f
			);+/


			meshes ~= loadHsfModel(
				renderer,
				effect,
				`C:\Users\h3r3tic\Documents\3dsMax\export\foo.hsf`,
				envUB,
				CoordSys(vec3fi[0, -1, -0.5]),
				tm,
				0.01f
			);
			

			meshes ~= loadHsfModel(
				renderer,
				effect,
				`C:\Users\h3r3tic\Documents\3dsMax\export\masha.hsf`,
				envUB,
				CoordSys(vec3fi[1.5, -1, -0.5]),
				tm,
				0.01f
			);
			
			
			meshes ~= loadHsfModel(
				renderer,
				effect,
				`C:\Users\h3r3tic\Documents\3dsMax\export\tank.hsf`,
				envUB,
				CoordSys(vec3fi[1.5, 0, -2.5]),
				tm,
				0.01f
			);


			meshes ~= loadHsfModel(
				renderer,
				effect,
				`C:\Users\h3r3tic\Documents\3dsMax\export\soldier.hsf`,
				envUB,
				CoordSys(vec3fi[-1.5, -1, -0.5]),
				tm,
				0.5f
			);


			meshes ~= loadModel(
				renderer,
				effect,
				mediaDir~`mesh/MTree/MonsterTree.3ds`,
				envUB,
				CoordSys(vec3fi[-1.5, -1, -2.5]),
				tm,
				0.01f
			);
		}
		
		
		if (0 == meshes.length) {
			//throw new Exception("No meshes in the scene :(");
		} else {
			uword numTris = 0;
			uword numMeshes = 0;
			
			foreach (m; meshes) {
				numTris += /+m.numInstances * +/m.numIndices / 3;
				numMeshes += /+m.numInstances+/1;
			}
			
			Stdout.formatln(
				"{} Meshes with a total of {} triangles in the scene.",
				numMeshes,
				numTris
			);
		}
		
		mat4 viewToClip = mat4.perspective(
			65.0f,		// fov
			cast(float)window.width / window.height,	// aspect
			0.1f,		// near
			100.0f		// far
		);


		effect.setUniform("viewToClip", viewToClip);
		terrainEffect.setUniform("viewToClip", viewToClip);
		
		renderer.minimizeStateChanges();
		timer.start();
	}
	
	
	override void render() {
		final timeDelta = timer.stop();
		timer.start();

		final renderList = renderer.createRenderList();
		assert (renderList !is null);
		scope (success) renderer.disposeRenderList(renderList);



		const float maxError = 0.2f;
		terrain.optimize(camera.position, maxError);

		int numDrawn = 0;
		void drawChunk(Chunk* ch, vec3 pos, float halfSize) {
			if (!ch.split) {
				auto userData = chunkData.data[terrain.getIndex(ch)];
				if (userData.loaded && userData.positions && userData.indices) {
					++numDrawn;
					
					final bin = renderList.getBin(chunkData.effect);
					userData.efInst.setUniform("terrainScale", terrain.scale);
					
					userData.efInst.setUniform(
						"FragmentProgram.albedoTex",
						albedo
					);

					userData.efInst.setUniform(
						"FragmentProgram.detailTex",
						detail
					);

					userData.efInst.setUniform(
						"detailRepeat",
						vec3.one * 10.f
					);

					userData.efInst.setUniform(
						"FragmentProgram.lightTex",
						lightmap
					);

					userData.mesh[0].toRenderableData(bin.add(userData.efInst));
				}
			} else {
				vec2[4] chpos;
				ch.getChildPositions(vec2(pos.x, pos.z), halfSize, &chpos);
				
				foreach (i, c; ch.children) {
					drawChunk(c, vec3(chpos[i].x, 0, chpos[i].y), halfSize * .5f);
				}
			}
		}
		
		drawChunk(terrain.root, vec3(.5f, 0.f, .5f), .5f);


		effect.setUniform("worldToView",
			camera.getMatrix
		);
		terrainEffect.setUniform("worldToView",
			camera.getMatrix
		);
		
		lightRot += timeDelta * 90.f;
		lightPulse += timeDelta * 10.f;

		// update the shared environment params
		{
			final envUBData = &effect.uniformBuffers[0];
			
			/+size_t lightScaleOffset = envUBData.params.dataSlice[
				envUBData.getUniformIndex("envData.lightScale")
			].offset;+/

			final eyePosSlice = envUBData.params.dataSlice[
				envUBData.getUniformIndex("envData.eyePos")
			];
			
			
			/+float lightScale = (cos(deg2rad * lightPulse) + 1.f) * 15.0f;
			envUB.setSubData(lightScaleOffset, cast(void[])(&lightScale)[0..1]);+/
			
			
			if (eyePosSlice.length > 0) {
				vec3 eyePos = camera.position;
				if (envUB.valid) {
					envUB.setSubData(eyePosSlice.offset, cast(void[])(&eyePos)[0..1]);
				}
			}
		}

		// update light positions
		foreach (mesh; meshes) {
			mesh.effectInstance.setUniform("lights[1].position",
				vec3(0, 0, -4) + quat.yRotation(lightRot).xform(vec3(5, 2, 0))
			);
		}

		foreach (i, ref m; meshes) {
			final bin = renderList.getBin(m.effectInstance.getEffect);
			m.toRenderableData(bin.add(m.effectInstance));
		}
		
		renderList.sort();
		renderer.resetStats();
		renderer.framebuffer.settings.clearColorValue[0] = vec4.one * 0.1f;
		renderer.clearBuffers();
		renderer.render(renderList);
		//Stdout.formatln("Tex changes: {}", renderer.getStats.numTextureChanges);
	}
}
