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
	
	tango.io.Stdout,
	tango.time.StopWatch;
	
import xf.loader.scene.model.all
	: LoaderNode = Node, LoaderMesh = Mesh, LoaderScene = Scene;



UniformBuffer envUB;


void main(cstring[] args) {
	(new TestApp(args)).run;
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
		camera = new SimpleCamera(vec3.zero, 0.0f, 0.0f, inputHub.mainChannel);
		window.interceptCursor = true;
		window.showCursor = false;
		
		// Create the effect from a cgfx file

		EffectCompilationOptions opts;
		opts.useGeometryProgram = false;
		effect = renderer.createEffect(
			"sample",
			EffectSource.filePath("sample.cgfx"),
			opts
		);
		
		// Specialize the shader template

		effect.setArraySize("lights", 3);
		effect.setUniformType("lights[0]", "PointLight");
		effect.setUniformType("lights[1]", "PointLight");
		effect.setUniformType("lights[2]", "PointLight");
		effect.compile();
		EffectHelper.allocateDefaultUniformStorage(effect);
		
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

		Texture loadTex(cstring path) {
			return renderer.createTexture(
				imgLoader.load(path)
			);
		}

		final testgrid = loadTex(mediaDir~"img/testgrid.png");
		assert (testgrid.valid);

		final whiteTexture = loadTex(mediaDir~"img/white.bmp");
		assert (whiteTexture.valid);
		
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
				`C:\coding\projects\boxen\src\xf\test\media\mesh\tank.hsf`,
				envUB,
				CoordSys(vec3fi[0, -1, -0.5]),
				tm,
				0.01f,
				10
			);


			/+meshes ~= loadHsfModel(
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
			);+/
		}
		
		
		if (0 == meshes.length) {
			//throw new Exception("No meshes in the scene :(");
		} else {
			uword numTris = 0;
			uword numMeshes = 0;
			
			foreach (m; meshes) {
				numTris += /+m.numInstances * +/m.indexData.numIndices / 3;
				numMeshes += /+m.numInstances+/1;
			}
			
			Stdout.formatln(
				"{} Meshes with a total of {} triangles in the scene.",
				numMeshes,
				numTris
			);
		}
		
		mat4 viewToClip = mat4.perspective(
			55.0f,		// fov
			cast(float)window.width / window.height,	// aspect
			0.1f,		// near
			100.0f		// far
		);


		effect.setUniform("viewToClip", viewToClip);
		
		renderer.minimizeStateChanges();
		timer.start();
	}
	
	
	override void render() {
		final timeDelta = timer.stop();
		timer.start();

		final renderList = renderer.createRenderList();
		assert (renderList !is null);
		scope (success) renderer.disposeRenderList(renderList);


		effect.setUniform("worldToView",
			camera.getMatrix
		);
		
		lightRot += timeDelta * 90.f;
		lightPulse += timeDelta * 10.f;

		// update the shared environment params
		if (effect.uniformBuffers.length > 0) {
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
