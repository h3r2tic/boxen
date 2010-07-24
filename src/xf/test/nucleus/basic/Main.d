module Main;

private {
	version (StackTracing) {
		import tango.core.tools.TraceExceptions;
	}
	
	import xf.Common;
	import xf.core.Registry;
	import xf.utils.GfxApp;
	import xf.utils.SimpleCamera;
	
	import Nucleus = xf.nucleus.Nucleus;
	import xf.nucleus.Defs;
	import xf.nucleus.Renderer;
	import xf.nucleus.Renderable;
	import xf.nucleus.Light;
	import xf.nucleus.IStructureData;
	import xf.nucleus.CompiledMeshAsset;
	import xf.nucleus.KernelParamInterface;
	import xf.nucleus.SurfaceDef;
	import xf.nucleus.MaterialDef;
	import xf.nucleus.post.PostProcessor;

	import xf.nucleus.kdef.model.IKDefRegistry;

	import xf.gfx.IRenderer : IRenderer;
	import xf.gfx.Buffer;
	import xf.gfx.VertexBuffer;
	import xf.gfx.IndexBuffer;
	import xf.gfx.IndexData;
	import xf.gfx.Log;

	import xf.vsd.VSD;

	import xf.loader.scene.model.Mesh : LoaderMesh = Mesh;
	import xf.loader.scene.hsf.Hsf;

	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.CoordSys;
	import xf.omg.util.ViewSettings;

	import tango.core.Variant;

	static import xf.utils.Memory;

	import tango.io.vfs.FileFolder;
	import Path = tango.io.Path;
	import tango.io.Stdout;
	
	import tango.math.random.Kiss;
	import tango.stdc.math : fmodf;
	import xf.omg.color.HSV;
}



// TODO: better mem
class MeshStructure : IStructureData {
	this (CompiledMeshAsset ma, IRenderer renderer) {
		vertexBuffer = renderer.createVertexBuffer(
			BufferUsage.StaticDraw,
			ma.vertexData
		);

		xf.utils.Memory.alloc(vertexAttribs, ma.vertexAttribs.length);
		xf.utils.Memory.alloc(vertexAttribNames, ma.vertexAttribs.length);

		foreach (i, ref va; vertexAttribs) {
			va = ma.vertexAttribs[i].attrib;
		}

		size_t totalNameLen = 0;
		foreach (a; ma.vertexAttribs) {
			totalNameLen += a.name.length;
		}

		char[] nameBuf;
		xf.utils.Memory.alloc(nameBuf, totalNameLen);

		foreach (i, a; ma.vertexAttribs) {
			vertexAttribNames[i] = nameBuf[0..a.name.length];
			vertexAttribNames[i][] = a.name;
			nameBuf = nameBuf[a.name.length..$];
		}
		
		assert (0 == nameBuf.length);

		indexData.indexBuffer = renderer.createIndexBuffer(
			BufferUsage.StaticDraw,
			ma.indices
		);
		indexData.numIndices	= ma.numIndices;
		indexData.indexOffset	= ma.indexOffset;
		indexData.minIndex		= ma.minIndex;
		indexData.maxIndex		= ma.maxIndex;
	}

	cstring structureTypeName() {
		return "Mesh";
	}

	void setKernelObjectData(KernelParamInterface kpi) {
		kpi.setIndexData(&indexData);
		
		foreach (i, ref attr; vertexAttribs) {
			final name = vertexAttribNames[i];
			final param = kpi.getVaryingParam(name);
			if (param !is null) {
				param.buffer = &vertexBuffer;
				param.attrib = &attr;
			} else {
				gfxLog.warn("No param named '{}' in the kernel.", name);
			}
		}
	}

	// TODO: hardcode the available data and expose meta-info

	private {
		VertexBuffer	vertexBuffer;

		// allocated with xf.utils.Memory
		VertexAttrib[]	vertexAttribs;
		cstring[]		vertexAttribNames;

		IndexData		indexData;
	}
}


class TestLight : Light {
	override cstring kernelName() {
		return "TestLight";
	}
	
	override void setKernelData(KernelParamInterface kpi) {
		kpi.bindUniform("lightPos", &position);
		kpi.bindUniform("lumIntens", &lumIntens);
		kpi.bindUniform("radius", &radius);
		kpi.bindUniform("influenceRadius", &influenceRadius);
	}

	float	radius;
}


void createDepthTex() {
}


class TestShadowedLight : TestLight {
	override cstring kernelName() {
		return "TestShadowedLight";
	}

	override void prepareRenderData() {
		calcInfluenceRadius();

		if (!spotlightMask.valid) {
			cstring filePath = `../../media/img/spotlight.dds`;
			Img.Image img = depthRenderer._imgLoader.load(filePath);
			if (!img.valid) {
				Stdout.formatln("Could not load texture: '{}'", filePath);
				assert (false);
			}

			spotlightMask = rendererBackend.createTexture(
				img
			);
		}

		if (!depthFb.valid) {
			final cfg = FramebufferConfig();
			cfg.size = shadowMapSize;
			cfg.location = FramebufferLocation.Offscreen;

			{
				TextureRequest treq;
				treq.internalFormat = TextureInternalFormat.RG32F;
				treq.minFilter = TextureMinFilter.Linear;
				treq.magFilter = TextureMagFilter.Linear;
				treq.wrapS = TextureWrap.ClampToBorder;
				treq.wrapT = TextureWrap.ClampToBorder;
				cfg.color[0] = depthTex = rendererBackend.createTexture(
					shadowMapSize,
					treq
				);
				assert (depthTex.valid);
			}
				
			depthFb = rendererBackend.createFramebuffer(cfg);
			assert (depthFb.valid);
		}

		if (!sharedDepthFb.valid) {
			final cfg = FramebufferConfig();
			cfg.size = shadowMapSize;
			cfg.location = FramebufferLocation.Offscreen;

			{
				TextureRequest treq;
				treq.internalFormat = TextureInternalFormat.RG32F;
				treq.minFilter = TextureMinFilter.Linear;
				treq.magFilter = TextureMagFilter.Linear;
				treq.wrapS = TextureWrap.ClampToBorder;
				treq.wrapT = TextureWrap.ClampToBorder;
				cfg.color[0] = sharedDepthTex = rendererBackend.createTexture(
					shadowMapSize,
					treq
				);
				assert (sharedDepthTex.valid);
			}
				
			cfg.depth = RenderBuffer(
				shadowMapSize,
				TextureInternalFormat.DEPTH_COMPONENT32F
			);

			sharedDepthFb = rendererBackend.createFramebuffer(cfg);
			assert (sharedDepthFb.valid);
		}
		
		vec3 target = vec3.zero;		// HACK
		this.worldToView = mat4.lookAt(this.position, target);
		assert (this.worldToView.ok);
		
		this.viewToClip = mat4.perspective(
			60.0f,		// fov
			1.0,		// aspect
			0.1f,		// near plane
			influenceRadius		// far plane
		);
		assert (this.viewToClip.ok);
		
		this.worldToClip = viewToClip * worldToView;
		assert (this.worldToClip.ok);

		final nr = depthRenderer;
		final rlist = nr.createRenderList();
		final origFb = rendererBackend.framebuffer;
		
		scope (exit) {
			rendererBackend.framebuffer = origFb;
			nr.disposeRenderList(rlist);
		}

		rendererBackend.framebuffer = sharedDepthFb;
		rendererBackend.framebuffer.settings.clearColorValue[0] = vec4.zero;
		rendererBackend.clearBuffers();

		auto viewCs = CoordSys(worldToView).inverse;
		final viewSettings = ViewSettings(
			viewCs,
			60.0f,		// fov
			1.0,		// aspect
			0.1f,		// near plane
			influenceRadius		// far plane
		);

		vsd.findVisible(viewSettings, (VisibleObject[] olist) {
			foreach (o; olist) {
				final bin = rlist.add();
				static assert (RenderableId.sizeof == typeof(o.id).sizeof);
				rlist.list.renderableId[bin] = cast(RenderableId)o.id;
				rlist.list.coordSys[bin] = renderables.transform[o.id];
			}
		});

		with (rendererBackend.state.cullFace) {
			enabled = true;
			front = false;
			back = true;
		}

		nr.render(viewSettings, rlist);

		rendererBackend.framebuffer = depthFb;
		depthPost.render(sharedDepthTex);
	}

	vec2i shadowMapSize = { x: 512, y: 512 };
	
	mat4 worldToView;
	mat4 viewToClip;
	mat4 worldToClip;

	Framebuffer depthFb;
	Texture		depthTex;
	
	static Framebuffer	sharedDepthFb;
	static Texture		sharedDepthTex;

	static Texture	spotlightMask;

	override void setKernelData(KernelParamInterface kpi) {
		super.setKernelData(kpi);
		kpi.bindUniform("depthSampler", &depthTex);
		kpi.bindUniform("spotlightMask", &spotlightMask);
		kpi.bindUniform("light_worldToClip", &worldToClip);
	}
}


Renderer		depthRenderer;
IRenderer		rendererBackend;
VSDRoot			vsd;
PostProcessor	depthPost;



cstring defaultStructureKernel(cstring structureTypeName) {
	switch (structureTypeName) {
		case "Mesh": return "DefaultMeshStructure";
		default: assert (false, structureTypeName);
	}
}



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
	//VSDRoot			vsd;
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

	IKDefRegistry	kdefRegistry;
	FileFolder		vfs;

	override void initialize() {
		GC.disable();

		.rendererBackend = rendererBackend;
		
		final vfs = new FileFolder(".");

		kdefRegistry = create!(IKDefRegistry)();
		kdefRegistry.setVFS(vfs);
		kdefRegistry.registerFolder("../../media/kdef");
		kdefRegistry.registerFolder(".");
		kdefRegistry.reload();
		kdefRegistry.dumpInfo();

		// ----

		SurfaceId[cstring]	surfaces;
		SurfaceId			nextSurfaceId;

		MaterialId[cstring]	materials;
		MaterialId			nextMaterialId;

		depthRenderer = Nucleus.createRenderer("Depth", rendererBackend, kdefRegistry);
		depthRenderer.setParam("outKernel", Variant("VarianceDepthRendererOut"));

		nr = Nucleus.createRenderer("LightPrePass", rendererBackend, kdefRegistry);
		nr2 = Nucleus.createRenderer("Forward", rendererBackend, kdefRegistry);
		
		kdefRegistry.registerObserver(depthRenderer);
		kdefRegistry.registerObserver(nr);
		kdefRegistry.registerObserver(nr2);
		registerLightObserver(nr);
		registerLightObserver(nr2);

		post = new PostProcessor(rendererBackend, kdefRegistry);
		post.setKernel("TestPost");

		depthPost = new PostProcessor(rendererBackend, kdefRegistry);
		depthPost.setKernel("TestDepthPost");

		foreach (surfName, surf; &kdefRegistry.surfaces) {
			surf.id = nextSurfaceId++;
			surf.reflKernel = kdefRegistry.getKernel(surf.reflKernelName);
			nr.registerSurface(surf);
			nr2.registerSurface(surf);
			surfaces[surfName.dup] = surf.id;
		}

		foreach (matName, mat; &kdefRegistry.materials) {
			mat.id = nextMaterialId++;
			mat.materialKernel = kdefRegistry.getKernel(mat.materialKernelName);
			nr.registerMaterial(mat);
			nr2.registerMaterial(mat);
			materials[matName.dup] = mat.id;
		}

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
			lightOffsets ~= vec3(0, 1.0 + Kiss.instance.fraction() * 3.0, 0);
			lightAngles ~= Kiss.instance.fraction() * 360.0f;
			lightDists ~= Kiss.instance.fraction() * 0.3f - 0.15f;
			lightSpeeds ~= 0.7f * (0.3f * Kiss.instance.fraction() + 0.7f) * (Kiss.instance.fraction() > 0.5f ? 1 : -1);

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
				assert (material in materials, material);
				renderables.material[rid] = materials[material];
				renderables.surface[rid] = surfaces[surface];
				renderables.transform[rid] = cs;
				renderables.localHalfSize[rid] = compiledMesh.halfSize;
			});
		}

		//loadScene(, 0.02f, CoordSys.identity, "CookTorrance", "TestMaterialImpl");

		version (Sibenik) {
			cstring model = `../../media/mesh/sibenik.hsf`;
			float scale = 1f;

			loadScene(
				model, scale, CoordSys(vec3fi[0, -3, 0]),
				"TestSurface3", "TestMaterialImpl"
			);
		} else {
			/+/+cstring model = `../../media/mesh/soldier.hsf`;
			float scale = 1.0f;+/
			cstring model = `../../media/mesh/masha.hsf`;
			float scale = 0.02f;

			/+loadScene(
				model, scale, CoordSys(vec3fi[-2, 0, 0]),
				"TestSurface1", "TestMaterialImpl"
			);+/
			
			loadScene(
				model, scale, CoordSys(vec3fi[0, 0, 2], quat.yRotation(90)),
				"TestSurface2", "TestMaterialImpl"
			);

			loadScene(
				model, scale, CoordSys(vec3fi[2, 0, 0], quat.yRotation(180)),
				"TestSurface3", "TestMaterialImpl"
			);+/

			/+loadScene(
				model, scale, CoordSys(vec3fi[0, 0, -2], quat.yRotation(-90)),
				"TestSurface4", "TestMaterialImpl"
			);+/

			cstring model = `../../media/mesh/lightTest.hsf`;
			float scale = 0.01f;

			loadScene(
				model, scale, CoordSys(vec3fi[0, 0, 0]),
				"TestSurface3", "TestMaterialImpl"
			);
		}

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

			nr.render(viewSettings, rlist);

			rendererBackend.framebuffer = mainFb;
			rendererBackend.clearBuffers();

			post.render(fbTex);
		} else {
			rendererBackend.framebuffer = mainFb;

			rendererBackend.resetStats();
			rendererBackend.framebuffer.settings.clearColorValue[0] = vec4.one * bgColor;
			rendererBackend.clearBuffers();

			nr.render(viewSettings, rlist);
		}


		if (kdefRegistry.invalidated) {
			kdefRegistry.reload();
		}
	}
}


import tango.stdc.stdio : getchar;

void main(cstring[] args) {
	try {
		(new TestApp).run;
	} catch (Exception e) {
		e.writeOut((cstring s) { Stdout(s); });
		Stdout.newline();
		Stdout.formatln("Hit me with like an Enter.");
		getchar();
	}
}
