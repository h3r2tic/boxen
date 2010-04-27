module xf.hybrid.backend.gl.Renderer;

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
	}
}



// version = StubHybridRenderer;

class Renderer : BaseRenderer, FontRenderer, TextureMngr {
	struct Vertex {
		vec2 position;
		vec4 color;
		vec2 texCoord;
	}


	struct Batch {
		enum Type {
			Triangles = 0,
			Quads = 1,
			Lines = 2,
			Points = 3,
			Direct = 4
		}
		
		Type type;
		
		union {
			struct {
				Vertex*	verts;
				size_t	numVerts;
				
				VertexCache*	_vcache;
				
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


	private Rect getClipRect() {
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
		/+version (StubHybridRenderer) return;
		_weight = size;
		
		auto b = prepareBatch(Batch.Type.Points, 1);
		size_t vn = b.numVerts;
		b.points[vn] = p + _offset;
		b.colors[vn] = _color;
		b.texCoords[vn] = _texCoord;
		++vn;
		b.numVerts = vn;+/
	}
	
	
	override void	line(vec2 p0, vec2 p1, float width = 1.f) {
		/+version (StubHybridRenderer) return;
		_weight = width;

		auto b = prepareBatch(Batch.Type.Lines, 2);
		size_t vn = b.numVerts;
		b.points[vn] = p0 + _offset + _lineOffset;
		b.colors[vn] = _color;
		b.texCoords[vn] = _texCoord;
		++vn;

		b.points[vn] = p1 + _offset + _lineOffset;
		b.colors[vn] = _color;
		b.texCoords[vn] = _texCoord;
		++vn;
		
		b.numVerts = vn;+/
	}
	
	
	override void	rect(Rect r) {
		/+version (StubHybridRenderer) return;

		vec2[4] p = void;
		p[0] = vec2(r.min.x, r.min.y) + _offset;
		p[1] = vec2(r.min.x, r.max.y) + _offset;
		p[2] = vec2(r.max.x, r.max.y) + _offset;
		p[3] = vec2(r.max.x, r.min.y) + _offset;
		
		
		if (_style is null) {
			auto b = prepareBatch(Batch.Type.Triangles, 6);
			
			size_t vn = b.numVerts;
			void add(int i) {
				b.points[vn] = p[i];
				b.colors[vn] = _color;
				b.texCoords[vn] = _texCoord;
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

				_texture = img.texture;
				
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
					b.points[vn] = p[i];
					b.colors[vn] = c[i];
					b.texCoords[vn] = tc[i];
					++vn;
				}
				
				add2(0); add2(1); add2(2);
				add2(0); add2(2); add2(3);
				
				b.numVerts = vn;
			} else {
				auto b = prepareBatch(Batch.Type.Triangles, 6*3*3);

				size_t vn = b.numVerts;
				void addInterp(float u, float v, float tu, float tv) {
					b.points[vn] = (p[0] * (1.f - v) + p[1] * v) * (1.f - u) + (p[2] * v + p[3] * (1.f - v)) * u;
					b.colors[vn] = (c[0] * (1.f - v) + c[1] * v) * (1.f - u) + (c[2] * v + c[3] * (1.f - v)) * u;
					b.texCoords[vn] = (tc[0] * (1.f - tv) + tc[1] * tv) * (1.f - tu) + (tc[2] * tv + tc[3] * (1.f - tv)) * tu;
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
				b.points[vn] = bp[i] + _lineOffset;
				b.colors[vn] = border.color;
				b.texCoords[vn] = _texCoord;
				++vn;
			}
			
			add3(0); add3(1);
			add3(1); add3(2);
			add3(2); add3(3);
			add3(3); add3(0);
			
			b.numVerts = vn;
		}+/
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

		// TODO: set textures and whatnot for effect instances
		// TODO: vertex attribs for effect instances

		final state = _r.state();
		state.blend.enabled = true;
		state.blend.src = Gfx.RenderState.Blend.Factor.Src1Color;
		state.blend.dst = Gfx.RenderState.Blend.Factor.OneMinusSrc1Color;
		
		for (int i = 0; i < _numBatches; ++i) {
			auto b = &_batches[i];

			if (Batch.Type.Direct == b.type) {
				handleDirectRendering(*b);
				continue;
			}

			if (!setupClipping(b.clipRect)) {
				continue;
			}

			// TODO
			/+switch (b.type) {
				case Batch.Type.Lines: {
					gl.LineWidth(b.weight);
				} break;

				case Batch.Type.Points: {
					gl.PointSize(b.weight);
				} break;
				
				default: break;
			}+/

			// TODO: add to the render list
//			gl.DrawArrays(batchToGlType[b.type], 0, b.numVerts);
		}
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
		assert (false, "use a white texture instead");
		//_texture = null;
	}
	
	
	private Batch* addBatch(Batch b, VertexCache* vcache) {
		Batch* res;
		
		if (_batches.length > _numBatches) {
			res = &_batches[_numBatches++];
			*res = b;
		} else {
			_batches ~= b;
			res = &_batches[$-1];
			++_numBatches;
		}
		
		res.numVerts = 0;
		res._vcache = vcache;
		
		if (vcache) {
			res.verts = cast(Vertex*)vcache.ptr + vcache.length;
		}
		
		return res;
	}
	
	
	private Batch* prepareBatch(Batch.Type type, size_t numVerts) {
		version (StubHybridRenderer) {
			assert (false);		// should not be called in this version
		} else {
			auto vcache = Batch.Type.Direct == type ? null : getVertexCache(numVerts);
			
			if (0 == _numBatches || Batch.Type.Direct == type) {
				addBatch(Batch(type), vcache);
			} else {
				auto b = &_batches[_numBatches-1];
				if (	b.type == type &&
						b._vcache.tex is _texture &&
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
				b._vcache.tex = _texture;
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
		assert (false, "TODO");
		
		/+Trace.formatln("Creating a texture of size: {}", size);
		
		ubyte[] data;
		data.alloc(size.x * size.y * 4);

		uint bitspp = 32;
		uint bytespp = bitspp / 8;
		
		ubyte f2ub(float f) {
			if (f < 0) return 0;
			if (f > 1) return 255;
			return cast(ubyte)rndint(f * 255);
		}

		for (uint i = 0; i < size.x; ++i) {
			for (uint j = 0; j < size.y; ++j) {			
				for (uint c = 0; c < bytespp; ++c) {
					data[(size.x * j + i) * bytespp + c] = f2ub(defColor.cell[c]);
				}
			}
		}
		
		GlTexture tex = new GlTexture;
		gl.GenTextures(1, cast(uint*)&tex.id);
		
		gl.Enable(GL_TEXTURE_2D);
		gl.BindTexture(GL_TEXTURE_2D, tex.id);
				
		const uint level = 0;
		const uint border = 0;
		GLenum format	= GL_RGBA;
		
		gl.TexImage2D(GL_TEXTURE_2D, level, bytespp, size.x, size.y, border, format, GL_UNSIGNED_BYTE, data.ptr);
		gl.TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER,	GL_LINEAR);
		gl.TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER,	GL_LINEAR);

		gl.Disable(GL_TEXTURE_2D);
		data.free();

		Trace.formatln("Texture created");
		
		return tex;+/
	}
	
	
	void updateTexture(Texture tex_, vec2i origin, vec2i size, ubyte* data) {
		assert (false, "TODO");
		
		/+assert (size.x > 0 && size.y > 0);
		
		GlTexture tex = cast(GlTexture)(tex_);
		assert (tex !is null);
		
		gl.Enable(GL_TEXTURE_2D);
		gl.BindTexture(GL_TEXTURE_2D, tex.id);
		
		const int level = 0;
		gl.TexSubImage2D(GL_TEXTURE_2D, level, origin.x, origin.y, size.x, size.y, GL_RGBA, GL_UNSIGNED_BYTE, data);
		
		gl.Disable(GL_TEXTURE_2D);+/
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
		assert (false, "TODO");
		/+version (StubHybridRenderer) return;
		auto b = prepareBatch(Batch.Type.Quads, 4);
		size_t vn = b.numVerts;
		b.points[vn..vn+4] = points;
		b.colors[vn..vn+4] = _color;
		b.texCoords[vn..vn+4] = texCoords;

		if (BlendingMode.Subpixel == _blending) {
			b.alphaColors[vn..vn+4] = vec3.one * _color.a;
		}

		vn += 4;
		b.numVerts = vn;+/
	}
	
	
	IconCache iconCache() {
		return _iconCache;
	}
	
	// ----------------------------------------------------------------------------------------------------


	private bool setupClipping(Rect r, bool setupProjection = true) {
		/+if (_glClipRect == r) {
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
		
		gl.Viewport(cast(int)c.min.x, cast(int)(_viewportSize.y - c.min.y - h), w, h);
		gl.Scissor(cast(int)c.min.x, cast(int)(_viewportSize.y - c.min.y - h), w, h);
		gl.Enable(GL_SCISSOR_TEST);

		
		if (setupProjection) {
			gl.MatrixMode(GL_PROJECTION);
			gl.LoadIdentity();
			gl.gluOrtho2D(c.min.x, c.max.x, c.max.y, c.min.y);
			gl.MatrixMode(GL_MODELVIEW);
			gl.LoadIdentity();
		}
		
		return true;+/
		assert (false, "TODO");
	}

	
	this() {
		_iconCache = new IconCache;
		_iconCache.texMngr = this;
		FontMngr.fontRenderer = this;
		_imageLoader = new CachedLoader(new FreeImageLoader);
	}


	struct VertexCache {
		// 64k vertices should be enough for anyone :P
		const capacity = 64 * 1024;
		
		Gfx.VertexBuffer	vb;
		Gfx.EffectInstance	efInst;
		GfxTexture			tex;
		ubyte*				ptr;
		uword				length;
	}

	VertexCache[]	_vertexCaches;
	uword			_numVertexCaches;


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

		// TODO: effect instance, texture
	}


	private void _flushBatchData() {
		foreach (ref b; _vertexCaches[0.._numVertexCaches]) {
			b.vb.setSubData(0, (cast(Vertex*)b.ptr)[0..b.length]);
		}
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
		
		Style			_style;
		Rect			_glClipRect;
		bool			_clipRectOk = true;

		static vec2		_lineOffset = {x: .5f, y: .5f};
	}
}
