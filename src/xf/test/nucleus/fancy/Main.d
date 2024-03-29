module Main;

private {
	version (StackTracing) {
		import tango.core.tools.TraceExceptions;
	}
	
	import xf.Common;
	import xf.utils.GfxApp;
	import xf.utils.SimpleCamera;
	
	import xf.nucleus.asset.compiler.SceneCompiler;
	import xf.nucleus.asset.CompiledSceneAsset;
	import xf.nucleus.post.PostProcessor;
	import xf.nucleus.structure.PointCloud;

	import xf.nucleus.Nucleus;
	import xf.nucleus.Scene;
	import xf.nucleus.light.Point;
	import xf.nucleus.light.Spot;

	import xf.vsd.VSD;

	import xf.loader.scene.model.Mesh : LoaderMesh = Mesh;
	import xf.loader.scene.hsf.Hsf;
	import xf.loader.Common;

	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.CoordSys;
	import xf.omg.util.ViewSettings;

	import xf.mem.ScratchAllocator;
	import xf.mem.MainHeap;

	import tango.io.Stdout;
	
	import tango.math.random.Kiss;
	import tango.stdc.math : fmodf;
	import xf.omg.color.HSV;

	import tango.core.Memory;
}


//version = LightTest;
version = Sponza;
//version = FixedTest


class TestApp : GfxApp {
	Renderer		nr;
	Renderer		nr2;
	VSDRoot			vsd;
	VSDRoot			tvsd;
	SimpleCamera	camera;
	
	Texture			fbTex;
	Framebuffer		mainFb;
	Framebuffer		texFb;

	PostProcessor	post;


	Light[]			lights;
	vec3[]			lightOffsets;
	float[]			lightDists;
	float[]			lightSpeeds;
	float[]			lightAngles;
	vec4[]			lightIllums;

	PointCloud		pointCloud;
	RenderableId	pointCloudRid;


	/+override void configureWindow(Window wnd) {
		wnd.width(1680).height(1050).fullscreen(true);
	}+/
	

	override void initialize() {
		version (FixedTest) {
			Kiss.instance.seed(12345);
		}
		
		setMediaDir(`../../media`);
		initializeNucleus(this.renderer, "../../media/kdef", ".");
		
		nr = createRenderer("LightPrePass");
		nr2 = createRenderer("Forward");
		
		post = new PostProcessor(rendererBackend, kdefRegistry);
		post.setKernel("PostGlareAcuityNoise");

		// TODO: configure the VSD spatial subdivision
		vsd = VSDRoot();
		tvsd = VSDRoot();

		version (Sponza) {
			camera = new SimpleCamera(vec3(-7.54, 2.9, 5.03), -7.00, 12.80, inputHub.mainChannel);
		} else {
			camera = new SimpleCamera(vec3(0, 3, 4), 0, 0, inputHub.mainChannel);
		}
		window.interceptCursor = true;
		window.showCursor = false;

		// ----

		version (FixedTest) {
			const numLights = 50;
			alias PointLight LightType;
		} else {
			const numLights = 100;
			alias PointLight LightType;
		}
		
		for (int i = 0; i < numLights; ++i) {
			createLight((lights ~= new LightType)[$-1]);
			version (Sponza) {
				lightOffsets ~= vec3(0, 2 + Kiss.instance.fraction() * 2.0, 0);
				lightAngles ~= Kiss.instance.fraction() * 360.0f;
				lightDists ~= Kiss.instance.fraction() - 0.5f;
				lightSpeeds ~= 0.7f * (0.3f * Kiss.instance.fraction() + 0.7f) * (Kiss.instance.fraction() > 0.5f ? 1 : -1);
			} else {
				lightOffsets ~= vec3(0, 1.0 + Kiss.instance.fraction() * 3.0, 0);
				lightAngles ~= Kiss.instance.fraction() * 360.0f;
				lightDists ~= Kiss.instance.fraction() * 0.3f - 0.15f;
				lightSpeeds ~= 0.2f * (0.3f * Kiss.instance.fraction() + 0.7f) * (Kiss.instance.fraction() > 0.5f ? 1 : -1);

				/+lightOffsets ~= vec3(0, -2 + Kiss.instance.fraction() * 4, 0);
				lightAngles ~= Kiss.instance.fraction() * 360.0f;
				lightDists ~= Kiss.instance.fraction() * 0.3f - 0.15f;
				lightSpeeds ~= 0.2f * (0.3f * Kiss.instance.fraction() + 0.7f) * (Kiss.instance.fraction() > 0.5f ? 1 : -1);+/
			}

			float h = cast(float)i / numLights;//Kiss.instance.fraction();
			//float s = 0.92f;
			float s = 0.6f;
			float v = 1.0f;

			vec4 rgba = vec4.zero;
			hsv2rgb(h, s, v, &rgba.r, &rgba.g, &rgba.b);

			version (FixedTest) {
				lightIllums ~= rgba * (1000.f / numLights);
			} else {
				lightIllums ~= rgba;// * (1000.f / numLights);
			}
		}

		// ----

		version (Sponza) {
			cstring model = `mesh/csponza.hsf`;
			float scale = 1f;

			SceneAssetCompilationOptions opts;
			opts.scale = scale;

			final compiledScene = compileHSFSceneAsset(
				model,
				DgScratchAllocator(&mainHeap.allocRaw),
				opts
			);

			assert (compiledScene !is null);

			loadScene(compiledScene, &vsd, CoordSys(vec3fi[0, -3, 0]));
		} else version (Sibenik) {
			cstring model = `mesh/sibenik.hsf`;
			float scale = 1f;

			SceneAssetCompilationOptions opts;
			opts.scale = scale;

			final compiledScene = compileHSFSceneAsset(
				model,
				DgScratchAllocator(&mainHeap.allocRaw),
				opts
			);

			assert (compiledScene !is null);

			loadScene(compiledScene, &vsd, CoordSys(vec3fi[0, -3, 0]));
		} else version (LightTest) {
			cstring model = `mesh/lightTest.hsf`;
			float scale = 0.01f;

			SceneAssetCompilationOptions opts;
			opts.scale = scale;

			final compiledScene = compileHSFSceneAsset(
				model,
				DgScratchAllocator(&mainHeap.allocRaw),
				opts
			);

			assert (compiledScene !is null);

			loadScene(compiledScene, &vsd, CoordSys(vec3fi[0, 1, 0]));
		} else {
			cstring model = `mesh/soldier.hsf`;
			float scale = 1.0f;
			/+cstring model = `mesh/masha.hsf`;
			//cstring model = `mesh/foo.hsf`;
			float scale = 0.02f;+/

			SceneAssetCompilationOptions opts;
			opts.scale = scale;

			final compiledScene = compileHSFSceneAsset(
				model,
				DgScratchAllocator(&mainHeap.allocRaw),
				opts
			);

			assert (compiledScene !is null);

			loadScene(compiledScene, &vsd, CoordSys(vec3fi[1, -2, 0]));
			loadScene(compiledScene, &vsd, CoordSys(vec3fi[-1, -2, 0]));

			/+loadScene(
				model, scale, CoordSys(vec3fi[-2, 0, 0]),
				"TestSurface1", "TestMaterialImpl"
			);
			
			loadScene(
				model, scale, CoordSys(vec3fi[0, 0, 2], quat.yRotation(90)),
				"TestSurface2", "TestMaterialImpl"
			);

			loadScene(
				model, scale, CoordSys(vec3fi[2, 0, 0], quat.yRotation(180)),
				"TestSurface3", "TestMaterialImpl"
			);

			loadScene(
				model, scale, CoordSys(vec3fi[0, 0, -2], quat.yRotation(-90)),
				"TestSurface4", "TestMaterialImpl"
			);+/

			/+loadScene(
				model, scale, CoordSys(vec3fi[0, -2, 0]),
				"TestSurface3", "TestMaterialImpl"
			);+/
		}

		/+kdefRegistry.dumpInfo();
		for (uword rid = 0; rid < .renderables.length; ++rid) {
			Stdout.formatln("rid{}: stct:{} matl:{} surf:{}",
				rid,
				renderables.structureKernel[rid],
				materialNames[renderables.material[rid]],
				surfaceNames[renderables.surface[rid]]
			);
		}+/

		pointCloud = new PointCloud(100_000, vec3.one * 15, rendererBackend);
		pointCloudRid = loadSceneObject(
			pointCloud,
			"ParticleSurface",
			"TestParticleMaterial",
			&tvsd,
			CoordSys.identity
		);
		
		{
			mainFb = rendererBackend.framebuffer;
			
			final cfg = FramebufferConfig();
			vec2i size = cfg.size = vec2i(window.width, window.height);
			cfg.location = FramebufferLocation.Offscreen;

			{
				TextureRequest treq;
				treq.internalFormat = TextureInternalFormat.RGBA_FLOAT16;
				treq.minFilter = TextureMinFilter.Linear;
				treq.magFilter = TextureMagFilter.Linear;
				treq.wrapS = TextureWrap.ClampToBorder;
				treq.wrapT = TextureWrap.ClampToBorder;
				cfg.color[0] = fbTex = rendererBackend.createTexture(
					size,
					treq
				);
			}
				
			cfg.depth = RenderBuffer(
				size,
				TextureInternalFormat.DEPTH24_STENCIL8
			);

			texFb = rendererBackend.createFramebuffer(cfg);
			assert (texFb.valid);
			rendererBackend.framebuffer = texFb;
		}
	}


	override void render() {
		version (FixedTest) {}
		else {
			if (keyboard.keyDown(KeySym.e)) {
				/+for (int li = 0; li < lights.length; ++li) {
					lightAngles[li] += lightSpeeds[li] * -0.01;
				}+/
			} else {
				for (int li = 0; li < lights.length; ++li) {
					lightAngles[li] += lightSpeeds[li];
				}
			}
		}

		renderables.transform[pointCloudRid].rotation *= quat.yRotation(0.01);

		for (int li = 0; li < lights.length; ++li) {
			lightAngles[li] = fmodf(lightAngles[li], 360.0);
		}

		static float lightDist = 1.0f;
		if (keyboard.keyDown(KeySym._1)) {
			lightDist *= 0.995f;
		}
		if (keyboard.keyDown(KeySym._2)) {
			lightDist /= 0.995f;
		}
		
		static float lightScale = 0.0f;
		if (0 == lightScale) lightScale = 4.5f / lights.length;
		if (keyboard.keyDown(KeySym.Down)) {
			lightScale *= 0.99f;
		}
		if (keyboard.keyDown(KeySym.Up)) {
			lightScale /= 0.99f;
		}

		if (keyboard.keyDown(KeySym.equal)) {
			foreach (ref ls; lightSpeeds) {
				ls /= 0.99f;
			}
		}
		if (keyboard.keyDown(KeySym.minus)) {
			foreach (ref ls; lightSpeeds) {
				ls *= 0.99f;
			}
		}

		static float lightRad = 0.1f;
		if (keyboard.keyDown(KeySym._3)) {
			lightRad *= 0.99f;
		}
		if (keyboard.keyDown(KeySym._4)) {
			lightRad /= 0.99f;
		}

		static float bgColor = 0.005f;
		
		if (keyboard.keyDown(KeySym.Left)) {
			bgColor *= 0.99f;
		}
		if (keyboard.keyDown(KeySym.Right)) {
			bgColor /= 0.99f;
		}

		foreach (li, l; lights) {
			version (Sponza) {
				vec3 posMult = vec3(12, 1, 4);
				l.position = posMult * quat.yRotation(lightAngles[li]).xform(lightOffsets[li] + vec3(0, 0, 1) * (lightDist + lightDists[li]));
			} else {
				l.position = quat.yRotation(lightAngles[li]).xform(lightOffsets[li] + vec3(0, 0, 2) * (lightDist + lightDists[li]));
			}
			l.lumIntens = lightIllums[li] * lightScale;
			l.radius = lightRad;
		}

		/+lights[0].position = quat.yRotation(lightRot).xform(vec3(0, 1, 0) + vec3(0, 0, -2) * lightDist);
		lights[1].position = quat.yRotation(-lightRot*1.1).xform(vec3(0, 2, 0) + vec3(0, 0, 2) * lightDist);
		lights[2].position = quat.yRotation(-lightRot*1.22).xform(vec3(0, 4, 0) + vec3(0, 0, 2) * lightDist);

		lights[0].lumIntens = vec4(1, 0.1, 0.01, 0) * lightScale;
		lights[1].lumIntens = vec4(0.1, 0.3, 1.0, 0) * lightScale;
		lights[2].lumIntens = vec4(0.3, 1.0, 0.6, 0) * lightScale;
		
		lights[0].radius = lightRad;
		lights[1].radius = lightRad;
		lights[2].radius = lightRad;+/

		// move some objects

		// The various arrays for VSD must be updated as they may have been
		// resized externally and VSD now holds the old reference.
		// The VSD does not have a copy of the various data associated with
		// Renderables as to reduce allocations and unnecessary copies of dta.
		vsd.transforms = renderables.transform[0..renderables.length];
		vsd.localHalfSizes = renderables.localHalfSize[0..renderables.length];
		tvsd.transforms = vsd.transforms;
		tvsd.localHalfSizes = vsd.localHalfSizes;
		
		// update vsd.enabledFlags
		// update vsd.invalidationFlags
		//vsd.enableObject(rid);
		//vsd.invalidateObject(rid);
		
		vsd.update();
		tvsd.update();

		static bool wantDeferred = true; {
			static bool prevKeyDown = false;
			bool keyDown = keyboard.keyDown(KeySym.Return);
			if (keyDown && !prevKeyDown) {
				wantDeferred ^= true;
				if (wantDeferred) {
					Stdout.formatln("Using the light pre-pass renderer.");
				} else {
					Stdout.formatln("Using the forward renderer.");
				}
			}
			prevKeyDown = keyDown;
		}


		final nr = wantDeferred ? this.nr : this.nr2;
		final tnr = this.nr2;

		final rlist = nr.createRenderList();
		final trlist = tnr.createRenderList();
		scope (exit) {
			nr.disposeRenderList(rlist);
			tnr.disposeRenderList(trlist);
		}

		final viewSettings = ViewSettings(
			camera.coordSys,
			60.0f,		// fov
			cast(float)window.width / window.height,	// aspect
			0.1f,		// near plane
			1000.0f		// far plane
		);

		buildRenderList(&vsd, viewSettings, rlist);
		buildRenderList(&tvsd, viewSettings, trlist);

		static bool wantPost = true; {
			static bool prevKeyDown = false;
			bool keyDown = keyboard.keyDown(KeySym.space);
			if (keyDown && !prevKeyDown) {
				wantPost ^= true;
				Stdout.formatln(
					"Post-processing {}.",
					wantPost ? "enabled" : "disabled"
				);
			}
			prevKeyDown = keyDown;
		}

		with (rendererBackend.state.cullFace) {
			enabled = true;
			front = false;
			back = true;
		}

		rendererBackend.state.sRGB = true;

		void renderTranslucent() {
			/+final st = *rendererBackend.state;
			with (rendererBackend.state.blend) {
				enabled = true;
				src = src.One;
				dst = dst.One;
			}
			with (rendererBackend.state.depth) {
				writeMask = false;
			}
			tnr.render(viewSettings, &tvsd, trlist);
			*rendererBackend.state = st;+/
		}

		if (wantPost) {
			rendererBackend.framebuffer = texFb;

			rendererBackend.resetStats();
			rendererBackend.framebuffer.settings.clearColorValue[0] = vec4.one * bgColor;
			rendererBackend.clearBuffers();

			nr.render(viewSettings, &vsd, rlist);
			renderTranslucent();

			rendererBackend.framebuffer = mainFb;
			rendererBackend.clearBuffers();

			post.render(fbTex);
		} else {
			rendererBackend.framebuffer = mainFb;

			rendererBackend.resetStats();
			rendererBackend.framebuffer.settings.clearColorValue[0] = vec4.one * bgColor;
			rendererBackend.clearBuffers();

			nr.render(viewSettings, &vsd, rlist);
			renderTranslucent();
		}


		nucleusHotSwap();
	}
}


import tango.stdc.stdio : getchar;
import tango.stdc.stdlib : exit;

void main(cstring[] args) {
	//GC.disable();
	
	try {
		(new TestApp).run;
	} catch (Exception e) {
		e.writeOut((cstring s) { Stdout(s); });
		Stdout.newline();
		Stdout.formatln("Hit me with like an Enter.");
		getchar();
		exit(1);
	}
}
