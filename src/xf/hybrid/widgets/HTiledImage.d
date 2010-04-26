module xf.hybrid.widgets.HTiledImage;

private {
	import xf.hybrid.Common;
	import xf.hybrid.Style;
	import xf.hybrid.Shape : Rectangle;
}



// HACK. TODO: texture repeating in the GL Renderer
class HTiledImage : Widget {
	this() {
		//this.shape = new Rectangle;
		this.registerStyle("normal", this._normalStyle = new Style);
		this.enableStyle("normal");
		//super();
	}


	override EventHandling handleRender(RenderEvent e) {
		if (!widgetVisible) {
			return EventHandling.Stop;
		}

		assert (e.renderer !is null);
		auto r = e.renderer;
		r.applyStyle(this.style);

		if (this.style.image.available) {
			auto img = this.style.image.value();
			
			r.color = vec4.one;
			r.enableTexturing(img.texture);
			
			vec2i maxSize = vec2i(_tiledWidth, cast(int)this.size.y);
			vec2i imgSize = img.size;
			
			vec2[4] vp = void;
			vp[0] = vec2.zero;
			vp[1] = vec2(0, this.size.y);
			
			for (int x = 0; x < maxSize.x; x += imgSize.x) {
				int x2 = min(x + imgSize.x, maxSize.x);
				vec2 off = this.globalOffset + vec2(x, 0);

				vp[2] = vec2(x2-x, this.size.y);
				vp[3] = vec2(x2-x, 0);

				vec2[4] tc = void;
				tc[0] = img.texCoords[0];
				tc[2] = img.texCoords[1];
				tc[2].x = (tc[2].x - tc[0].x) * (x2 - x) / imgSize.x + tc[0].x;
				tc[1] = vec2(tc[0].x, tc[2].y);
				tc[3] = vec2(tc[2].x, tc[0].y);
				
				vec2[4] pos = vp;
				pos[] += off;
				
				r.absoluteQuad(pos, tc);
			}
		}

		return EventHandling.Continue;
	}
	
	
	typeof(this) file(char[] path) {
		this._file = path;
		_normalStyle.image.value = new ImageStyle(path);
		return this;
	}
	
	char[] file() {
		return _file;
	}
	
	
	int tileWidth() {
		if (!_normalStyle.image.available) {
			return 1;
		} else {
			return _normalStyle.image.value.size.x;
		}
	}
	
	
	protected {
		char[]	_file;
		Style		_normalStyle;
	}
	
	mixin(defineProperties("char[] file, out int tileWidth, inline int tiledWidth"));
	mixin MWidget;
}
