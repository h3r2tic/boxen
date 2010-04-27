module xf.hybrid.backend.gl.Renderer;

/+private {
	import xf.hybrid.GuiRenderer : BaseRenderer = GuiRenderer;
	import xf.hybrid.FontRenderer;
	import xf.hybrid.Font;
	import xf.hybrid.Texture;
	import xf.hybrid.IconCache;
	import xf.hybrid.Shape;
	import xf.hybrid.Style;
	import xf.hybrid.widgets.Label;
	import xf.hybrid.WidgetConfig;
	import xf.hybrid.Context;
	
	import xf.image.Loader : ImageRequest, ImageFormat, ImageLoader = Loader;
	import xf.image.DevilLoader;
	import xf.image.CachedLoader;
	
	import xf.hybrid.Math;
	import xf.utils.Memory;
	
	import xf.dog.Dog;
	
	import tango.util.log.Trace;
}



// version = StubHybridRenderer;

//private {
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
				void*				_vcache;
				vec2*				points;
				vec4*				colors;
				vec3*				alphaColors;
				vec2*				texCoords;
				size_t				numVerts;
				
				Texture				texture;
				BlendingMode	blending;
				float					weight;
			}
			
			struct {
				void delegate(BaseRenderer)	directRenderingHandler;
				Rect										originalRect;
			}
		}
		
		Rect clipRect;
	}

	class GlTexture : Texture {
		int id;
	}
	
	static const uint[] batchToGlType = [GL_TRIANGLES, GL_QUADS, GL_LINES, GL_POINTS];
//}



class Renderer : BaseRenderer, FontRenderer, TextureMngr {
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
				request.imageFormat = ImageFormat.RGBA;
				assert (img.path.length > 0);
				assert (imageLoader !is null);
				
				imageLoader.useVfs(gui.vfs);
				auto raw = imageLoader.load(img.path, &request);
				
				assert (raw !is null, img.path);
				assert (1 == raw.planes.length);
				assert (ImageFormat.RGBA == raw.imageFormat);
				auto plane = raw.planes[0];
				img.size = vec2i(plane.width, plane.height);
				assert (iconCache !is null);
				img.texture = iconCache.get(img.size, bl, tr, img.texCoords[0], img.texCoords[1]);
				iconCache.updateTexture(img.texture, bl, img.size, (cast(ubyte[])plane.data).ptr);
			}
		}
	}
	
	
	override void shape(Shape shape, vec2 size) {
		version (StubHybridRenderer) return;
		if (cast(Rectangle)shape) {
			this.rect(shape.rect(size));
			/+gl.immediate(GL_LINE_LOOP, {
				gl.Color3f(1.f, 1.f, 1.f);
				gl.Vertex2f(_offset.x, _offset.y);
				gl.Vertex2f(_offset.x, _offset.y+size.y);
				gl.Vertex2f(_offset.x+size.x, _offset.y+size.y);
				gl.Vertex2f(_offset.x+size.x, _offset.y);
			});+/
		}
	}


	override void	point(vec2 p, float size = 1.f) {
		version (StubHybridRenderer) return;
		_weight = size;
		//flushStyleSettings();
		
		auto b = prepareBatch(Batch.Type.Points, 1);
		size_t vn = b.numVerts;
		b.points[vn] = p + _offset;
		b.colors[vn] = _color;
		b.texCoords[vn] = _texCoord;
		++vn;
		b.numVerts = vn;
	}
	
	
	override void	line(vec2 p0, vec2 p1, float width = 1.f) {
		version (StubHybridRenderer) return;
		_weight = width;
		//flushStyleSettings();

		auto b = prepareBatch(Batch.Type.Lines, 2);
		size_t vn = b.numVerts;
		b.points[vn] = p0 + _offset + lineOffset;
		b.colors[vn] = _color;
		b.texCoords[vn] = _texCoord;
		++vn;

		b.points[vn] = p1 + _offset + lineOffset;
		b.colors[vn] = _color;
		b.texCoords[vn] = _texCoord;
		++vn;
		
		b.numVerts = vn;
	}
	
	
	override void	rect(Rect r) {
		version (StubHybridRenderer) return;
		//flushStyleSettings();

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
				b.points[vn] = bp[i] + lineOffset;
				b.colors[vn] = border.color;
				b.texCoords[vn] = _texCoord;
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
	
	
	override bool	special(Object obj) {
		return false;
	}
	
	
	override void direct(void delegate(BaseRenderer) dg, Rect rect) {
		version (StubHybridRenderer) return;
		assert (dg !is null);
		auto b = prepareBatch(Batch.Type.Direct, 0);
		b.directRenderingHandler = dg;
		b.originalRect = rect;
	}


	override void flush() {
		assert (gl !is null);

		assert (getClipRect() != Rect.init, "Renderer.getClipRect returned Rect.init; make sure to call renderer.setClipRect() before rendering the GUI");
		
		scope (exit) {
			_numBatches = 0;
			_numVertexCaches = 0;
		}
		
		_glClipRect = Rect(vec2.zero, vec2.zero);
		
		for (int i = 0; i < _numBatches; ++i) {
			auto b = &batches[i];
		//foreach (ref b; batches) {
			if (Batch.Type.Direct == b.type) {
				handleDirectRendering(*b);
				continue;
			}

			if (!setupClipping(b.clipRect)) {
				continue;
			}
			
			if (b.texture !is null) {
				gl.Enable(GL_TEXTURE_2D);
				gl.BindTexture(GL_TEXTURE_2D, (cast(GlTexture)b.texture).id);
			} else {
				gl.Disable(GL_TEXTURE_2D);
			}

			if (BlendingMode.Subpixel == b.blending) {
				gl.BlendFunc(GL_ZERO, GL_ONE_MINUS_SRC_COLOR);
				gl.Enable(GL_BLEND);

				gl.TexCoordPointer(2, GL_FLOAT, 0, b.texCoords);
				gl.VertexPointer(2, GL_FLOAT, 0, b.points);
				gl.ColorPointer(3, GL_FLOAT, 0, b.alphaColors);
				
				gl.EnableClientState(GL_TEXTURE_COORD_ARRAY);
				gl.EnableClientState(GL_VERTEX_ARRAY);
				gl.EnableClientState(GL_COLOR_ARRAY);
				
				gl.DrawArrays(batchToGlType[b.type], 0, b.numVerts);

				gl.DisableClientState(GL_TEXTURE_COORD_ARRAY);
				gl.DisableClientState(GL_VERTEX_ARRAY);
				gl.DisableClientState(GL_COLOR_ARRAY);
			}
			
			switch (b.blending) {
				case BlendingMode.Alpha: {
					gl.BlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
					gl.Enable(GL_BLEND);
				} break;

				case BlendingMode.Subpixel: {
					gl.BlendFunc(GL_SRC_ALPHA, GL_ONE);
				} break;

				case BlendingMode.None: {
					//gl.Disable(GL_BLEND);
					gl.BlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
					gl.Enable(GL_BLEND);
				} break;
			}

			gl.TexCoordPointer(2, GL_FLOAT, 0, b.texCoords);
			gl.VertexPointer(2, GL_FLOAT, 0, b.points);
			gl.ColorPointer(4, GL_FLOAT, 0, b.colors);
			
			gl.EnableClientState(GL_TEXTURE_COORD_ARRAY);
			gl.EnableClientState(GL_VERTEX_ARRAY);
			gl.EnableClientState(GL_COLOR_ARRAY);
			
			switch (b.type) {
				case Batch.Type.Lines: {
					gl.LineWidth(b.weight);
				} break;

				case Batch.Type.Points: {
					gl.PointSize(b.weight);
				} break;
				
				default: break;
			}

			gl.DrawArrays(batchToGlType[b.type], 0, b.numVerts);

			gl.DisableClientState(GL_TEXTURE_COORD_ARRAY);
			gl.DisableClientState(GL_VERTEX_ARRAY);
			gl.DisableClientState(GL_COLOR_ARRAY);
		}
	}
	
	
	protected void handleDirectRendering(Batch b) {
		version (StubHybridRenderer) return;
		if (!setupClipping(b.clipRect)) {
			return;
		}
		
		auto r = b.originalRect;
		int w = cast(int)(r.max.x - r.min.x);
		int h = cast(int)(r.max.y - r.min.y);

		gl.Viewport(cast(int)r.min.x, cast(int)(viewportSize.y - r.min.y - h), w, h);
		
		assert (Batch.Type.Direct == b.type);
		assert (b.directRenderingHandler !is null);
		b.directRenderingHandler(this);
	}


	void disableTexturing() {
		_texture = null;
	}
	
	
	Batch* addBatch(Batch b, VertexCache* vcache) {
		Batch* res;
		
		if (batches.length > _numBatches) {
			res = &batches[_numBatches++];
			*res = b;
		} else {
			batches ~= b;
			res = &batches[$-1];
			++_numBatches;
		}
		
		res.numVerts = 0;
		res._vcache = vcache;
		
		if (vcache) {
			res.points = vcache.points + vcache.length;
			res.colors = vcache.colors + vcache.length;
			res.alphaColors = vcache.alphaColors + vcache.length;
			res.texCoords = vcache.texCoords + vcache.length;
		}
		
		return res;
	}
	
	
	Batch* prepareBatch(Batch.Type type, size_t numVerts) {
		version (StubHybridRenderer) assert (false);		// should not be called in this version
		
		auto vcache = Batch.Type.Direct == type ? null : getVertexCache(numVerts);
		
		if (0 == _numBatches || Batch.Type.Direct == type) {
			addBatch(Batch(type), vcache);
		} else {
			auto b = &batches[_numBatches-1];
			if (	b.type == type &&
					b.texture is _texture &&
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
		
		auto b = &batches[_numBatches-1];

		if (Batch.Type.Direct != type) {
			vcache.length += numVerts;
			b.texture = _texture;
			b.blending = _blending;
			b.weight = _weight;
		}
		
		b.clipRect = _clipRect;
		
		return b;
	}

	
	// ----------------------------------------------------------------------------------------------------
	// TextureMngr

	Texture createTexture(vec2i size, vec4 defColor) {
		Trace.formatln("Creating a texture of size: {}", size);
		
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
		
		return tex;
	}
	
	
	void updateTexture(Texture tex_, vec2i origin, vec2i size, ubyte* data) {
		assert (size.x > 0 && size.y > 0);
		
		GlTexture tex = cast(GlTexture)(tex_);
		assert (tex !is null);
		
		gl.Enable(GL_TEXTURE_2D);
		gl.BindTexture(GL_TEXTURE_2D, tex.id);
		
		const int level = 0;
		gl.TexSubImage2D(GL_TEXTURE_2D, level, origin.x, origin.y, size.x, size.y, GL_RGBA, GL_UNSIGNED_BYTE, data);
		
		gl.Disable(GL_TEXTURE_2D);
	}


	// ----------------------------------------------------------------------------------------------------
	// FontRenderer

	void enableTexturing(Texture tex) {
		_texture = tex;
	}
	
	
	void blendingMode(BlendingMode mode) {
		_blending = mode;
	}
	
	
	void color(vec4 col) {
		_color = col;
	}
	
	
	void absoluteQuad(vec2[] points, vec2[] texCoords) {
		version (StubHybridRenderer) return;
		auto b = prepareBatch(Batch.Type.Quads, 4);
		size_t vn = b.numVerts;
		b.points[vn..vn+4] = points;
		b.colors[vn..vn+4] = _color;
		b.texCoords[vn..vn+4] = texCoords;

		if (BlendingMode.Subpixel == _blending) {
			b.alphaColors[vn..vn+4] = vec3.one * _color.a;
		}

		vn += 4;
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
			c.max = vec2(viewportSize.x, viewportSize.y);
		} else {
			c.min = vec2.from(vec2i.from(c.min));
			c.max = vec2.from(vec2i.from(c.max));
		}
		
		c = Rect.intersection(c, Rect(vec2.zero, vec2.from(viewportSize)));
		
		int w = cast(int)(c.max.x - c.min.x);
		int h = cast(int)(c.max.y - c.min.y);
		
		if (w <= 0 || h <= 0) {
			_clipRectOk = false;
			return false;
		} else {
			_clipRectOk = true;
		}
		
		gl.Viewport(cast(int)c.min.x, cast(int)(viewportSize.y - c.min.y - h), w, h);
		gl.Scissor(cast(int)c.min.x, cast(int)(viewportSize.y - c.min.y - h), w, h);
		gl.Enable(GL_SCISSOR_TEST);

		
		if (setupProjection) {
			gl.MatrixMode(GL_PROJECTION);
			gl.LoadIdentity();
			gl.gluOrtho2D(c.min.x, c.max.x, c.max.y, c.min.y);
			gl.MatrixMode(GL_MODELVIEW);
			gl.LoadIdentity();
		}
		
		return true;
	}

	
	this() {
		_iconCache = new IconCache;
		_iconCache.texMngr = this;
		FontMngr.fontRenderer = this;
		imageLoader = new CachedLoader(new DevilLoader);
	}
	
	
	struct VertexCache {
		vec2*	points;
		vec4*	colors;
		vec3*	alphaColors;
		vec2*	texCoords;
		size_t	length;
		
		void allocate() {
			points = cast(vec2*)tango.stdc.stdlib.malloc(vec2.sizeof * allocSize);
			colors = cast(vec4*)tango.stdc.stdlib.malloc(vec4.sizeof * allocSize);
			alphaColors = cast(vec3*)tango.stdc.stdlib.malloc(vec3.sizeof * allocSize);
			texCoords = cast(vec2*)tango.stdc.stdlib.malloc(vec2.sizeof * allocSize);
			length = 0;
		}
		
		const size_t allocSize = 1024 * 64;
		
		// otherwise the point-by-point quad adding will not work
		static assert (allocSize % 4 == 0);
	}
	
	VertexCache[]	_vertexCaches;
	size_t				_numVertexCaches;
	
	
	VertexCache* getVertexCache(size_t verts) {
		assert (verts <= VertexCache.allocSize, `too many vertices requested`);

		if (_numVertexCaches > 0) {
			auto vc = &_vertexCaches[_numVertexCaches-1];
			if (vc.length + verts < vc.allocSize) {
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
		vc.allocate();
		return vc;
	}
	
	
	public {
		GL		gl;
		vec2i	viewportSize;
	}
	
	protected {
		Batch[]			batches;
		uint				_numBatches;
		ImageLoader	imageLoader;
	}
	
	private {
		IconCache			_iconCache;
		
		vec4					_color = vec4.one;
		vec2					_texCoord = vec2.zero;
		Texture				_texture;
		BlendingMode	_blending;
		float					_weight = 1.0;
		
		Style					_style;
		
		Rect					_glClipRect;
		bool					_clipRectOk = true;

		static vec2			lineOffset = {x: .5f, y: .5f};
	}
}
+/
