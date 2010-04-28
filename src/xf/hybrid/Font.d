module xf.hybrid.Font;

private {
	import xf.hybrid.FontRenderer;
	import xf.hybrid.IconCache;
	import xf.hybrid.Texture;
	import xf.hybrid.Context;
	import xf.hybrid.Rect;

	import xf.utils.Memory;
	import xf.mem.Array;
	
	import xf.hybrid.Math;
	
	import derelict.freetype.ft;
	import derelict.util.loader;
	import derelict.util.exception;

	import tango.math.Math : rndint;
}

version (X86_64) {
       static assert(FT_Generic .sizeof == 16);
       static assert(FT_BBox .sizeof == 32);
       static assert(FT_GlyphSlot .sizeof == 8);
       static assert(FT_Size .sizeof == 8);
       static assert(FT_CharMap .sizeof == 8);
       static assert(FT_Driver .sizeof == 8);
       static assert(FT_Memory .sizeof == 8);
       static assert(FT_Stream .sizeof == 8);
       static assert(FT_ListRec .sizeof == 16);
       static assert(FT_Face_Internal .sizeof == 8);
       static assert (FT_FaceRec.sizeof == 248);
}



/**
	Basic info a bout glyphs
*/
struct Glyph {
	vec2[2]		texCoords;
	Texture		texture;
	vec2i		size;			// size inside the texture, in pixels
	vec2i		offset;		// offset from the top-left corner of the pen to the glyph image
	vec2i		advance;	// tells us how much we should advance the pen after drawing this glyph
	uint		ftIndex;	// freetype's index of this glyph
	ubyte[]		buffer;
}


/**
	Thanks to this struct, we can map (name, size) tuples to Font objects
*/
struct FontKey {
	FontRenderer		renderer;
	char[]				faceName;
	int					size;
	
	hash_t toHash() {
		return size + typeid(char[]).getHash(&faceName) + cast(hash_t)cast(void*)renderer;
	}
	
	int opCmp(FontKey* rhs) {
		assert (rhs !is null);
		if (size > rhs.size) return 1;
		if (size < rhs.size) return -1;
		if (cast(void*)renderer > cast(void*)rhs.renderer) return 1;
		if (cast(void*)renderer < cast(void*)rhs.renderer) return -1;
		return typeid(char[]).compare(&faceName, &rhs.faceName);
	}
}


///
enum FontAntialiasing {
	None,			/// glyphs will be aliased
	Grayscale,		/// should be best for CRTs
	LCD_RGB,		/// optimal for most LCDs
	LCD_BGR		/// some LCDs may have BGR subpixel layouts
}


///
enum LCDFilter {
	Standard,		// this is standard FreeType's subpixel filter. Basically, a triangular kernel
	Crisp,			// this one is a compromise between the default lcd filter, no filter and non-lcd aliased renderings
	None				// doesn't do any subpixel filtering, will result in massive color fringes
}


/**
	Stores info about the loaded fonts and some freetype stuff
*/
class FontMngr {
	static Font[FontKey]	loadedFonts;
	static FontRenderer	fontRenderer;
	
	
	static FT_Library		ftLib;		/// freetype library handler
	
	
	protected static Font loadFont(char[] fontPath, int size) {
		if (ftLib is null) loadFtLib();
		
		Font newFont() {
			auto res = loadedFonts[FontKey(fontRenderer, fontPath, size)] = new Font(fontPath, size);
			loadedFonts.rehash;		// will speed-up AA lookups
			return res;
		}
		
		auto ptr = FontKey(fontRenderer, fontPath, size) in loadedFonts;
		if (ptr is null) return newFont();
		else return *ptr;
	}
	
	
	static void loadFtLib() {
		// sometimes the shared lib might be missing a function we don't use anyway. we don't want to crash in that case.
		Derelict_SetMissingProcCallback(function bool(char[] a, char[] b) { return true; });
			DerelictFT.load();		// load the FreeType dynamic library, freetype.dll/.so is required for application to run
		Derelict_SetMissingProcCallback(null);
		
		// just sanity checking
		assert (FT_Init_FreeType !is null);
		
		auto ftError = FT_Init_FreeType(&ftLib);  // initialize the freetype library
		assert (0 == ftError);
		assert (ftLib !is null);
	}

	
	// this object can't be instantiated manually
	private this() {}
	private ~this() {}
}


struct FontPrintCache {
	void resize(size_t s) {
		data.resize(s);
	}
	
	void invalidate() {
		valid = false;
	}
	
	private {
		struct Data {
			dchar	chr;
			uint	ftIndex;
			ushort	delta;
		}
		
		Array!(Data)	data;
		bool			valid = false;
	}
}


/**
	Handles layout, caching and rendering of glyphs and strings for a single typeface
*/
final class Font {
	/**
		This is how fonts should be loaded.
		
		Examples:
		---
			Font(`fonts/verdana.ttf`, 12).print(....);
		---
	*/
	static Font opCall(char[] fontPath, int size) {
		auto res = FontMngr.loadFont(fontPath, size);
		assert (res !is null);
		return res;
	}
	
	
	package this(char[] fontPath, int size) {
		{
			auto stream = gui.vfs.file(fontPath).input();
			scope (exit) stream.close();
			this.fontData = cast(ubyte[])stream.load();
		}
		//this.fontData = cast(ubyte[])File(fontPath).read;		// we'll store the data in a buffer, because FreeType doesn't copy it.
		
		FT_Open_Args args;
		args.memory_base = this.fontData.ptr;
		args.memory_size = this.fontData.length;
		args.flags = FT_OPEN_MEMORY | FT_OPEN_PARAMS;
		args.driver = null;
		
		// for debugging/testing/whatever reasons, we may want to see how the unpatented hinting behaves...
		version (UnpatentedHinting) {
			// ... if so, add the appropriate tag
			FT_Parameter[1] params;
			params[0].tag = FT_MAKE_TAG!('u', 'n', 'p', 'a');

			args.num_params = params.length;
			args.params = params.ptr;
		}
		
		const int faceIdx = 0;
		auto error = FT_Open_Face(FontMngr.ftLib, &args, faceIdx, &fontFace);
		if (error != 0) {
			throw new Exception("Could not load font file: '" ~ fontPath ~ "'");
		}
		
		// this could use a better approach, but it seems to work for all TrueType fonts I've tested so far
		error = FT_Set_Pixel_Sizes(fontFace, 0, size);
		assert (0 == error, "FT_Set_Pixel_Sizes failed");
		
		height_ = size;
		lineSkip_ = FT_MulFix(fontFace.height, fontFace.size.metrics.y_scale) / 64;
		lineGap = 0;
		ascent_ = fontFace.size.metrics.ascender / 64;
		descent_ = fontFace.size.metrics.descender / 64;
	}
	
	
	/**
		Yields the width of a string in pixels
	*/
	int width(stringT)(stringT str, FontPrintCache* fcache = null) {
		uint max;
		
		layoutText(str, (int charIndex, dchar c, vec2i pen, ref Glyph g) {
			max = pen.x + g.advance.x;
		}, fcache);
		
		return max;
	}
	
	
	/**
		Prints a string at a given position and color, using the current font renderer
	*/
	vec2i print(stringT)(vec2i location, stringT str, FontPrintCache* fcache = null) {
		print_(location, str, fcache);
		return location;
	}
	
	
	/**
		Font height as requested in the ctor hack (static opCall)
	*/
	int height() {
		return height_;
	}
	
	
	/**
		The distance between two consecutive horizontal lines of text using this font
	*/
	int lineSkip() {
		return lineSkip_ + lineGap_;
	}
	
	
	/**
	*/
	int ascent() {
		return ascent_;
	}
	

	/**
	*/
	int descent() {
		return descent_;
	}

	
	/**
		Write-only property, sets additional spacing between lines of text, as fractions of the font's height
	*/
	void lineGap(float frac) {
		lineGap_ = rndint(frac * height);
	}
	
	
	/**
		Useful when doing subpixel blending.
		
		Sending a quad with a different blending mode causes it to flush its buffers
	*/
	void flush() {
		auto r = FontMngr.fontRenderer;
		r.blendingMode = BlendingMode.None;

		vec2[4] points = vec2.zero;
		vec2[4] texCoords = vec2.zero;

		r.absoluteQuad(points, texCoords);
	}
	
	
	/**
		Sets the subpixel filter
	*/
	bool lcdFilter(LCDFilter f) {
		if (FT_Library_SetLcdFilter !is null) {
			switch (f) {
				case LCDFilter.Standard:
					FT_Library_SetLcdFilter(FontMngr.ftLib, FT_LcdFilter.FT_LCD_FILTER_DEFAULT);
					break;

				case LCDFilter.Crisp:
				case LCDFilter.None:
					FT_Library_SetLcdFilter(FontMngr.ftLib, FT_LcdFilter.FT_LCD_FILTER_NONE);
					break;

				default: assert (false);
			}
			
			lcdFilter_ = f;
			return true;
		} else {
			lcdFilter_ = LCDFilter.Standard;
			return false;
		}
	}
	

	private {
		/**
			Calls the supplied delegate over the provided text with a tuple of parameters: (int, dchar, vec2i, inout Glyph), meaning respectively:
			character index (i-th call gets the i-th index), the unicode character, pen position, glyph info
		*/
		void layoutText(stringT)(stringT text, void delegate(int, dchar, vec2i, ref Glyph) dg, FontPrintCache* fcache = null) {
			int	useKerning = FT_HAS_KERNING(fontFace);
			uint	previous = 0;	// the previous glyph index is needed for kerning
			int	penX = 0;
			int	cur = 0;			// the index for the first arg of 'dg'
			
			if (fcache) {
				if (fcache.valid) {
					foreach (i, c; fcache.data) {
						dchar chr = c.chr;
						uint glyphIndex = c.ftIndex;
						penX += c.delta >> 6;
						
						uint index = getGlyph(chr, glyphIndex);	// TODO: cache this?
						
						if (uint.max == index) {
							continue;		// we use uint.max as an invalid glyph. we don't want to crash on those, just skip 'em.
						}
						
						auto glyph = &glyphs[index];
						dg(i, chr, vec2i(penX, 0), *glyph);
						++cur;
						
						// move the pen and remember the previous glyph index for kerning
						penX += glyph.advance.x;
						previous = glyphIndex;
					}
				} else {
					// fcache invalid

					size_t strLen = 0;
					foreach (dchar chr; text) {
						++strLen;
					}
					fcache.resize(strLen);

					foreach (i, dchar chr; text) {
						uint glyphIndex = FT_Get_Char_Index(fontFace, chr);
						auto c = fcache.data[i];
						c.ftIndex = glyphIndex;
						c.chr = chr;
						
						if (useKerning && previous && glyphIndex) {
							// adjust the pen for kerning
							FT_Vector delta;
							FT_Get_Kerning(fontFace, previous, glyphIndex, FT_Kerning_Mode.FT_KERNING_DEFAULT, &delta);
							c.delta = delta.x;
							penX += delta.x >> 6;
						} else {
							fcache.data[i].delta = 0;
						}
						
						uint index = getGlyph(chr, glyphIndex);
						
						if (uint.max == index) {
							continue;		// we use uint.max as an invalid glyph. we don't want to crash on those, just skip 'em.
						}
						
						auto glyph = &glyphs[index];
						dg(i, chr, vec2i(penX, 0), *glyph);
						++cur;
						
						// move the pen and remember the previous glyph index for kerning
						penX += glyph.advance.x;
						previous = glyphIndex;
					}
					
					fcache.valid = true;
				}
			} else {
				foreach (i, dchar chr; text) {
					uint glyphIndex = FT_Get_Char_Index(fontFace, chr);
					
					if (useKerning && previous && glyphIndex) {
						// adjust the pen for kerning
						FT_Vector delta;
						FT_Get_Kerning(fontFace, previous, glyphIndex, FT_Kerning_Mode.FT_KERNING_DEFAULT, &delta);
						penX += delta.x >> 6;
					}
					
					uint index = getGlyph(chr, glyphIndex);
					
					if (uint.max == index) {
						continue;		// we use uint.max as an invalid glyph. we don't want to crash on those, just skip 'em.
					}
					
					auto glyph = &glyphs[index];
					dg(i, chr, vec2i(penX, 0), *glyph);
					++cur;
					
					// move the pen and remember the previous glyph index for kerning
					penX += glyph.advance.x;
					previous = glyphIndex;
				}
			}
		}


		/**
			Early-out info which might be used for not-so-dumb multi-line printing
		*/
		enum PrintResult {
			Ok,
			OutRight,
			OutLeft,
			OutDown,
			OutUp
		}
	
	
		// not the 'real' printing function, but we're close already
		PrintResult print_(stringT)(ref vec2i location, stringT str, FontPrintCache* fcache) {
			scope(success) location.y += this.lineSkip;
			// early-out tests
			
			auto r = FontMngr.fontRenderer;
			auto clipRect = r.getClipRect();
			assert (clipRect != Rect.init, "Renderer.getClipRect returned Rect.init; make sure to call renderer.setClipRect() before rendering the GUI");
			
			if (location.y >= clipRect.max.y) return PrintResult.OutDown;
			if (location.y + cast(int)height_ <= clipRect.min.y) return PrintResult.OutUp;
			if (location.x >= clipRect.max.x) return PrintResult.OutRight;
			
			// ok, look like we have to actually print the string
			return printWorker(location, str, fcache);
		}
		
		
		void uploadGlyph(ref Glyph g) {
			// tex coords; these will be set by the icon cache
			vec2i bl, tr;
			vec2 tbl, ttr;
			
			assert (FontMngr.fontRenderer !is null);
			assert (FontMngr.fontRenderer.iconCache !is null);
			Texture tex = FontMngr.fontRenderer.iconCache.get(g.size, bl, tr, tbl, ttr);
			
			// copy our bitmap into the texture
			FontMngr.fontRenderer.iconCache.updateTexture(tex, bl, g.size, g.buffer);

			// finish off the glyph struct
			g.texCoords[0] = tbl;
			g.texCoords[1] = ttr;
			g.texture = tex;
			
			.free(g.buffer);
			g.buffer = null;
		}
		
		
		// this function does the dirty job of submitting quads to the font renderer
		PrintResult printWorker(stringT)(vec2i location, stringT str, FontPrintCache* fcache) {
			if (0 == str.length) return PrintResult.Ok;
			location.y += this.height;
			
			assert (FontMngr.fontRenderer !is null);
			
			auto r = FontMngr.fontRenderer;
			r.blendingMode = BlendingMode.Subpixel;		// might be optimized for grayscale antialiasing or no antialiasing at all
			
			Rect clipRect = r.getClipRect();
			assert (clipRect != Rect.init, "Renderer.getClipRect returned Rect.init; make sure to call renderer.setClipRect() before rendering the GUI");
			
			layoutText(str, (int charIndex, dchar c, vec2i pen, ref Glyph g) {
				if (g.texture is null) {
					uploadGlyph(g);
				}
				
				pen.x += g.offset.x;
				pen.y -= g.offset.y;
				pen += location;
				
				if (pen.x <= clipRect.max.x && pen.x + g.size.x >= clipRect.min.x) {
					Texture curTex = g.texture;
					FontMngr.fontRenderer.enableTexturing(curTex);
					
					// adding 4 vertices will push a quad down the renderer
					
					vec2[4] points = void;
					vec2[4] texCoords = void;
					
					texCoords[0] = vec2(g.texCoords[0].x, g.texCoords[1].y);
					points[0] = vec2(pen.x, pen.y+g.size.y);

					texCoords[1] = g.texCoords[1];
					points[1] = vec2(pen.x + g.size.x, pen.y+g.size.y);

					texCoords[2] = vec2(g.texCoords[1].x, g.texCoords[0].y);
					points[2] = vec2(pen.x + g.size.x, pen.y);

					texCoords[3] = g.texCoords[0];
					points[3] = vec2(pen.x, pen.y);
					
					r.absoluteQuad(points, texCoords);
				}
			}, fcache);
			
			// this is a cheap operation it doesn't really change any GL state or whanot, just restores the 'normal' blending mode for
			// quads added next. remember that the *gui* renderer doesn't only deal with text.
			r.blendingMode = BlendingMode.Alpha;
			
			return PrintResult.Ok;
		}
		
		
		// given a dchar and freetype's glyph index, retrieve the index to our glyph array
		uint getGlyph(dchar c, uint ftIndex) {
			if (c < 128) {
				// fast path for ASCII
				uint mapped = asciiGlyphMap[c];
				if (uint.max == mapped) return cacheGlyph(c, ftIndex);
				else return mapped;
			} else {
				// AA for other Unicode chars
				uint* mapped = c in glyphMap;
				if (mapped is null) return cacheGlyph(c, ftIndex);
				else return *mapped;
			}
		}
		
		
		FT_Render_Mode renderMode() {
			switch (antialiasing) {
				case FontAntialiasing.None:			return FT_Render_Mode.FT_RENDER_MODE_MONO;
				case FontAntialiasing.Grayscale:	return FT_Render_Mode.FT_RENDER_MODE_NORMAL;
				case FontAntialiasing.LCD_RGB:	// fall through
				case FontAntialiasing.LCD_BGR:	return FT_Render_Mode.FT_RENDER_MODE_LCD;
				default: assert (false);
			}
		}
		
		
		/**
			Renders a glyph into the provided buffer
		*/
		vec2i renderGlyph(ref ubyte[] buffer, ref Glyph glyph, uint ftIndex) {
			lcdFilter = lcdFilter_;		// other fonts may use different filtering modes. tell FreeType we want our specified mode.
												// lcdFilter is a property that sets FreeType state.
			
			FT_GlyphSlot slot = fontFace.glyph;
			
			vec2i size;
			buffer[] = 0;
			
			// convert from FreeType's fixed point to int
			glyph.advance.x = fontFace.glyph.advance.x >> 6;
			glyph.advance.y = fontFace.glyph.advance.y >> 6;
			
			if (0 == FT_Render_Glyph(slot, renderMode)) {		// this gives us a bitmap
				auto bitmap = slot.bitmap;
				
				glyph.offset.x = slot.bitmap_left;
				glyph.offset.y = slot.bitmap_top;
				
				int glyphWidth = bitmap.width;
				switch (antialiasing) {
					case FontAntialiasing.None:			// fall through
					case FontAntialiasing.Grayscale:	break;
					
					// FreeType gives three times wider bitmaps for subpixel renderings
					case FontAntialiasing.LCD_RGB:	// fall through
					case FontAntialiasing.LCD_BGR:	glyphWidth /= 3; break;

					default: assert (false);
				}
				
				// we need to expand the bitmap horizontally to do our own filtering
				if (crispLCDFilter) {
					glyphWidth += 2;
					--glyph.offset.x;
				}
				
				glyph.size = size = vec2i(glyphWidth, bitmap.rows);
				
				// only realloc if the provided buffer can't hold the data
				int bytes = size.x * size.y * 4;
				if (buffer.length < bytes) buffer.realloc(bytes);
				
				// return 255 if the bit at (x,y) position is set. 0 otherwise.
				ubyte indexBinaryBitmap(FT_Bitmap bitmap, int x, int y) {
					ubyte buf = bitmap.buffer[y * bitmap.pitch + (x >> 3)];
					ubyte mask = cast(ubyte)(0b10000000 >> (x & 7));

					// DMD, you're a tard.
					return (buf & mask) != 0 ? cast(ubyte)255 : cast(ubyte)0;
				}
				
				for (int y = 0; y < size.y; ++y) {
					for (int x = 0; x < size.x; ++x) {
						uint bufferIdx = (y * size.x + x) * 4;
						
						// set the alpha channel of the img to white. We're using RGB as subpixel alpha anyway.
						buffer[bufferIdx+3] = 255;

						// index the bitmap given by freetype at (x*3+xoffset-3, y). 0 when out of bounds. useful for filtering
						ubyte ftBuffer(int xoffset) {
							xoffset += x*3;
							xoffset -= 3;
							if (xoffset < 0) return 0;
							if (xoffset >= bitmap.width) return 0;
							return bitmap.buffer[y * bitmap.pitch + xoffset];
						}

						switch (antialiasing) {
							case FontAntialiasing.None:
								buffer[bufferIdx..bufferIdx+3] = indexBinaryBitmap(bitmap, x, y);
								break;
							case FontAntialiasing.Grayscale:
								buffer[bufferIdx..bufferIdx+3] = bitmap.buffer[y * bitmap.pitch + x];
								
								// antialiasing makes the glyph appear darker...
								gammaCorrect(buffer[bufferIdx..bufferIdx+3], 1.2);
								break;
							case FontAntialiasing.LCD_RGB:
							case FontAntialiasing.LCD_BGR:
								if (crispLCDFilter) {
									foreach (i, ref c; buffer[bufferIdx..bufferIdx+3]) {
										c = crispFilter(ftBuffer(i-2), ftBuffer(i-1), ftBuffer(i), ftBuffer(i+1), ftBuffer(i+2));
									}
								} else {
									buffer[bufferIdx..bufferIdx+3] = bitmap.buffer[y * bitmap.pitch + x*3 .. y * bitmap.pitch + x*3 + 3];
									
									// antialiasing makes the glyph appear darker...
									gammaCorrect(buffer[bufferIdx..bufferIdx+3], 1.2);
								}
								
								// swap byte order for bgr subpixel layout
								if (FontAntialiasing.LCD_BGR == antialiasing) {
									ubyte r = buffer[bufferIdx];
									buffer[bufferIdx] = buffer[bufferIdx+2];
									buffer[bufferIdx+2] = r;
								}
								break;
							default: assert (false);
						}
					}
				}
				
				// the crisp filter requires a component of the mono-rendered glyph
				if (crispLCDFilter) {
					uint loadFlags = FT_LOAD_TARGET_(FT_Render_Mode.FT_RENDER_MODE_MONO);
					version (UnpatentedHinting) loadFlags |= FT_LOAD_FORCE_AUTOHINT;
					
					if (0 == FT_Load_Glyph(fontFace, ftIndex, loadFlags)) {
						FT_Glyph tmpGlyph;
						
						if (0 == FT_Get_Glyph(fontFace.glyph, &tmpGlyph) && 0 == FT_Render_Glyph(slot, FT_Render_Mode.FT_RENDER_MODE_MONO)) {
							for (int y = 0; y < size.y; ++y) {
								for (int x = 0; x < size.x; ++x) {
									uint bufferIdx = (y * size.x + x) * 4;
									
									ubyte monoColor =
										(x > 0 && x+1 < size.x)
										? indexBinaryBitmap(slot.bitmap, x-1, y)
										: cast(ubyte)0;		// DMDTARD
									
									foreach (ref c; buffer[bufferIdx..bufferIdx+3]) {
										c += monoColor / 4;
									}
									
									gammaCorrect(buffer[bufferIdx..bufferIdx+3], 1.1);
								}
							}
						}

						FT_Done_Glyph(tmpGlyph);
					}
				}
			}

			return size;
		}
		
		
		/**
			Creates a Glyph structure, renders the bitmap to a texture and returns an index into the glyph array
		*/
		uint cacheGlyph(dchar c, uint ftIndex) {
			uint index = uint.max;
			
			foreach (gi, gl; glyphs) {
				if (gl.ftIndex == ftIndex) {		// some fonts dont have lowecase glyphs, etc.
					index = gi;		// we can just skip the caching step and return an already cached glyph
					break;
				}
			}
			
			if (uint.max == index) {
				ubyte[] buffer;
				
				Glyph g;
				g.ftIndex = ftIndex;
				
				if (0 == ftIndex) {
					g.size = vec2i(height, height);
					g.offset = vec2i(0, height);
					g.advance = vec2i(height, 0);
					int bytes = g.size.x * g.size.y * 4;
					buffer.alloc(bytes);

					for (int y = 1; y+1 < g.size.y; ++y) {
						for (int x = 1; x+1 < g.size.x; ++x) {
							if (y != 1 && y+2 != g.size.y && x != 1 && x+2 != g.size.x &&
							(x < g.size.x / 3 || x > 2 * g.size.x / 3 || y < g.size.y / 3 || y > 2 * g.size.y / 3)) continue;
							int off = (y * g.size.x + x) * 4;
							buffer[off .. off+4] = 255;
						}
					}
				} else {
					FT_Glyph glyph;

					// ... usual FreeType stuff
					uint loadFlags = FT_LOAD_TARGET_(renderMode);
					version (UnpatentedHinting) loadFlags |= FT_LOAD_FORCE_AUTOHINT;

					if (0 != FT_Load_Glyph(fontFace, ftIndex, loadFlags)) return uint.max;
					if (0 != FT_Get_Glyph(fontFace.glyph, &glyph)) {
						FT_Done_Glyph(glyph);
						return uint.max;
					}
					
					renderGlyph(buffer, g, ftIndex);
					FT_Done_Glyph(glyph);
					
					// Let's try to cut on a few pixels. Sometimes FreeType reports a bit larger bitmap than what is really needed.
					{
						// is any of the subpixels at (x,y) non-zero ?
						bool any(int x, int y) {
							int off = (y * g.size.x + x) * 4;
							return buffer[off] != 0 || buffer[off+1] != 0 || buffer[off+2] != 0;
						}
						
						// compute the bounds of the rendered glyph
						int xmin = 0, xmax = g.size.x-1, ymin = 0, ymax = g.size.y-1;
						xloop1: for (; xmin < g.size.x; ++xmin) for (int y = 0; y < g.size.y; ++y) if (any(xmin, y)) break xloop1;
						yloop1: for (; ymin < g.size.y; ++ymin) for (int x = 0; x < g.size.x; ++x) if (any(x, ymin)) break yloop1;
						xloop2: for (; xmax > xmin; --xmax) for (int y = 0; y < g.size.y; ++y) if (any(xmax, y)) break xloop2;
						yloop2: for (; ymax > ymin; --ymax) for (int x = 0; x < g.size.x; ++x) if (any(x, ymax)) break yloop2;
						
						if (xmin > 0 || ymin > 0 || xmin < g.size.x-1 || ymin < g.size.y-1) {
							// Looks like we can strip a pixel here or there!
							
							vec2i size = vec2i(xmax+1-xmin, ymax+1-ymin);	// size of the new bitmap
							
							// We don't like 0-sized textures
							if (size.x > 0 && size.y > 0) {
								assert (size.x <= g.size.x);
								assert (size.y <= g.size.y);
								
								ubyte[] newBuf;
								newBuf.alloc(size.x*size.y*4);
								
								for (int y = 0; y < size.y; ++y) {
									int srcOff = ((y + ymin) * g.size.x + xmin) * 4;
									int dstOff = y * size.x * 4;
									int len = size.x * 4;
									
									newBuf[dstOff .. dstOff + len] = buffer[srcOff .. srcOff + len];
								}
								
								// update the glyph info, because we'll be using the new buffer
								buffer.free();
								buffer = newBuf;
								g.size = size;
								g.offset.x += xmin;
								g.offset.y -= ymin;
							}
						}
					}
				}
				
				g.buffer = buffer;
				glyphs ~= g;
				
				index = glyphs.length - 1;
				//buffer.free();
			}
			
			if (c < 128) {		// ascii chars use a faster path
				asciiGlyphMap[c] = index;
			} else {
				glyphMap[c] = index;
				glyphMap.rehash;
			}
			
			return index;
		}
		
		
		// are we using any lcd filter ?
		bool crispLCDFilter() {
	 		return lcdFilter_ == LCDFilter.Crisp && (FontAntialiasing.LCD_RGB == antialiasing || FontAntialiasing.LCD_BGR == antialiasing);
		}
		
				
		uint				height_;
		uint				lineSkip_;
		uint				lineGap_;
		int				ascent_;
		int				descent_;
		LCDFilter		lcdFilter_ = LCDFilter.Crisp;
		
		FT_Face		fontFace;
		ubyte[]			fontData;
		
		uint[dchar]	glyphMap;
		uint[128]		asciiGlyphMap = uint.max;
		Glyph[]			glyphs;

		public FontAntialiasing antialiasing = FontAntialiasing.LCD_RGB;


		// Don't construct this object manually. Use the static opCall.
		this() {}
		~this() {}
	}
}


private void gammaCorrect(ubyte[] rgb, float factor) {
	float scale = 1.f, temp = 0.f;
	float r = cast(float)rgb[0];
	float g = cast(float)rgb[1];
	float b = cast(float)rgb[2];
	r = r * factor / 255.f;
	g = g * factor / 255.f;
	b = b * factor / 255.f;
	if (r > 1.f && (temp = (1.f / r)) < scale) scale = temp;
	if (g > 1.f && (temp = (1.f / g)) < scale) scale = temp;
	if (b > 1.f && (temp = (1.f / b)) < scale) scale = temp;
	scale *= 255.0f;
	r *= scale;	
	g *= scale;	
	b *= scale;
	rgb[0] = cast(ubyte)r;
	rgb[1] = cast(ubyte)g;
	rgb[2] = cast(ubyte)b;
}


private ubyte crispFilter(ubyte[] data ...) {
	float total = 0.f;
	total += data[0] * 0.08f;
	total += data[4] * 0.08f;
	total += data[1] * 0.24f;
	total += data[3] * 0.24f;
	total += data[2] * 0.36f;
	
	total *= 0.55f;
	total += data[2] * 0.2f;
	
	if (total <= 0.f) return 0;
	if (total >= 255.f) return 255;
	return cast(ubyte)rndint(total);
}
