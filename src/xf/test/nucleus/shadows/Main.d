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


	/+override void configureWindow(Window w) {
		w.width = 1050;
		w.height = 1680;
		w.fullscreen = true;
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

		camera = new SimpleCamera(vec3(2.21, 2.77, 4.7), 688.40, -684.00, inputHub.mainChannel);
		window.interceptCursor = true;
		window.showCursor = false;

		// ----

		{
			createLight((lights ~= new SpotLight_SM)[$-1]);
			lightOffsets ~= vec3(0, 4, 0);
			lightAngles ~= 110;
			lightDists ~= 2;
			lightSpeeds ~= 1.0f;
			lightIllums ~= vec4[1, 1, 1, 0.0] * 250.0f;
		}

		// ----

		//cstring model = `mesh/bunny.hsf`;
		//cstring model = `mesh/nano.hsf`;
		//cstring model = `mesh/knot.hsf`;
		//cstring model = `mesh/somefem.hsf`;
		//cstring model = `mesh/dragon.hsf`;
		cstring model = `mesh/manitou.hsf`;
		//cstring model = `mesh/hog.hsf`;
		//cstring model = `mesh/buddha.hsf`;
		//cstring model = `mesh/spartan.hsf`;
		float scale = 1.0f;
		/+cstring model = `mesh/masha.hsf`;
		//cstring model = `mesh/cia.hsf`;
		float scale = 0.01f;+/

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
				for (int li = 0; li < lights.length; ++li) {
					lightAngles[li] += lightSpeeds[li];
				}
			}
		}

		for (int li = 0; li < lights.length; ++li) {
			lightAngles[li] = fmodf(lightAngles[li], 360.0);
		}

		static float lightDist = 0.8f;
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

		static float lightRad = 3.0f;
		if (keyboard.keyDown(KeySym._3)) {
			lightRad *= 0.99f;
		}
		if (keyboard.keyDown(KeySym._4)) {
			lightRad /= 0.99f;
		}

		vec4 bgColor = vec4.one * 0.1;
		
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
			rendererBackend.framebuffer.settings.clearColorValue[0] = bgColor;
			rendererBackend.clearBuffers();

			nr.render(viewSettings, &vsd, rlist);

			rendererBackend.framebuffer = mainFb;
			rendererBackend.clearBuffers();

			post.render(fbTex);
		} else {
			rendererBackend.framebuffer = mainFb;

			rendererBackend.resetStats();
			rendererBackend.framebuffer.settings.clearColorValue[0] = bgColor;
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
