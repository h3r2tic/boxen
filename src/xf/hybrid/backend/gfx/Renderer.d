module xf.hybrid.backend.gfx.Renderer;

private {
	import xf.Common;
	
	import xf.hybrid.GuiRenderer : BaseRenderer = GuiRenderer;
	import xf.hybrid.FontRenderer;
	import xf.hybrid.Font;
	import xf.hybrid.Texture;
	import xf.hybrid.IconCache;
	import xf.hybrid.Shape;
	import xf.hybrid.Style;
	import xf.hybrid.Context;		// for the vfs
	
	import xf.img.Image;
	import xf.img.Loader : ImageLoader = Loader;
	import xf.img.CachedLoader;

	// TODO: use xf.Registry
	import xf.img.FreeImageLoader;

	import xf.hybrid.Math;
	import xf.utils.Memory;
	import xf.mem.MainHeap;

	interface Gfx {
		import xf.gfx.IRenderer;
		import xf.gfx.Texture;
		import xf.gfx.Effect;
		import xf.gfx.Buffer;
		import xf.gfx.VertexBuffer;
		import xf.gfx.IndexData;
		
		interface EffectHelper {
			import xf.gfx.EffectHelper;
		}
	}
}



// version = StubHybridRenderer;

class Renderer : BaseRenderer, FontRenderer, TextureMngr {
	this (Gfx.IRenderer backend) {
		assert (backend !is null);
		_r = backend;
		_loadEffect();
		_iconCache = new IconCache;
		_iconCache.texMngr = this;
		FontMngr.fontRenderer = this;
		_imageLoader = new CachedLoader(new FreeImageLoader);

		{
			const whiteW = 3;
			const whiteH = 3;
			
			vec2i bl, tr;
			vec2 tbl, ttr;
			_whiteTex = cast(GfxTexture)_iconCache.get(
					vec2i(whiteW, whiteH), bl, tr, tbl, ttr
			);
			
			assert (_whiteTex !is null);
			_whiteTexCoord = (tbl + ttr) * 0.5f;

			ubyte[whiteW*whiteH*4] whiteData = 0xff;

			updateTexture(_whiteTex, bl, vec2i(whiteW, whiteH), whiteData.ptr);
		}
	}

	
	struct Vertex {
		vec2 position;
		vec4 color;
		vec2 texCoord;
	}


	struct Batch {
		enum Type {
			Triangles = 0,
			Lines = 1,
			Points = 2,
			Direct = 3
		}
		
		Type type;
		
		union {
			struct {
				Vertex*	verts;
				size_t	numVerts;
				
				VertexCache*	_vcache;

				GfxTexture			tex;
				Gfx.VertexBuffer	vb;
				Gfx.EffectInstance	efInst;
				
				BlendingMode	blending;
				float			weight;
			}
			
			struct {
				void delegate(BaseRenderer)	directRenderingHandler;
				Rect						originalRect;
			}
		}
		
		Rect clipRect;
	}

	static class GfxTexture : Texture {
		Gfx.Texture tex;
	}


	// implements FontRenderer
	Rect getClipRect() {
		return super.getClipRect();
	}
	
	
	override void applyStyle(Object s_) {
		if (s_ is null) {
			_style = null;
			return;
		}
		
		auto s = cast(Style)s_;
		assert (s !is null);
		
		_style = s;
	
		preprocessStyle();
	}
	
	
	protected void preprocessStyle() {
		if (_style.image.available) {
			auto img = _style.image.value();
			assert (img !is null);
			
			if (img.texture is null) {
				vec2i bl, tr;
				ImageRequest request;
				request.colorLayout = Image.ColorLayout.RGBA;
				request.dataType = Image.DataType.U8;
				
				assert (img.path.length > 0);
				assert (_imageLoader !is null);
				
				_imageLoader.useVfs(gui.vfs);
				auto raw = _imageLoader.load(img.path, &request);

				assert (raw.valid);	// TODO: error handling
				assert (Image.ColorLayout.RGBA == raw.colorLayout);
				img.size = vec2i(raw.width, raw.height);
				assert (iconCache !is null);
				
				img.texture = iconCache.get(
					img.size,
					bl,
					tr,
					img.texCoords[0],
					img.texCoords[1]
				);
				
				iconCache.updateTexture(
					img.texture,
					bl,
					img.size,
					(cast(ubyte[])raw.data).ptr
				);
			}
		}
	}
	
	
	override void shape(Shape shape, vec2 size) {
		version (StubHybridRenderer) return;
		if (cast(Rectangle)shape) {
			this.rect(shape.rect(size));
		}
	}


	override void	point(vec2 p, float size = 1.f) {
		version (StubHybridRenderer) return;
		_weight = size;
		
		auto b = prepareBatch(Batch.Type.Points, 1);
		size_t vn = b.numVerts;
		b.verts[vn].position = p + _offset;
		b.verts[vn].color = _color;
		b.verts[vn].texCoord = _texCoord;
		++vn;
		b.numVerts = vn;
	}
	
	
	override void	line(vec2 p0, vec2 p1, float width = 1.f) {
		version (StubHybridRenderer) return;
		_weight = width;

		auto b = prepareBatch(Batch.Type.Lines, 2);
		size_t vn = b.numVerts;
		b.verts[vn].position = p0 + _offset + _lineOffset;
		b.verts[vn].color = _color;
		b.verts[vn].texCoord = _texCoord;
		++vn;

		b.verts[vn].position = p1 + _offset + _lineOffset;
		b.verts[vn].color = _color;
		b.verts[vn].texCoord = _texCoord;
		++vn;
		
		b.numVerts = vn;
	}
	
	
	override void	rect(Rect r) {
		version (StubHybridRenderer) return;

		vec2[4] p = void;
		p[0] = vec2(r.min.x, r.min.y) + _offset;
		p[1] = vec2(r.min.x, r.max.y) + _offset;
		p[2] = vec2(r.max.x, r.max.y) + _offset;
		p[3] = vec2(r.max.x, r.min.y) + _offset;
		
		
		if (_style is null) {
			auto b = prepareBatch(Batch.Type.Triangles, 6);
			
			size_t vn = b.numVerts;
			void add(int i) {
				b.verts[vn].position = p[i];
				b.verts[vn].color = _color;
				b.verts[vn].texCoord = _texCoord;
				++vn;
			}
			
			add(0); add(1); add(2);
			add(0); add(2); add(3);
			
			b.numVerts = vn;
			
			return;
		}
		
		
		if (_style.background.available) {
			auto background = _style.background.value();
			assert (background !is null);

			vec4[4] c = void;
			vec2[4] tc = _texCoord;
			
			switch (background.type) {
				case BackgroundStyle.Type.Gradient: {
					auto g = &background.Gradient;
					switch (g.type) {
						case GradientStyle.Type.Horizontal: {
							c[0] = c[1] = g.color0;
							c[2] = c[3] = g.color1;
						} break;

						case GradientStyle.Type.Vertical: {
							c[0] = c[3] = g.color0;
							c[1] = c[2] = g.color1;
						} break;

						default: assert (false);
					}
				} break;
				
				case BackgroundStyle.Type.Solid: {
					c[] = background.Solid;
				} break;
				
				default: assert (false, "TODO");
			}
			
			if (_style.image.available) {
				auto img = _style.image.value();
				assert (img !is null);

				_texture = cast(GfxTexture)img.texture;
				
				vec2 tbl = img.texCoords[0];
				vec2 ttr = img.texCoords[1];
				
				tc[0] = vec2(tbl.x, ttr.y);
				tc[1] = vec2(tbl.x, tbl.y);
				tc[2] = vec2(ttr.x, tbl.y);
				tc[3] = vec2(ttr.x, ttr.y);
			}

			if (!_style.image.available || ushort.max == _style.image.value.hlines[0] || ushort.max == _style.image.value.vlines[0]) {
				auto b = prepareBatch(Batch.Type.Triangles, 6);

				size_t vn = b.numVerts;
				void add2(int i) {
					b.verts[vn].position = p[i];
					b.verts[vn].color = c[i];
					b.verts[vn].texCoord = tc[i];
					++vn;
				}
				
				add2(0); add2(1); add2(2);
				add2(0); add2(2); add2(3);
				
				b.numVerts = vn;
			} else {
				auto b = prepareBatch(Batch.Type.Triangles, 6*3*3);

				size_t vn = b.numVerts;
				void addInterp(float u, float v, float tu, float tv) {
					b.verts[vn].position = (p[0] * (1.f - v) + p[1] * v) * (1.f - u) + (p[2] * v + p[3] * (1.f - v)) * u;
					b.verts[vn].color = (c[0] * (1.f - v) + c[1] * v) * (1.f - u) + (c[2] * v + c[3] * (1.f - v)) * u;
					b.verts[vn].texCoord = (tc[0] * (1.f - tv) + tc[1] * tv) * (1.f - tu) + (tc[2] * tv + tc[3] * (1.f - tv)) * tu;
					++vn;
				}
				
				auto img = _style.image.value();
				assert (img !is null);
				
				float lineU[4];
				float lineV[4];
				
				float lineTU[4];
				float lineTV[4];

				lineTU[0] = lineTV[0] = lineU[0] = lineV[0] = 0.f;
				lineTU[3] = lineTV[3] = lineU[3] = lineV[3] = 1.f;
				
				lineTU[1] = cast(float)img.hlines[0] / img.size.x;
				lineTU[2] = cast(float)img.hlines[1] / img.size.x;
				lineTV[1] = cast(float)img.vlines[0] / img.size.y;
				lineTV[2] = cast(float)img.vlines[1] / img.size.y;
				
				lineU[1] = cast(float)img.hlines[0] / r.width;
				lineU[2] = 1.f - lineU[1];

				lineV[1] = cast(float)img.vlines[0] / r.height;
				lineV[2] = 1.f - lineV[1];

				void addIdxPt(int xi, int yi) {
					addInterp(lineU[xi], lineV[yi], lineTU[xi], lineTV[yi]);
				}
				
				void addQuad(int xi, int yi) {
					addIdxPt(xi, yi); addIdxPt(xi, yi+1); addIdxPt(xi+1, yi+1);
					addIdxPt(xi, yi); addIdxPt(xi+1, yi+1); addIdxPt(xi+1, yi);
				}
				
				for (int y = 0; y < 3; ++y) {
					for (int x = 0; x < 3; ++x) {
						addQuad(x, y);
					}
				}
				
				b.numVerts = vn;
			}
		}
		
		if (_style.border.available) {
			vec2[4] bp = void;
			bp[0] = vec2(r.min.x, r.min.y) + _offset;
			bp[1] = vec2(r.min.x, r.max.y-1) + _offset;
			bp[2] = vec2(r.max.x-1, r.max.y-1) + _offset;
			bp[3] = vec2(r.max.x-1, r.min.y) + _offset;

			auto border = _style.border.value();
			
			_weight = border.width;
			disableTexturing();
			auto b = prepareBatch(Batch.Type.Lines, 8);
			
			size_t vn = b.numVerts;
			void add3(int i) {
				b.verts[vn].position = bp[i] + _lineOffset;
				b.verts[vn].color = border.color;
				b.verts[vn].texCoord = _texCoord;
				++vn;
			}
			
			add3(0); add3(1);
			add3(1); add3(2);
			add3(2); add3(3);
			add3(3); add3(0);
			
			b.numVerts = vn;
		}
	}
	
	
	override void flushStyleSettings() {
		disableTexturing();
		if (_style !is null && _style.color.available) {
			color = *_style.color.value;
		} else {
			color = vec4.one;
		}
		blendingMode = BlendingMode.None;
	}
	
	
	override bool special(Object obj) {
		return false;
	}
	
	
	override void direct(void delegate(BaseRenderer) dg, Rect rect) {
		assert (false, "TODO");
		/+version (StubHybridRenderer) return;
		assert (dg !is null);
		auto b = prepareBatch(Batch.Type.Direct, 0);
		b.directRenderingHandler = dg;
		b.originalRect = rect;+/
	}


	override void flush() {
		assert (_r !is null);

		assert (getClipRect() != Rect.init, "Renderer.getClipRect returned Rect.init; make sure to call renderer.setClipRect() before rendering the GUI");

		_flushBatchData();
		
		scope (exit) {
			_numBatches = 0;
			_numVertexCaches = 0;
		}
		
		_glClipRect = Rect(vec2.zero, vec2.zero);

		final renderList = _r.createRenderList();
		assert (renderList !is null);
		scope (success) _r.disposeRenderList(renderList);

		// TODO: set whatnot for effect instances

		final state = _r.state();
		state.blend.enabled = true;
		state.blend.src = Gfx.RenderState.Blend.Factor.Src1Color;
		state.blend.dst = Gfx.RenderState.Blend.Factor.OneMinusSrc1Color;
		
		final bin = renderList.getBin(_effect);
		
		for (int i = 0; i < _numBatches; ++i) {
			auto b = &_batches[i];

			if (Batch.Type.Direct == b.type) {
				handleDirectRendering(*b);
				continue;
			}

			if (!setupClipping(b.clipRect)) {
				continue;
			}

			switch (b.type) {
				case Batch.Type.Lines: {
					state.line.width = b.weight;
				} break;

				case Batch.Type.Points: {
					state.point.size = b.weight;
				} break;
				
				default: break;
			}

			final rdata = bin.add(b.efInst);
			rdata.coordSys = rdata.coordSys.identity;
			rdata.scale = vec3.one;
			rdata.indexData.numIndices = b.numVerts;
			rdata.indexData.indexOffset =
					cast(Vertex*)b.verts - cast(Vertex*)b._vcache.ptr;
			
			switch (b.type) {
				case Batch.Type.Triangles: {
					rdata.indexData.topology = Gfx.MeshTopology.Triangles;
				} break;
					
				case Batch.Type.Lines: {
					rdata.indexData.topology = Gfx.MeshTopology.Lines;
				} break;
				
				case Batch.Type.Points: {
					rdata.indexData.topology = Gfx.MeshTopology.Points;
				} break;
				
				case Batch.Type.Direct: {
					assert (false, "Direct rendering should be handled elsewhere");
				}
				
				default: assert (false);
			}

			rdata.numInstances = 1;
			rdata.flags = rdata.flags.NoIndices;
		}

		_r.render(renderList);
	}
	
	
	private void handleDirectRendering(Batch b) {
		/+version (StubHybridRenderer) return;
		if (!setupClipping(b.clipRect)) {
			return;
		}
		
		auto r = b.originalRect;
		int w = cast(int)(r.max.x - r.min.x);
		int h = cast(int)(r.max.y - r.min.y);

		gl.Viewport(cast(int)r.min.x, cast(int)(_viewportSize.y - r.min.y - h), w, h);
		
		assert (Batch.Type.Direct == b.type);
		assert (b.directRenderingHandler !is null);
		b.directRenderingHandler(this);+/
	}


	override void disableTexturing() {
		_texture = _whiteTex;
		_texCoord = _whiteTexCoord;
	}
	
	
	private Batch* addBatch(Batch b, VertexCache* vcache) {
		Batch* res;
		
		if (_batches.length > _numBatches) {
			res = &_batches[_numBatches++];
			b.efInst = res.efInst;
			*res = b;
		} else {
			_batches ~= b;
			res = &_batches[$-1];
			++_numBatches;
			res.efInst = _r.instantiateEffect(_effect);
		}
		
		res._vcache = vcache;
		
		if (vcache) {
			res.verts = cast(Vertex*)vcache.ptr + vcache.length;

			with (*res.efInst.getVaryingParamData("VertexProgram.input.position")) {
				buffer = &vcache.vb;
				attrib = &_posVAttr;
			}

			with (*res.efInst.getVaryingParamData("VertexProgram.input.color")) {
				buffer = &vcache.vb;
				attrib = &_colorVAttr;
			}

			with (*res.efInst.getVaryingParamData("VertexProgram.input.texCoord")) {
				buffer = &vcache.vb;
				attrib = &_tcVAttr;
			}
		}
		
		return res;
	}
	
	
	private Batch* prepareBatch(Batch.Type type, size_t numVerts) {
		version (StubHybridRenderer) {
			assert (false);		// should not be called in this version
		} else {
			auto vcache = Batch.Type.Direct == type
				? null
				: getVertexCache(numVerts);
			
			if (0 == _numBatches || Batch.Type.Direct == type) {
				addBatch(Batch(type), vcache);
			} else {
				auto b = &_batches[_numBatches-1];
				if (	b.type == type &&
						b.tex is _texture &&
						b.blending == _blending &&
						b.weight == _weight &&
						b.clipRect == _clipRect &&
						b._vcache == cast(void*)vcache
				) {
					vcache.length += numVerts;
					return b;
				} else {
					addBatch(Batch(type), vcache);
				}
			}
			
			auto b = &_batches[_numBatches-1];

			if (Batch.Type.Direct != type) {
				vcache.length += numVerts;
				b.tex = _texture;
				b.blending = _blending;
				b.weight = _weight;
			}
			
			b.clipRect = _clipRect;
			
			return b;
		}
	}

	
	// ----------------------------------------------------------------------------------------------------
	// TextureMngr

	Texture createTexture(vec2i size, vec4 defColor) {
		final res = new GfxTexture;
		Gfx.TextureRequest req;
		req.internalFormat = Gfx.TextureInternalFormat.SRGB8_ALPHA8;
		req.minFilter = Gfx.TextureMinFilter.Linear;
		req.magFilter = Gfx.TextureMagFilter.Linear;
		res.tex = _r.createTexture(size, req, (vec3) { return defColor; });
		return res;
	}
	
	
	void updateTexture(Texture tex_, vec2i origin, vec2i size, ubyte* data) {
		assert (size.x > 0 && size.y > 0);

		final tex = cast(GfxTexture)(tex_);
		assert (tex !is null);

		_r.updateTexture(tex.tex, origin, size, data);
	}

	// ----------------------------------------------------------------------------------------------------
	// FontRenderer

	void enableTexturing(Texture tex) {
		assert (cast(GfxTexture)tex !is null);
		_texture = cast(GfxTexture)tex;
	}
	
	
	void blendingMode(BlendingMode mode) {
		_blending = mode;
	}
	
	
	void color(vec4 col) {
		_color = col;
	}
	
	
	void absoluteQuad(vec2[] points, vec2[] texCoords) {
		version (StubHybridRenderer) return;
		auto b = prepareBatch(Batch.Type.Triangles, 6);
		size_t vn = b.numVerts;
		const tris = [
			[ 0, 1, 2 ],
			[ 0, 2, 3 ]
		];

		foreach (tri; tris) {
			foreach (i; tri) {
				b.verts[vn].position = points[i];
				b.verts[vn].color = _color;
				b.verts[vn].texCoord = texCoords[i];
				++vn;
			}
		}
		
		b.numVerts = vn;
	}
	
	
	IconCache iconCache() {
		return _iconCache;
	}
	
	// ----------------------------------------------------------------------------------------------------


	private bool setupClipping(Rect r, bool setupProjection = true) {
		if (_glClipRect == r) {
			return _clipRectOk;
		} else {
			_glClipRect = r;
		}

		Rect c = _glClipRect;
		
		if (c == Rect.init) {
			c.min = vec2(0, 0);
			c.max = vec2(_viewportSize.x, _viewportSize.y);
		} else {
			c.min = vec2.from(vec2i.from(c.min));
			c.max = vec2.from(vec2i.from(c.max));
		}
		
		c = Rect.intersection(c, Rect(vec2.zero, vec2.from(_viewportSize)));
		
		int w = cast(int)(c.max.x - c.min.x);
		int h = cast(int)(c.max.y - c.min.y);
		
		if (w <= 0 || h <= 0) {
			_clipRectOk = false;
			return false;
		} else {
			_clipRectOk = true;
		}

		final state = _r.state();
		
		with (state.scissor) {
			enabled = true;
			x = cast(int)c.min.x;
			y = cast(int)(_viewportSize.y - c.min.y - h);
			width = w;
			height = h;
		}

		with (state.viewport) {
			x = cast(int)c.min.x;
			y = cast(int)(_viewportSize.y - c.min.y - h);
			width = w;
			height = h;
		}

		if (setupProjection) {
			mat4 worldToClip = mat4.ortho(
				c.min.x, c.max.x, c.max.y, c.min.y, 0, 1
			);
			
			_effect.setUniform("worldToClip", worldToClip);
		}
		
		return true;
	}

	

	struct VertexCache {
		// 64k vertices should be enough for anyone :P
		const capacity = 64 * 1024;
		
		Gfx.VertexBuffer	vb;
		ubyte*				ptr;
		uword				length;
	}

	VertexCache[]	_vertexCaches;
	uword			_numVertexCaches;

	Gfx.VertexAttrib	_posVAttr;
	Gfx.VertexAttrib	_colorVAttr;
	Gfx.VertexAttrib	_tcVAttr;
	

	VertexCache* getVertexCache(uword verts) {
		// TODO: err
		assert (verts <= VertexCache.capacity, `Too many vertices requested :<`);
		
		if (_numVertexCaches > 0) {
			auto vc = &_vertexCaches[_numVertexCaches-1];
			if (vc.length + verts < vc.capacity) {
				return vc;
			}
		}
		
		if (_numVertexCaches < _vertexCaches.length) {
			++_numVertexCaches;
			auto vc = &_vertexCaches[_numVertexCaches-1];
			vc.length = 0;
			return vc;
		}
		
		assert (_numVertexCaches == _vertexCaches.length);
		++_numVertexCaches;
		_vertexCaches ~= VertexCache();
		auto vc = &_vertexCaches[$-1];
		_allocVertexCache(vc);
		return vc;
	}


	private void _allocVertexCache(VertexCache* vc) {
		uword bytes = Vertex.sizeof * VertexCache.capacity;
		vc.ptr = cast(ubyte*)mainHeap.allocRaw(bytes);
		vc.vb = _r.createVertexBuffer(
			Gfx.BufferUsage.StaticDraw,
			vc.ptr[0..bytes]
		);
		vc.length = 0;
	}


	private void _flushBatchData() {
		foreach (ref b; _vertexCaches[0.._numVertexCaches]) {
			b.vb.setSubData(0, (cast(Vertex*)b.ptr)[0..b.length]);
		}

		// Data could have been re-assigned
		foreach (b; _batches[0.._numBatches]) {
			final texIdx = b.efInst.getUniformParamGroup().getUniformIndex(
				"FragmentProgram.tex"
			);

			assert (texIdx != -1);
			b.efInst.getUniformPtrsDataPtr()[texIdx] = &b.tex.tex;

			b.vb = b._vcache.vb;
		}
	}


	private void _loadEffect() {
		// TODO: configuration
		_effect = _r.createEffect(
			"HybridGUI",
			Gfx.EffectSource.filePath("HybridGUI.cgfx")
		);
		_effect.compile();
		Gfx.EffectHelper.allocateDefaultUniformStorage(_effect);

		_posVAttr = Gfx.VertexAttrib(
			Vertex.init.position.offsetof,
			Vertex.sizeof,
			Gfx.VertexAttrib.Type.Vec2
		);

		_colorVAttr = Gfx.VertexAttrib(
			Vertex.init.color.offsetof,
			Vertex.sizeof,
			Gfx.VertexAttrib.Type.Vec4
		);

		_tcVAttr = Gfx.VertexAttrib(
			Vertex.init.texCoord.offsetof,
			Vertex.sizeof,
			Gfx.VertexAttrib.Type.Vec2
		);
	}


	vec2i viewportSize() {
		return _viewportSize;
	}

	void viewportSize(vec2i s) {
		_viewportSize = s;
	}	
	
	
	private {
		vec4			_color = vec4.one;
		vec2			_texCoord = vec2.zero;
		GfxTexture		_texture;
		BlendingMode	_blending;
		float			_weight = 1.0;

		vec2i			_viewportSize;
		
		Batch[]			_batches;
		uint			_numBatches;
		ImageLoader		_imageLoader;

		Gfx.IRenderer	_r;
		Gfx.Effect		_effect;

		IconCache		_iconCache;
		GfxTexture		_whiteTex;
		vec2			_whiteTexCoord;
		
		Style			_style;
		Rect			_glClipRect;
		bool			_clipRectOk = true;

		static vec2		_lineOffset = {x: .5f, y: .5f};
	}
}
