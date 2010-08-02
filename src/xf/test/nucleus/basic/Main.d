module Main;

private {
	version (StackTracing) {
		import tango.core.tools.TraceExceptions;
	}
	
	import xf.Common;
	import xf.utils.GfxApp;
	import xf.utils.SimpleCamera;
	
	import Nucleus = xf.nucleus.Nucleus;
	import xf.nucleus.Defs;
	import xf.nucleus.Renderer;
	import xf.nucleus.Renderable;
	import xf.nucleus.Light;
	import xf.nucleus.CompiledMeshAsset;
	import xf.nucleus.post.PostProcessor;

	import xf.nucleus.Nucleus;
	import xf.nucleus.light.TestLight;
	import xf.nucleus.structure.MeshStructure;
	import xf.nucleus.structure.KernelMapping;

	import xf.nucleus.kdef.model.IKDefRegistry;

	import xf.vsd.VSD;

	import xf.loader.scene.model.Mesh : LoaderMesh = Mesh;
	import xf.loader.scene.hsf.Hsf;

	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.CoordSys;
	import xf.omg.util.ViewSettings;

	static import xf.utils.Memory;

	import Path = tango.io.Path;
	import tango.io.Stdout;
	
	import tango.math.random.Kiss;
	import tango.stdc.math : fmodf;
	import xf.omg.color.HSV;
}


//version = LightTest;


import xf.mem.MainHeap;
T mallocObject(T)() {
	void[] data = mainHeap.allocRaw(T.classinfo.init.length)[0..T.classinfo.init.length];
	data[] = T.classinfo.init;
	return cast(T)cast(void*)data.ptr;
}

import tango.core.Memory;

class TestApp : GfxApp {
	alias renderer rendererBackend;
	Renderer		nr;
	Renderer		nr2;
	VSDRoot			vsd;
	SimpleCamera	camera;
	

	Texture			fbTex;
	Framebuffer		mainFb;
	Framebuffer		texFb;

	PostProcessor	post;


	TestLight[]		lights;
	vec3[]			lightOffsets;
	float[]			lightDists;
	float[]			lightSpeeds;
	float[]			lightAngles;
	vec4[]			lightIllums;
	

	override void initialize() {
		initializeNucleus(this.rendererBackend, "../../media/kdef", ".");
		
		nr = Nucleus.createRenderer("LightPrePass");
		nr2 = Nucleus.createRenderer("Forward");
		
		post = new PostProcessor(rendererBackend, kdefRegistry);
		post.setKernel("TestPost");

		// TODO: configure the VSD spatial subdivision
		vsd = VSDRoot();

		camera = new SimpleCamera(vec3(0, 0, 10), 0, 0, inputHub.mainChannel);
		window.interceptCursor = true;
		window.showCursor = false;

		// Connect renderable creation to VSD object creation
		registerRenderableObserver(new class IRenderableObserver {
			void onRenderableCreated(RenderableId id) {
				vsd.createObject(id);
			}
			
			void onRenderableDisposed(RenderableId id) {
				vsd.disposeObject(id);
			}
			
			void onRenderableInvalidated(RenderableId id) {
				vsd.invalidateObject(id);
			}
		});

		// ----

		const numLights = 3;
		for (int i = 0; i < numLights; ++i) {
			createLight((lights ~= new TestShadowedLight)[$-1]);
			version (Sponza) {
				lightOffsets ~= vec3(0, 0.1 + Kiss.instance.fraction() * 10.0, 0);
				lightAngles ~= Kiss.instance.fraction() * 360.0f;
				lightDists ~= Kiss.instance.fraction() * 5;
				lightSpeeds ~= 0.7f * (0.3f * Kiss.instance.fraction() + 0.7f) * (Kiss.instance.fraction() > 0.5f ? 1 : -1);
			} else {
				lightOffsets ~= vec3(0, 1.0 + Kiss.instance.fraction() * 3.0, 0);
				lightAngles ~= Kiss.instance.fraction() * 360.0f;
				lightDists ~= Kiss.instance.fraction() * 0.3f - 0.15f;
				lightSpeeds ~= 0.7f * (0.3f * Kiss.instance.fraction() + 0.7f) * (Kiss.instance.fraction() > 0.5f ? 1 : -1);
			}

			float h = cast(float)i / numLights;//Kiss.instance.fraction();
			float s = 0.6f;
			float v = 1.0f;

			vec4 rgba = vec4.zero;
			hsv2rgb(h, s, v, &rgba.r, &rgba.g, &rgba.b);
			lightIllums ~= rgba;
		}

		// ----

		void loadScene(cstring path, float scale, CoordSys cs, cstring surface, cstring material) {
			path = Path.normalize(path);
			
			scope loader = new HsfLoader;
			loader.load(path);
			
			final scene = loader.scene;
			assert (scene !is null);
			assert (loader.meshes.length > 0);
			
			assert (1 == scene.nodes.length);
			final root = scene.nodes[0];

			void iterAssetMeshes(void delegate(int, ref LoaderMesh) dg) {
				foreach (i, ref m; loader.meshes) {
					dg(i, m);
				}
			}
			
			iterAssetMeshes((int, ref LoaderMesh m) {
				// This should be a part of the content pipeline

				MeshAssetCompilationOptions opts;
				opts.scale = scale;

				final compiledMesh = compileMeshAsset(m, opts);
				
				final ms = mallocObject!(MeshStructure);
				ms._ctor(compiledMesh, rendererBackend);

				final rid = createRenderable();	
				renderables.structureKernel[rid] = defaultStructureKernel(ms.structureTypeName);
				renderables.structureData[rid] = ms;

				renderables.material[rid] = getMaterialIdByName(material);
				renderables.surface[rid] = getSurfaceIdByName(surface);
				renderables.transform[rid] = cs;
				renderables.localHalfSize[rid] = compiledMesh.halfSize;
			});
		}

		//loadScene(, 0.02f, CoordSys.identity, "CookTorrance", "TestMaterialImpl");

		version (Sponza) {
			cstring model = `../../media/mesh/sponza.hsf`;
			float scale = 1f;

			loadScene(
				model, scale, CoordSys(vec3fi[0, -3, 0]),
				"TestSurface3", "TestMaterialImpl"
			);
		} else version (Sibenik) {
			cstring model = `../../media/mesh/sibenik.hsf`;
			float scale = 1f;

			loadScene(
				model, scale, CoordSys(vec3fi[0, -3, 0]),
				"TestSurface3", "TestMaterialImpl"
			);
		} else version (LightTest) {
			cstring model = `../../media/mesh/lightTest.hsf`;
			float scale = 0.01f;

			loadScene(
				model, scale, CoordSys(vec3fi[0, 1, 0]),
				"TestSurface3", "TestMaterialImpl"
			);
		} else {
			/+cstring model = `../../media/mesh/soldier.hsf`;
			float scale = 1.0f;+/
			cstring model = `../../media/mesh/masha.hsf`;
			//cstring model = `../../media/mesh/foo.hsf`;
			float scale = 0.02f;

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

			loadScene(
				model, scale, CoordSys(vec3fi[0, -2, 0]),
				"TestSurface3", "TestMaterialImpl"
			);
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
		if (keyboard.keyDown(KeySym.e)) {
			for (int li = 0; li < lights.length; ++li) {
				lightAngles[li] += lightSpeeds[li] * -0.01;
			}
		} else {
			for (int li = 0; li < lights.length; ++li) {
				lightAngles[li] += lightSpeeds[li];
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

		static float lightRad = 1.0f;
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
			l.position = quat.yRotation(lightAngles[li]).xform(lightOffsets[li] + vec3(0, 0, 2) * (lightDist + lightDists[li]));
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

		final rlist = nr.createRenderList();
		scope (exit) nr.disposeRenderList(rlist);

		final viewSettings = ViewSettings(
			camera.coordSys,
			60.0f,		// fov
			cast(float)window.width / window.height,	// aspect
			0.1f,		// near plane
			1000.0f		// far plane
		);

		vsd.findVisible(viewSettings, (VisibleObject[] olist) {
			foreach (o; olist) {
				final bin = rlist.add();
				static assert (RenderableId.sizeof == typeof(o.id).sizeof);
				rlist.list.renderableId[bin] = cast(RenderableId)o.id;
				rlist.list.coordSys[bin] = renderables.transform[o.id];
			}
		});

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


		if (kdefRegistry.invalidated) {
			kdefRegistry.reload();
		}
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
