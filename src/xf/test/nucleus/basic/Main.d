module Main;

private {
	import tango.core.tools.TraceExceptions;
	
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
	import xf.nucleus.Kernel;
	import xf.nucleus.CompiledMeshAsset;
	import xf.nucleus.KernelParamInterface;

	import xf.nucleus.kdef.model.IKDefRegistry;
	import xf.nucleus.kernel.KernelDef;
	import tango.io.vfs.FileFolder;
	import xf.mem.ChunkQueue;

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

	vec3	position = { x: 0, y: 1, z: 2 };
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


class TestApp : GfxApp {
	alias renderer rendererBackend;
	Renderer nr;
	VSDRoot vsd;
	SimpleCamera	camera;

	TestLight[]		lights;

	IKDefRegistry	kdefRegistry;
	ScratchFIFO		mem;
	FileFolder		vfs;

	override void initialize() {
		mem.initialize();

		void* delegate(size_t) allocator = &mem.pushBack;
		final vfs = new FileFolder(".");

		kdefRegistry = create!(IKDefRegistry)();
		kdefRegistry.setVFS(vfs);
		kdefRegistry.registerFolder("../../media/kdef", allocator);
		kdefRegistry.registerFolder(".", allocator);
		kdefRegistry.doSemantics(allocator);
		kdefRegistry.dumpInfo();

		// ----

		nr = Nucleus.createRenderer("Forward", rendererBackend, kdefRegistry);

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

		cstring path = `../../media/mesh/masha.hsf`;
		path = Path.normalize(path);
		
		scope loader = new HsfLoader;
		loader.load(path);
		
		final scene = loader.scene;
		assert (scene !is null);
		assert (loader.meshes.length > 0);
		
		assert (1 == scene.nodes.length);
		final root = scene.nodes[0];

		const numLights = 3;
		for (int i = 0; i < numLights; ++i) {
			createLight((lights ~= new TestLight)[$-1]);
		}

		void iterAssetMeshes(void delegate(int, ref LoaderMesh) dg) {
			foreach (i, ref m; loader.meshes) {
				dg(i, m);
			}
		}
		
		iterAssetMeshes((int, ref LoaderMesh m) {
			// This should be a part of the content pipeline

			MeshAssetCompilationOptions opts;
			opts.scale = 0.02f;

			final compiledMesh = compileMeshAsset(m, opts);
			
			final ms = mallocObject!(MeshStructure);
			ms._ctor(compiledMesh, rendererBackend);

			final rid = createRenderable();	
			renderables.structureKernel[rid] = defaultStructureKernel(ms.structureTypeName);
			renderables.structureData[rid] = ms;
			renderables.pigmentKernel[rid] = "TestPigment";
			renderables.pigmentData[rid] = null;	// TODO
			renderables.illumKernel[rid] = "CookTorrance";
			renderables.transform[rid] = CoordSys.identity;
			renderables.localHalfSize[rid] = compiledMesh.halfSize;
		});
	}


	override void render() {
		static float lightRot = 0.0f;
		lightRot += 0.1f;
		
		lights[0].position = quat.yRotation(lightRot).xform(vec3(0, 1, -2));
		lights[1].position = quat.yRotation(-lightRot*1.1).xform(vec3(0, 2, 2));
		lights[2].position = quat.yRotation(-lightRot*1.22).xform(vec3(0, 4, 1));

		lights[0].lumIntens = vec4(1, 0.1, 0.01, 0);
		lights[1].lumIntens = vec4(0.1, 0.3, 1.0, 0);
		lights[2].lumIntens = vec4(0.3, 1.0, 0.6, 0);
		
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

		rendererBackend.resetStats();
		rendererBackend.framebuffer.settings.clearColorValue[0] = vec4.one * 0.1f;
		rendererBackend.clearBuffers();

		nr.render(viewSettings, rlist);
	}
}


void main(cstring[] args) {
	(new TestApp).run;
}
