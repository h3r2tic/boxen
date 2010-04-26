module xf.hybrid.GuiRenderer;

private {
	import xf.hybrid.Shape;
	import xf.hybrid.Texture;
	import xf.hybrid.IconCache;
	import xf.hybrid.Rect;
	import xf.hybrid.WidgetConfig : PropAssign;
	import xf.hybrid.Math;
}



/**
	An abstraction of a renderer capable of rendering the GUI
*/
abstract class GuiRenderer {
	/**
		Sets the current global rendering offset
	*/
	void setOffset(vec2 off) {
		_offset = off;
	}
	

	/**
		Returns the current global rendering offset
	*/
	vec2 getOffset() {
		return _offset;
	}

	
	/**
		Adds a delta vector to the global rendering offset
	*/
	void offset(vec2 off) {
		_offset += off;
	}
	
	
	/**
		Sets the current rendering color
	*/
	void color(vec3 rgb, float a = 1.f) {
		color = vec4(rgb.r, rgb.g, rgb.b, a);
	}
	
	
	/**
		Merges the current clipping rectangle with the specified one
	*/
	void clip(Rect rect) {
		if (Rect.init == rect) {
			return;
		}
		
		if (Rect.init == _clipRect) {
			_clipRect = rect;
			return;
		}
		
		_clipRect = Rect.intersection(rect, _clipRect);
	}
	
	
	bool fullyClipped(vec2 pos, vec2 size) {
		if (Rect.init == _clipRect) {
			return false;
		}
		
		if (_clipRect.width <= 0 || _clipRect.height <= 0) {
			return true;
		}
		
		return !_clipRect.intersect(Rect(pos, pos+size));
	}
	
	
	/**
		Resets clipping so nothing is clipped by default
	*/
	void resetClipping() {
		_clipRect = Rect.init;
		_clipRectStack.length = 0;
	}
	
	
	/**
		Pushes the current clipping rectangle to the stack
	*/
	void pushClipRect() {
		_clipRectStack ~= _clipRect;
	}
	

	/**
		Pops the current clipping rectangle from the stack
	*/
	void popClipRect() {
		_clipRect = _clipRectStack[$-1];
		_clipRectStack = _clipRectStack[0..$-1];
	}
	
	
	/**
		Returns the current clipping rectangle
	*/
	Rect getClipRect() {
		return _clipRect;
	}
	
	
	/**
		Overrides the current clipping rectangle
	*/
	void setClipRect(Rect r) {
		_clipRect = r;
	}
	

	/// Sets the current rendering color
	abstract void color(vec4 col);

	/// Renders a shape with the given size
	abstract void shape(Shape shape, vec2 size);

	/// Renders a point with the given size
	abstract void	point(vec2, float size = 1.f);
	
	/// Renders a line with the given thickness / width
	abstract void	line(vec2, vec2, float width = 1.f);
	
	/// Renders a rectangle
	abstract void	rect(Rect);
	
	/// Renders a special object - handled by dynamic dispatch in the concrete GuiRenderer
	abstract bool	special(Object);
	
	/// Schedules a direct rendering operation
	abstract void	direct(void delegate(GuiRenderer), Rect);

	/// Sets the current object rendering style
	abstract void applyStyle(Object s);

	/// Flushes all rendering commands, finally producing the rendering results
	abstract void flush();

	// TODO: investigate me
	abstract void flushStyleSettings();


	/// Enables texturing and sets the current texture
	abstract void enableTexturing(Texture tex);
	
	/// Disables texturing
	abstract void disableTexturing();
	
	///
	void absoluteQuad(vec2[] points, vec2[] texCoords);

	/// Returns the currently used icon cache
	abstract IconCache iconCache();
	
	
	protected {
		vec2		_offset	= {x:0, y:0};
		Rect		_clipRect;
		Rect[]	_clipRectStack;
		//vec4	_color	= {r:1, g:1, b:1, a:1};
	}
}
