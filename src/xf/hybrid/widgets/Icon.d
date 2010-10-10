module xf.hybrid.widgets.Icon;

private {
	import xf.hybrid.Common;
	import xf.hybrid.Style;
	import xf.hybrid.Shape : Rectangle;
}



/**
	Indexable image
	Properties:
	---
	char[] addIcon
	int iconIndex
	---
*/
class Icon : Widget {
	override vec2 minSize() {
		if (this.style.image.available) {
			return vec2.from(this.style.image.value.size);
		} else {
			return vec2.zero;
		}
	}
	
	
	/+this() {
		this.shape = new Rectangle;
	}+/


	EventHandling handleRender(RenderEvent e) {
		iconIndex(_iconIndex);
		return super.handleRender(e);
	}
	
	
	typeof(this) addIcon(char[] path) {
		this._styles ~= new ImageStyle(path);
		iconIndex(_iconIndex);
		return this;
	}
	char[] addIcon() { assert(false); }
	
	
	
	typeof(this) iconIndex(int i) {
		_iconIndex = i;
		this.style.image.value = _styles[i];
		this.style.color.value = vec4(1, 1, 1, 1);

		style.background.value = BackgroundStyle.init;
		auto b = style.background.value;
		b.type = BackgroundStyle.Type.Solid;
		b.Solid = vec4(1, 1, 1, 1);

		return this;
	}
	
	int iconIndex() {
		return _iconIndex;
	}
	
	
	protected {
		int				_iconIndex;
		ImageStyle[]	_styles;
	}
	

	mixin(defineProperties("char[] addIcon, int iconIndex"));
	mixin MWidget;
}
