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
	import xf.hybrid.Log : log = hybridLog;
	
	import xf.img.Image;
	import xf.img.Loader : ImageLoader = Loader;
	import xf.img.CachedLoader;

	// TODO: use xf.Registry
	import xf.img.FreeImageLoader;

	import xf.hybrid.Math;
	import xf.utils.Memory;
	import xf.mem.MainHeap;
	import xf.mem.StackBuffer;

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
		vec2 subpixelSamplingVector;
	}


	struct Batch {
		enum Type {
			Triangles = 0,
			Lines = 1,
//			Points = 2,
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

	struct LineBrush {
		GfxTexture	tex;
		int			width;
		vec2		tc0;
		vec2		tc1;
		float		texelSize;
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
				assert (Image.ColorLayout.RGBA == raw.colorLayout, img.path);
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


	/+override void	point(vec2 p, float size = 1.f) {
		version (StubHybridRenderer) return;
		_weight = size;
		
		auto b = prepareBatch(Batch.Type.Points, 1);
		size_t vn = b.numVerts;
		b.verts[vn].position = p + _offset;
		b.verts[vn].color = _color;
		b.verts[vn].texCoord = _texCoord;
		b.verts[vn].subpixelSamplingVector = _subpixelSamplingVector;
		++vn;
		b.numVerts = vn;
	}+/


	private LineBrush* _getLineBrush(int w) {
		foreach (ref br; _lineBrushes) {
			if (br.width == w) {
				return &br;
			}
		}

		final br = &(_lineBrushes ~= LineBrush())[$-1];
		br.width = w;

		enum { borderWidth = 2 }
		static assert (borderWidth >= 1);
		
		uword texWidth = w + borderWidth * 2;

		scope stack = new StackBuffer;
		vec4ub[] tex = stack.allocArray!(vec4ub)(texWidth);
		tex[] = vec4ub.zero;
		tex[borderWidth .. borderWidth+w] = vec4ub(255, 255, 255, 255);

		vec2i bl, tr;
		vec2 tbl, ttr;
		br.tex = cast(GfxTexture)_iconCache.get(vec2i(texWidth, 1), bl, tr, tbl, ttr, vec2i.zero);
		
		// copy our bitmap into the texture
		_iconCache.updateTexture(br.tex, bl, vec2i(texWidth, 1), cast(ubyte*)tex.ptr);

		final float texel = (ttr.x - tbl.x) / (tr.x - bl.x);
		final float ctexel = texel * (borderWidth + 0.5f * w) + tbl.x;
		final float numSkip = (1.f + (w - 1.f) / 2);

		float y = (ttr.y + tbl.y) * 0.5f;
		
		br.tc0 = vec2(ctexel - texel * numSkip, y);
		br.tc1 = vec2(ctexel + texel * numSkip, y);

		br.texelSize = texel;

		return br;
	}


	override void	triangles(vec2[] pts, vec4[] colors) {
		assert (0 == pts.length % 3);
		disableTexturing();

		auto b = prepareBatch(Batch.Type.Triangles, pts.length);
		size_t vn = b.numVerts;

		foreach (i, ref p; pts) {
			b.verts[vn].position = p + _offset;
			b.verts[vn].color = colors[i];
			b.verts[vn].texCoord = _texCoord;
			b.verts[vn].subpixelSamplingVector = _subpixelSamplingVector;
			++vn;
		}

		b.numVerts = vn;
	}
	
	
	override void	lines(vec2[] pts, float width = 1.f) {
		assert (0 == pts.length % 2);

		version (StubHybridRenderer) return;
		_weight = width;

		int lwidth = max(0, rndint(width));
		final brush = _getLineBrush(lwidth);
		enableTexturing(brush.tex);

		auto b = prepareBatch(Batch.Type.Triangles, pts.length * 3);	// 2 tris per segment
		size_t vn = b.numVerts;

		final tc0 = brush.tc0;
		final tc1 = brush.tc1;

		for (int i = 0; i < pts.length; i += 2) {
			vec2 from = pts[i] + _offset;
			vec2 to = pts[i+1] + _offset;

			vec2 fwd = (to - from).normalized;
			vec2 sideUnit = fwd.rotatedHalfPi;
			vec2 side = sideUnit * (lwidth * 0.5f + 0.5f);

			vec2 p0 = from - side;
			vec2 p1 = to - side;
			vec2 p2 = to + side;
			vec2 p3 = from + side;

			// Our lines are different than the ones in OpenGL.
			// The ones in GL have their endpoints in the top-left corners of pixels,
			// which causes odd-width lines to look blurry. We'd like to have sharp
			// 1-width lines, thus we reverse this behavior and have blurry even-width lines.
			// Additionally, our lines are expanded by a pixel in each end to be endpoint-inclusive.
			{
				p0.x += 0.5f;
				p0.y += 0.5f;
				p1.x += 0.5f;
				p1.y += 0.5f;
				p2.x += 0.5f;
				p2.y += 0.5f;
				p3.x += 0.5f;
				p3.y += 0.5f;

				vec2 fwdNudge = fwd * .5f;
				p0 -= fwdNudge;
				p1 += fwdNudge;
				p2 += fwdNudge;
				p3 -= fwdNudge;
			}

			void add(vec2 p, vec2 t) {
				b.verts[vn].position = p;
				b.verts[vn].color = _color;
				b.verts[vn].texCoord = t;
				b.verts[vn].subpixelSamplingVector = vec2(side.x * brush.texelSize * (-1.0f / 3.0f), 0);
				++vn;
			}

			add(p0, tc1);
			add(p1, tc1);
			add(p2, tc0);

			add(p0, tc1);
			add(p2, tc0);
			add(p3, tc0);
		}

		b.numVerts = vn;
	}
	

	override void	line(vec2 pts[], float width = 1.f) {
		assert (pts.length >= 2);

		version (StubHybridRenderer) return;
		_weight = width;

		int lwidth = max(0, rndint(width));
		final brush = _getLineBrush(lwidth);
		enableTexturing(brush.tex);

		auto b = prepareBatch(Batch.Type.Triangles, (pts.length-1) * 6);	// 2 tris per segment
		size_t vn = b.numVerts;

		final tc0 = brush.tc0;
		final tc1 = brush.tc1;

		for (int i = 0; i+1 < pts.length; ++i) {
			vec2 from = pts[i] + _offset;
			vec2 to = pts[i+1] + _offset;

			vec2 p0 = from;
			vec2 p1 = to;
			vec2 p2 = to;
			vec2 p3 = from;

			vec2 side = (to - from).normalized.rotatedHalfPi * (lwidth * 0.5f + 0.5f);

			vec2 fwd0, fwd1, fwd2;
			
			if (i > 0) {
				fwd0 = (pts[i] - pts[i-1]).normalized;
			}
			
			fwd1 = (pts[i+1] - pts[i]).normalized;
			
			if (i+2 < pts.length) {
				fwd2 = (pts[i+2] - pts[i+1]).normalized;
			}

			vec2 side1, side2;

			if (i > 0) {
				vec2 side1Unit = (fwd0+fwd1).normalized.rotatedHalfPi;
				side1 = side1Unit * (lwidth * 0.5f + 0.5f);
			} else {
				side1 = side;
			}

			if (i+2 < pts.length) {
				vec2 side2Unit = (fwd1+fwd2).normalized.rotatedHalfPi;
				side2 = side2Unit * (lwidth * 0.5f + 0.5f);
			} else {
				side2 = side;
			}

			p0 -= side1;
			p3 += side1;

			p1 -= side2;
			p2 += side2;

			// Our lines are different than the ones in OpenGL.
			// The ones in GL have their endpoints in the top-left corners of pixels,
			// which causes odd-width lines to look blurry. We'd like to have sharp
			// 1-width lines, thus we reverse this behavior and have blurry even-width lines.
			// Additionally, our lines are expanded by a pixel in each end to be endpoint-inclusive.
			{
				p0.x += 0.5f;
				p0.y += 0.5f;
				p1.x += 0.5f;
				p1.y += 0.5f;
				p2.x += 0.5f;
				p2.y += 0.5f;
				p3.x += 0.5f;
				p3.y += 0.5f;

				if (i+2 >= pts.length) {
					vec2 fwd = (to - from).normalized;
					vec2 fwdNudge = fwd * .5f;
					
					p1 += fwdNudge;
					p2 += fwdNudge;
				}
				if (0 == i) {
					vec2 fwd = (to - from).normalized;
					vec2 fwdNudge = fwd * .5f;

					p0 -= fwdNudge;
					p3 -= fwdNudge;
				}
			}

			void add(vec2 p, vec2 t) {
				b.verts[vn].position = p;
				b.verts[vn].color = _color;
				b.verts[vn].texCoord = t;
				b.verts[vn].subpixelSamplingVector = vec2(side.x * brush.texelSize * (-1.0f / 3.0f), 0);
				++vn;
			}

			add(p0, tc1);
			add(p1, tc1);
			add(p2, tc0);

			add(p0, tc1);
			add(p2, tc0);
			add(p3, tc0);
		}

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
				b.verts[vn].subpixelSamplingVector = _subpixelSamplingVector;
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
					b.verts[vn].subpixelSamplingVector = _subpixelSamplingVector;
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
					b.verts[vn].subpixelSamplingVector = _subpixelSamplingVector;
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
			bp[0] = vec2(r.min.x, r.min.y);
			bp[1] = vec2(r.min.x, r.max.y-1);
			bp[2] = vec2(r.max.x-1, r.max.y-1);
			bp[3] = vec2(r.max.x-1, r.min.y);

			auto border = _style.border.value();
			
			_weight = border.width;
			//disableTexturing();

			vec2[8] pts = void;
			pts[0] = bp[0];
			pts[1] = bp[1];
			pts[2] = bp[1];
			pts[3] = bp[2];
			pts[4] = bp[2];
			pts[5] = bp[3];
			pts[6] = bp[3];
			pts[7] = bp[0];

			final colBK = _color;
			_color = border.color;
			lines(pts[], border.width);
			_color = colBK;

			/+auto b = prepareBatch(Batch.Type.Lines, 8);
			
			size_t vn = b.numVerts;
			void add3(int i) {
				b.verts[vn].position = bp[i] + _lineOffset;
				b.verts[vn].color = border.color;
				b.verts[vn].texCoord = _texCoord;
				b.verts[vn].subpixelSamplingVector = _subpixelSamplingVector;
				++vn;
			}
			
			add3(0); add3(1);
			add3(1); add3(2);
			add3(2); add3(3);
			add3(3); add3(0);
			
			b.numVerts = vn;+/
		}
	}
	
	
	override void flushStyleSettings() {
		disableTexturing();
		if (_style !is null && _style.color.available) {
			color = *_style.color.value;
		} else {
			color = vec4.one;
		}
	}
	
	
	override bool special(Object obj) {
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
		assert (_r !is null);

		assert (getClipRect() != Rect.init, "Renderer.getClipRect returned Rect.init; make sure to call renderer.setClipRect() before rendering the GUI");

		_flushBatchData();
		
		scope (exit) {
			_numBatches = 0;
			_numVertexCaches = 0;
		}
		
		_glClipRect = Rect(vec2.zero, vec2.zero);

		// TODO: set whatnot for effect instances

		final stateBk = *_r.state();
		scope (exit) *_r.state() = stateBk;
		
		final state = _r.state();
		state.blend.enabled = true;
		state.blend.src = Gfx.RenderState.Blend.Factor.One;
		state.blend.dst = Gfx.RenderState.Blend.Factor.OneMinusSrc1Color;
		state.depth.enabled = false;

		//log.trace("Renderer: numBatches: {}", _numBatches);
		
		for (int i = 0; i < _numBatches; ++i) {
			final renderList = _r.createRenderList();
			assert (renderList !is null);
			scope (success) _r.disposeRenderList(renderList);
			final bin = renderList.getBin(_effect);

			auto b = &_batches[i];

			if (Batch.Type.Direct == b.type) {
				handleDirectRendering(*b);
				continue;
			}

			if (!setupClipping(b.clipRect, b.clipRect)) {
				continue;
			}

			switch (b.type) {
				/+case Batch.Type.Points: {
					state.point.size = b.weight;
				} break;+/
				
				default: break;
			}

			final rdata = bin.add(b.efInst);
			rdata.coordSys = rdata.coordSys.identity;
			rdata.scale = vec3.one;
			rdata.indexData.numIndices = b.numVerts;
			
			rdata.indexData.indexOffset
				= cast(Vertex*)b.verts - cast(Vertex*)b._vcache.ptr;
			
			switch (b.type) {
				case Batch.Type.Triangles: {
					rdata.indexData.topology = Gfx.MeshTopology.Triangles;
				} break;
					
				case Batch.Type.Lines: {
					rdata.indexData.topology = Gfx.MeshTopology.Lines;
				} break;
				
				/+case Batch.Type.Points: {
					rdata.indexData.topology = Gfx.MeshTopology.Points;
				} break;+/
				
				case Batch.Type.Direct: {
					assert (false, "Direct rendering should be handled elsewhere");
				}
				
				default: assert (false);
			}

			rdata.numInstances = 1;
			rdata.flags = rdata.flags.NoIndices;

			_r.render(renderList);
		}
	}
	
	
	private void handleDirectRendering(Batch b) {
		version (StubHybridRenderer) return;

		final origState = *_r.state();
		scope (exit) *_r.state() = origState;

		_r.resetState();

		if (!setupClipping(b.clipRect, b.originalRect)) {
			return;
		}
		
		/+auto r = b.originalRect;
		int w = cast(int)(r.max.x - r.min.x);
		int h = cast(int)(r.max.y - r.min.y);+/

		//gl.Viewport(cast(int)r.min.x, cast(int)(_viewportSize.y - r.min.y - h), w, h);
		
		assert (Batch.Type.Direct == b.type);
		assert (b.directRenderingHandler !is null);
		b.directRenderingHandler(this);
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

			with (*res.efInst.getVaryingParamData("VertexProgram.input.subpixelSamplingVector")) {
				buffer = &vcache.vb;
				attrib = &_spsvVAttr;
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
						//b.blending == _blending &&
						//b.weight == _weight &&
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
				//b.blending = _blending;
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
				b.verts[vn].subpixelSamplingVector = _subpixelSamplingVector;
				++vn;
			}
		}
		
		b.numVerts = vn;
	}
	
	
	IconCache iconCache() {
		return _iconCache;
	}
	
	// ----------------------------------------------------------------------------------------------------


	private bool setupClipping(Rect r, Rect origR, bool setupProjection = true) {
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
			x = cast(int)origR.min.x;
			y = cast(int)(_viewportSize.y - origR.max.y);
			width = cast(int)(origR.max.x - origR.min.x);
			height = cast(int)(origR.max.y - origR.min.y);
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
	Gfx.VertexAttrib	_spsvVAttr;
	

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
			if (b.type != Batch.Type.Direct) {
				final texIdx = b.efInst.getUniformParamGroup().getUniformIndex(
					"FragmentProgram.tex"
				);

				assert (texIdx != -1);
				b.efInst.getUniformPtrsDataPtr()[texIdx] = &b.tex.tex;

				b.vb = b._vcache.vb;
			}
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

		_spsvVAttr = Gfx.VertexAttrib(
			Vertex.init.subpixelSamplingVector.offsetof,
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


	// implements FontRenderer
	void subpixelSamplingVector(vec2 v) {
		_subpixelSamplingVector = v;
	}

	
	
	private {
		vec4			_color = vec4.one;
		vec2			_texCoord = vec2.zero;
		GfxTexture		_texture;
		float			_weight = 1.0;
		vec2			_subpixelSamplingVector = vec2.zero;

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

		LineBrush[]		_lineBrushes;

		static vec2		_lineOffset = {x: .5f, y: .5f};
	}
}
