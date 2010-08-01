module xf.hybrid.widgets.Label;

private {
	import xf.hybrid.Common;
	import xf.hybrid.Font;
	import xf.hybrid.GuiRenderer;
	
	import tango.io.Stdout;
	import tango.util.Convert;
	import tango.stdc.string : memmove;
}



/**
	Static text label
	Properties:
	---
	char[] text
	inline Font font
	
	// default = verdana.ttf
	char[] fontFace
	
	// default = 13
	int fontSize
	
	// 0 -> left, 1 -> center, 2 -> right
	inline int halign
	inline int valign
	---
*/
class Label : Widget {
	override vec2 minSize() {
		return vec2[this.width(), font.lineSkip()];
	}
	
	
	int width() {
		if (_width != -1) {
			return _width;
		} else {
			return _width = font.width(_text, &_fpCache);
		}
	}
	

	protected override char[] _toString(char[] indent) {
		return indent ~ this.classinfo.name ~ " = '" ~ _text ~ "'"  ~ " o" ~ to!(char[])(parentOffset) ~ " s" ~ to!(char[])(size);
	}
	
	
	typeof(this) fontFace(char[] s) {
		_fpCache.invalidate();
		_width = -1;

		font = Font(_fontFace = s, fontSize);
		return this;
	}
	
	
	char[] fontFace() {
		return _fontFace;
	}
	
	
	typeof(this) fontSize(int s) {
		_fpCache.invalidate();
		_width = -1;

		font = Font(fontFace, _fontSize = s);
		return this;
	}
	
	
	int fontSize() {
		return _fontSize;
	}
	
	
	typeof(this) text(char[] t) {
		_fpCache.invalidate();
		_width = -1;
		
		_text.length = t.length;
		memmove(_text.ptr, t.ptr, t.length * char.sizeof);
		return this;
	}
	
	
	char[] text() {
		return _text;
	}
	
	
	override void render(GuiRenderer r) {
		super.render(r);
		r.flushStyleSettings();
		
		vec2 ms = this.minSize;
		vec2 cs = this.size;
		vec2 off = globalOffset;
		
		switch (_halign) {
			case 0: break;
			case 1: off.x += (cs.x - ms.x) * .5f; break;
			case 2: off.x += cs.x - ms.x; break;
			default: break;
		}
		
		switch (_valign) {
			case 0: break;
			case 1: off.y += (cs.y - ms.y) * .5f; break;
			case 2: off.y += cs.y - ms.y; break;
			default: break;
		}

		font.print(off, text, &_fpCache);
	}
	
	
	this() {
		font = Font(_fontFace = `verdana.ttf`, _fontSize = 13);
	}
	
	
	protected {
		char[]	_fontFace;
		int		_fontSize;
		char[]	_text;
		
		int				_width = -1;
		FontPrintCache	_fpCache;
	}


	mixin(defineProperties("char[] text, inline Font font, char[] fontFace, int fontSize, inline int halign, inline int valign"));
	mixin MWidget;
}
