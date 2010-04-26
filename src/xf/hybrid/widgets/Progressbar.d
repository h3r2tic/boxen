module xf.hybrid.widgets.Progressbar;

private {
	import xf.hybrid.Common;
	import xf.hybrid.CustomWidget;
	import xf.hybrid.widgets.HTiledImage;
}



/**
	Properties:
	---
	inline float position
	inline bool smooth
	---
*/
class Progressbar : CustomWidget {
	protected void configureImg() {
		if (position >= 1.f) {
			_img.tiledWidth = cast(int)_img.size.x;
		} else {
			int w = cast(int)(position * _img.size.x);
			if (smooth) {
				_img.tiledWidth = w;
			} else if (_img.tileWidth > 0) {
				_img.tiledWidth = w - w % _img.tileWidth;
			}
		}
	}

	override EventHandling handleRender(RenderEvent e) {
		configureImg();
		return super.handleRender(e);
	}
	
	this() {
		getAndRemoveSub("img", &_img);
		_position = 0.f;
	}
	
	
	protected {
		HTiledImage _img;
	}
	
	mixin(defineProperties("inline float position, inline bool smooth"));
	mixin MWidget;
}
