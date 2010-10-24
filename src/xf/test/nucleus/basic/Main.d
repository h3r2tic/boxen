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


//version = LightTest2;


class TestApp : GfxApp {
	Renderer		nr;
	Renderer		nr2;
	VSDRoot			vsd;
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


	override void configureWindow(Window w) {
		w.width = 1680/2;
		w.height = 1050/2;
		//w.fullscreen = true;
	}


	override void initialize() {
		version (FixedTest) {
			Kiss.instance.seed(12345);
		}

		version (Demo) {
			setMediaDir(`media`);
			initializeNucleus(this.renderer, "media/kdef", ".");
		} else {
			setMediaDir(`../../media`);
			initializeNucleus(this.renderer, "../../media/kdef", ".");
		}
		
		nr = createRenderer("LightPrePass");
		nr2 = createRenderer("Forward");
		
		post = new PostProcessor(rendererBackend, kdefRegistry);
		post.setKernel("PostGlareAcuityNoise");

		// TODO: configure the VSD spatial subdivision
		vsd = VSDRoot();

		version (Sponza) {
			camera = new SimpleCamera(vec3(-7.54, 2.9, 5.03), -7.00, 12.80, inputHub.mainChannel);
		} else {
			//camera = new SimpleCamera(vec3(0, 3, 4), 0, 0, inputHub.mainChannel);

			version (LightTest2) {
				camera = new SimpleCamera(vec3(-9.85, 7.32, 9.65), -22.40, -12.60, inputHub.mainChannel);
			} else {
				//camera = new SimpleCamera(vec3(0, 1, 2), 0, 0, inputHub.mainChannel);
				camera = new SimpleCamera(vec3(-0.44, 2.22, 1.5), -32.80, -17.80, inputHub.mainChannel);
				//camera = new SimpleCamera(vec3(-0.4, 1.93, 1.77), -27.80, -4.20, inputHub.mainChannel);
				//camera = new SimpleCamera(vec3(0.43, 2.11, 1.34), -31.00, 20.20, inputHub.mainChannel);
				//camera = new SimpleCamera(vec3(-0.08, 0.02, 0.81), 0.80, 1.20, inputHub.mainChannel);
			}
		}
		window.interceptCursor = true;
		window.showCursor = false;

		// ----

		version (FixedTest) {
			const numLights = 50;
			alias PointLight LightType;
		} else {
			const numLights = 3;

			version (LightTest2) {
				alias PointLight LightType;
			} else {
				//alias SpotLight_VSM LightType;
				alias PointLight LightType;
			}
		}
		
		for (int i = 0; i < numLights; ++i) {
			createLight((lights ~= new LightType)[$-1]);
			version (Sponza) {
				lightOffsets ~= vec3(0, 0.1 + Kiss.instance.fraction() * 10.0, 0);
				lightAngles ~= Kiss.instance.fraction() * 360.0f;
				lightDists ~= Kiss.instance.fraction() * 5;
				lightSpeeds ~= 0.7f * (0.3f * Kiss.instance.fraction() + 0.7f) * (Kiss.instance.fraction() > 0.5f ? 1 : -1);
			} else {
				lightOffsets ~= vec3(0, 2.0 + Kiss.instance.fraction() * 3.0, 0);
				lightAngles ~= Kiss.instance.fraction() * 360.0f;
				lightDists ~= Kiss.instance.fraction() * 0.3f + 0.15f;
				lightSpeeds ~= 0.2f * (0.3f * Kiss.instance.fraction() + 0.7f) * (Kiss.instance.fraction() > 0.5f ? 1 : -1);

				/+lightOffsets ~= vec3(0, -2 + Kiss.instance.fraction() * 4, 0);
				lightAngles ~= Kiss.instance.fraction() * 360.0f;
				lightDists ~= Kiss.instance.fraction() * 0.3f - 0.15f;
				lightSpeeds ~= 0.2f * (0.3f * Kiss.instance.fraction() + 0.7f) * (Kiss.instance.fraction() > 0.5f ? 1 : -1);+/
			}

			float h = cast(float)i / numLights;//Kiss.instance.fraction();
			float s = 0.2f;
			float v = 1.0f;

			vec4 rgba = vec4.zero;
			hsv2rgb(h, s, v, &rgba.r, &rgba.g, &rgba.b);

			version (FixedTest) {
				lightIllums ~= rgba * (1000.f / numLights);
			} else {
				lightIllums ~= 40 * rgba;// * (1000.f / numLights);
			}
		}

		version (LightTest2) {} else {
			lightIllums[0] *= 0.25;
			lightIllums[1] *= 0.35;
		}

		lightAngles[0] = 0;
		lightAngles[1] = 120;
		lightAngles[2] = 240;
		
		lightSpeeds[0..3] = 0.1f;

		lightOffsets[0] = vec3.unitY * 4;
		lightOffsets[1] = vec3.unitY * 4;
		lightOffsets[2] = vec3.unitY * 3;

		lightOffsets[] = vec3.unitY * 6;

		// ----

		version (LightTest2) {
			cstring model = `mesh/lightTest2.hsf`;
			float scale = 1.0f;
		} else {
			//cstring model = `mesh/bunny.hsf`;
			//cstring model = `mesh/nano.hsf`;
			//cstring model = `mesh/knot.hsf`;
			//cstring model = `mesh/somefem.hsf`;
			//cstring model = `mesh/dragon.hsf`;
			//cstring model = `mesh/maskedPlane.hsf`;
			cstring model = `mesh/ubot.hsf`;
			//cstring model = `mesh/buddha.hsf`;
			//cstring model = `mesh/spartan.hsf`;
			float scale = 1.0f;
			/+cstring model = `mesh/masha.hsf`;
			//cstring model = `mesh/cia.hsf`;
			float scale = 0.01f;+/
		}

		SceneAssetCompilationOptions opts;
		opts.scale = scale;

		final compiledScene = compileHSFSceneAsset(
			model,
			DgScratchAllocator(&mainHeap.allocRaw),
			opts
		);

		assert (compiledScene !is null);

		loadScene(compiledScene, &vsd, CoordSys(vec3fi[0, 0, 0]));

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
/+				/+for (int li = 0; li < lights.length; ++li) {
					lightAngles[li] += lightSpeeds[li] * -0.01;
				}+/
			} else {+/
				for (int li = 0; li < lights.length; ++li) {
					lightAngles[li] += lightSpeeds[li];
				}
			}
		}

		for (int li = 0; li < lights.length; ++li) {
			lightAngles[li] = fmodf(lightAngles[li], 360.0);
		}

		static float lightDist = 1.5f;
		if (keyboard.keyDown(KeySym._1)) {
			lightDist *= 0.995f;
		}
		if (keyboard.keyDown(KeySym._2)) {
			lightDist /= 0.995f;
		}
		
		static float lightScale = 0.0f;
		if (0 == lightScale) lightScale = 10.0f / lights.length;
		if (keyboard.keyDown(KeySym.Down)) {
			lightScale *= 0.99f;
		}
		if (keyboard.keyDown(KeySym.Up)) {
			lightScale /= 0.99f;
		}

		static float lightRad = 2.0f;
		if (keyboard.keyDown(KeySym._3)) {
			lightRad *= 0.99f;
		}
		if (keyboard.keyDown(KeySym._4)) {
			lightRad /= 0.99f;
		}

		static float bgColor = 0.01f;
		
		if (keyboard.keyDown(KeySym.Left)) {
			bgColor *= 0.99f;
		}
		if (keyboard.keyDown(KeySym.Right)) {
			bgColor /= 0.99f;
		}

		foreach (li, l; lights) {
			l.position = quat.yRotation(lightAngles[li]).xform(lightOffsets[li] + vec3(0, 0, 2) * (lightDist + lightDists[li]));
			l.lumIntens = lightIllums[li] * lightScale;
			l.radius = lightRad;
		}
		// move some objects

		// The various arrays for VSD must be updated as they may have been
		// resized externally and VSD now holds the old reference.
		// The VSD does not have a copy of the various data associated with
		// Renderables as to reduce allocations and unnecessary copies of dta.
		vsd.transforms = renderables.transform[0..renderables.length];
		vsd.localHalfSizes = renderables.localHalfSize[0..renderables.length];
		
		// update vsd.enabledFlags
		// update vsd.invalidationFlags
		//vsd.enableObject(rid);
		//vsd.invalidateObject(rid);
		
		vsd.update();

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

		if (wantPost) {
			rendererBackend.framebuffer = texFb;

			rendererBackend.resetStats();
			rendererBackend.framebuffer.settings.clearColorValue[0] = vec4.one * bgColor;
			rendererBackend.clearBuffers();

			nr.render(viewSettings, &vsd, rlist);

			rendererBackend.framebuffer = mainFb;
			rendererBackend.clearBuffers();

			post.render(fbTex);
		} else {
			rendererBackend.framebuffer = mainFb;

			rendererBackend.resetStats();
			rendererBackend.framebuffer.settings.clearColorValue[0] = vec4.one * bgColor;
			rendererBackend.clearBuffers();

			nr.render(viewSettings, &vsd, rlist);
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
