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

	static import xf.utils.Memory;

	import tango.io.vfs.FileFolder;
	import Path = tango.io.Path;
	import tango.io.Stdout;
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
	}
	
	override void determineInfluenced(
		void delegate(
			bool delegate(
				ref CoordSys	cs,
				ref vec3		localHalfSize
			)
		) objectIter
	) {
		objectIter((
				ref CoordSys	cs,
				ref vec3		localHalfSize
			) {
				return true;
			}
		);
	}

	float	radius;
}



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
	VSDRoot			vsd;
	SimpleCamera	camera;
	

	Texture			fbTex;
	Framebuffer		mainFb;
	Framebuffer		texFb;

	PostProcessor	post;


	TestLight[]		lights;

	IKDefRegistry	kdefRegistry;
	FileFolder		vfs;

	override void initialize() {
		GC.disable();
		
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

		nr = Nucleus.createRenderer("LightPrePass", rendererBackend, kdefRegistry);
		//nr = Nucleus.createRenderer("Forward", rendererBackend, kdefRegistry);
		kdefRegistry.registerObserver(nr);
		registerLightObserver(nr);

		post = new PostProcessor(rendererBackend, kdefRegistry);
		post.setKernel("TestPost");

		foreach (surfName, surf; &kdefRegistry.surfaces) {
			surf.id = nextSurfaceId++;
			surf.illumKernel = kdefRegistry.getKernel(surf.illumKernelName);
			nr.registerSurface(surf);
			surfaces[surfName.dup] = surf.id;
		}

		foreach (matName, mat; &kdefRegistry.materials) {
			mat.id = nextMaterialId++;
			mat.pigmentKernel = kdefRegistry.getKernel(mat.pigmentKernelName);
			nr.registerMaterial(mat);
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
			createLight((lights ~= new TestLight)[$-1]);
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

		//loadScene(, 0.02f, CoordSys.identity, "CookTorrance", "TestPigment");

		cstring model = `../../media/mesh/soldier.hsf`;
		float scale = 1.0f;
		/+cstring model = `../../media/mesh/masha.hsf`;
		float scale = 0.02f;+/

		loadScene(
			model, scale, CoordSys(vec3fi[-2, 0, 0]),
			"TestSurface1", "TestMaterial"
		);
		
		loadScene(
			model, scale, CoordSys(vec3fi[0, 0, 2], quat.yRotation(90)),
			"TestSurface2", "TestMaterial"
		);

		loadScene(
			model, scale, CoordSys(vec3fi[2, 0, 0], quat.yRotation(180)),
			"TestSurface3", "TestMaterial"
		);

		loadScene(
			model, scale, CoordSys(vec3fi[0, 0, -2], quat.yRotation(-90)),
			"TestSurface4", "TestMaterial"
		);

		/+cstring model = `../../media/mesh/lightTest.hsf`;
		float scale = 0.01f;

		loadScene(
			model, scale, CoordSys(vec3fi[0, 1, 0]),
			"TestSurface3", "TestMaterial"
		);+/

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
		static float lightRot = 0.0f;
		lightRot += 0.1f;

		static float lightDist = 1.0f;
		if (keyboard.keyDown(KeySym._1)) {
			lightDist *= 0.995f;
		}
		if (keyboard.keyDown(KeySym._2)) {
			lightDist /= 0.995f;
		}
		
		lights[0].position = quat.yRotation(lightRot).xform(vec3(0, 1, 0) + vec3(0, 0, -2) * lightDist);
		lights[1].position = quat.yRotation(-lightRot*1.1).xform(vec3(0, 2, 0) + vec3(0, 0, 2) * lightDist);
		lights[2].position = quat.yRotation(-lightRot*1.22).xform(vec3(0, 4, 0) + vec3(0, 0, 2) * lightDist);

		static float lightScale = 1.0f;
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

		lights[0].lumIntens = vec4(1, 0.1, 0.01, 0) * lightScale;
		lights[1].lumIntens = vec4(0.1, 0.3, 1.0, 0) * lightScale;
		lights[2].lumIntens = vec4(0.3, 1.0, 0.6, 0) * lightScale;
		
		lights[0].radius = lightRad;
		lights[1].radius = lightRad;
		lights[2].radius = lightRad;

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

		static bool wantPost = false;

		static bool prevKeyDown = false;
		bool keyDown = keyboard.keyDown(KeySym.space);
		if (keyDown && !prevKeyDown) {
			wantPost ^= true;
		}
		prevKeyDown = keyDown;

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


void main(cstring[] args) {
	(new TestApp).run;
}
