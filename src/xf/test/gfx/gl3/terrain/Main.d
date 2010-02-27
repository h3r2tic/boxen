module Main;

version (StackTracing) import tango.core.tools.TraceExceptions;

import
	xf.Common,
	xf.utils.GfxApp,
	xf.utils.SimpleCamera,
	
	xf.img.FreeImageLoader,
	
	xf.omg.core.LinearAlgebra,
	xf.utils.Memory;
	
import xf.terrain.HeightmapChunkLoader;
import xf.terrain.ChunkedTerrain;
import xf.terrain.ChunkData;
import xf.terrain.ChunkLoader;
import xf.terrain.Chunk;



void main() {
	(new TestApp).run;
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
			assert (indices.length > 0 && indices.length % 3 == 0);
			
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
	SimpleCamera		camera;
	
	const int			chunkSize = 64;
	Effect				terrainEffect;
	ChunkedTerrain		terrain;
	MyChunkHandler		chunkData;
	Texture				albedo, lightmap, detail;
	
	
	override void configureWindow(Window wnd) {
		super.configureWindow(wnd);
		wnd.title = "Terrain rendering demo";
		wnd.interceptCursor = true;
		wnd.showCursor = false;
	}
	
	
	override void initialize() {
		version (Demo) {
			const cstring mediaDir = `media/`;
		} else {
			const cstring mediaDir = `../../../media/`;
		}

		auto ldr = new HeightmapChunkLoader;
		ldr.load(mediaDir ~ "terrain/height.png", chunkSize);
		terrain = new ChunkedTerrain(ldr);
		chunkData = new MyChunkHandler;
		terrain.addChunkHandler(chunkData);
		terrain.scale = vec3(100.f, 30.f, 100.f);

		camera = new SimpleCamera(vec3.zero, 0.0f, 0.0f, inputHub.mainChannel);
		
		scope imgLoader = new FreeImageLoader;

		Texture loadTex(cstring path) {
			return renderer.createTexture(
				imgLoader.load(path)
			);
		}

		albedo = loadTex(mediaDir ~ "terrain/albedo.png");
		lightmap = loadTex(mediaDir ~ "terrain/light.png");
		
		TextureRequest req;
		req.internalFormat = TextureInternalFormat.RGBA8;
		detail = renderer.createTexture(
			imgLoader.load(mediaDir ~ "terrain/detail.jpg"),
			req
		);
		
		terrainEffect = renderer.createEffect(
			"terrain",
			EffectSource.filePath("terrain.cgfx")
		);
		
		terrainEffect.useGeometryProgram = false;
		terrainEffect.compile();
		chunkData.effect = terrainEffect;
		chunkData.renderer = renderer;
		
		mat4 viewToClip = mat4.perspective(
			65.0f,		// fov
			cast(float)window.width / window.height,	// aspect
			0.1f,		// near
			100.0f		// far
		);


		terrainEffect.setUniform("viewToClip", viewToClip);
	}
	
	
	override void render() {
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

		terrainEffect.setUniform("worldToView",
			camera.getMatrix
		);
		
		renderList.sort();
		renderer.framebuffer.settings.clearColorValue[0] = vec4(0.1, 0.2, 0.4, 1.0);
		renderer.clearBuffers();
		renderer.render(renderList);
	}
}
