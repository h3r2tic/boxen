module xf.hybrid.backend.gfx.Widgets;

private {
	import xf.hybrid.backend.gfx.Renderer : Renderer;
	import xf.hybrid.GuiRenderer : BaseRenderer = GuiRenderer;
	import xf.hybrid.Common;
	import xf.hybrid.widgets.Group;
	import xf.hybrid.Shape;
	import xf.hybrid.CustomWidget;
	
	import xf.hybrid.widgets.WindowFrame;
	
	import xf.input.Input;
	import xf.input.Writer;

	import tango.util.log.Trace;
}



class TopLevel : Group {
	this() {
		overrideSizeForFrame(minSize);
		layout = new BinLayout;
		
		//context.reshape = &this.reshapeHandler;
	}
	

	override vec2 minSize() {
		return vec2(80, 60);
	}
	

	/+override vec2 desiredSize() {
		return vec2(context.width, context.height);
	}+/
	
	
	protected void reshapeHandler(size_t w, size_t h) {
		Trace.formatln("reshape [{} {}]", w, h);
		//this.userSize = vec2(w, h);
	}

	
	override EventHandling handleExpandLayout(ExpandLayoutEvent e) {
		auto res = super.handleExpandLayout(e);
		
		if (e.bubbling) {
			vec2i si = vec2i.from(this.size);
			
			/+if (context.width != si.x) {
				Trace.formatln("Width changed");
				context.width = si.x;
			}
			
			if (context.height != si.y) {
				Trace.formatln("Height changed");
				context.height = si.y;
			}+/
		}
		
		return res;
	}
	
	
	protected EventHandling handleRender(RenderEvent e) {
		auto r = cast(Renderer)e.renderer;
		
		if (e.sinking) {
			//Trace.formatln("r.viewportSize = {}", vec2i.from(this.size));
			r.viewportSize = vec2i.from(this.size);
			r.setClipRect(Rect(vec2.zero, this.size));
		}
		
		super.handleRender(e);

		if (e.bubbling) {
			r.flush();
		}

		if (e.sinking) {
			return EventHandling.Continue;
		} else {
			return EventHandling.Stop;
		}
	}


	mixin MWidget;
}







/+


/**
	Manages a raw OS-level window via Dog
	
	Properties:
	---
	char[] text
	
	// position within the OS
	vec2i rootPos
	
	bool showCursor
	---
*/
class TopLevelWindow : Group {
	this() {
		overrideSizeForFrame(minSize);
		context = GLWindow();
		layout = new BinLayout;
		
		context
			.title("Hybrid test")
			.decorations(false)
			.width(width)
			.height(height)
		.create();
		
		context.reshape = &this.reshapeHandler;
		
		setupGL();
		
		version (NewDogInput) {
			context.inputChannel = gui.inputChannel;
		} else {
			context.msgFilter = &(new OSInputWriter(gui.inputChannel, false)).filter;
		}
	}
	
	
	void destroy() {
		context.destroy;
	}
	
	
	///
	int width() {
		return cast(int)this.size.x;
	}
	

	///
	int height() {
		return cast(int)this.size.y;
	}


	override vec2 minSize() {
		return vec2(80, 60);
	}
	

	override vec2 desiredSize() {
		return vec2(context.width, context.height);
	}
	
	
	protected void reshapeHandler(size_t w, size_t h) {
		Trace.formatln("reshape [{} {}]", w, h);
		//this.userSize = vec2(w, h);
	}

	
	protected void setupGL() {
		Trace.formatln("setupGL");

		use(context) in (GL gl) {
			gl.MatrixMode(GL_PROJECTION);
			gl.LoadIdentity();
			gl.gluOrtho2D(0, context.width, context.height, 0);
			gl.MatrixMode(GL_MODELVIEW);
			gl.LoadIdentity();
		};
	}
	
	
	override EventHandling handleExpandLayout(ExpandLayoutEvent e) {
		auto res = super.handleExpandLayout(e);
		
		if (e.bubbling) {
			vec2i si = vec2i.from(this.size);
			
			if (context.width != si.x) {
				Trace.formatln("Width changed");
				context.width = si.x;
			}
			
			if (context.height != si.y) {
				Trace.formatln("Height changed");
				context.height = si.y;
			}
		}
		
		return res;
	}
	
	
	protected EventHandling handleRender(RenderEvent e) {
		auto r = cast(Renderer)e.renderer;
		
		if (e.sinking) {
			auto gl = context.begin();
			r.gl = gl;
			//Trace.formatln("r.viewportSize = {}", vec2i.from(this.size));
			r.viewportSize = vec2i.from(this.size);
			e.renderer.setClipRect(Rect(vec2.zero, this.size));
			
			if (clearBackground) {
				gl.Clear(GL_COLOR_BUFFER_BIT);
			}
		}
		
		super.handleRender(e);

		if (e.bubbling) {
			r.flush();
			/+r.gl.DisableClientState(GL_TEXTURE_COORD_ARRAY);
			r.gl.DisableClientState(GL_VERTEX_ARRAY);
			r.gl.DisableClientState(GL_COLOR_ARRAY);
			r.gl.Disable(GL_TEXTURE_2D);
			r.gl.Disable(GL_BLEND);
			r.gl.Disable(GL_SCISSOR_TEST);+/
			r.gl = null;

			context.end();
			context.update().show();
		}

		if (e.sinking) {
			return EventHandling.Continue;
		} else {
			return EventHandling.Stop;
		}
	}
	
	
	/**
		Installs mouse drag handlers in the frame
	*/
	void bindToFrame(WindowFrame f) {
		assert (f !is null);
		_frame = f;
		_frame.handle.addHandler(&this.onFrameHandleButton);
		_frame.handle.addHandler(&this.onFrameHandleMouseMove);
	}
	
	
	protected bool frameHandleButtonGlobal(MouseButtonEvent e) {
		if (!e.down) {
			_dragging = false;
			return true;
		} else {
			return false;
		}
	}
	
	
	protected EventHandling onFrameHandleButton(MouseButtonEvent e) {
		if (MouseButton.Left == e.button) {
			if (e.sinking) {
				_dragging = e.down;
				gui.addGlobalHandler(&frameHandleButtonGlobal);
			}
		}
		return EventHandling.Stop;
	}


	protected EventHandling onFrameHandleMouseMove(MouseMoveEvent e) {
		if (!_dragging) {
			_dragOffset = context.position - vec2i(cast(int)e.rootPos.x, cast(int)e.rootPos.y);
		}
		
		if (e.sinking && _dragging) {
			vec2i g = vec2i(cast(int)e.rootPos.x, cast(int)e.rootPos.y);
			context.position = g + _dragOffset;
			return EventHandling.Stop;
		}
		
		return EventHandling.Continue;
	}

	typeof(this) text(char[] value) {
		context.title = value;
		return this;
	}

	char[] text() {
		return context.title;
	}
	
	typeof(this) rootPos(vec2i value) {
		context.position = value;
		return this;
	}

	vec2i rootPos() {
		return context.position;
	}

	// Consider replacing this with _cursorVisible
	typeof(this) showCursor(bool value) {
		context.showCursor(value);
		_cursorVisible = value;
		return this;
	}

	bool showCursor() {
		return _cursorVisible;
	}


	GLWindow				context;
	
	protected {
		bool					_cursorVisible = true;
		WindowFrame	_frame;
		bool					_dragging;
		vec2i				_dragOffset;
	}


	mixin(defineProperties("char[] text, vec2i rootPos, bool showCursor, inline bool clearBackground"));
	mixin MWidget;
}


/**
	Manages a Hybrid-framed OS-level window via Dog
*/
class FramedTopLevelWindow : CustomWidgetT!(TopLevelWindow) {
	this() {
		WindowFrame f;
		getAndRemoveSub("frame", &f);
		bindToFrame(f);
	}
	
	
	override IWidget getLocalSub(char[] name) {
		if ("frame" == name) {
			return frame;
		} else {
			return super.getLocalSub(name);
		}
	}


	override void onGuiStructureBuilt() {
		auto frameText = frame.text();
		if (frameText != this.text) {
			this.text = frameText;
		}
		super.onGuiStructureBuilt();
	}
	
	
	WindowFrame frame() {
		return _frame;
	}

	mixin MWidget;
}



/**
	A viewport with a custom OpenGL rendering handler
*/
class GLViewport : Widget {
	/**
		Sets the delegate that will do the actual rendering. The handler will be called automatically by the renderer
		and should not be invoked manually. The params it gets are the viewport size and a Dog context
	*/
	typeof(this) renderingHandler(void delegate(vec2i, GL) dg) {
		_renderingHandler = dg;
		return this;
	}
	
	
	override EventHandling handleRender(RenderEvent e) {
		if (!widgetVisible) {
			return EventHandling.Stop;
		}
		
		if (e.sinking && _renderingHandler !is null) {
			if (auto r = cast(Renderer)e.renderer) {
				r.pushClipRect();
				r.clip(Rect(this.globalOffset, this.globalOffset + this.size));
				r.direct(&this.handleRender_, Rect(this.globalOffset, this.globalOffset + this.size));
				r.popClipRect();
			}
		}

		return EventHandling.Continue;
	}
	
	
	protected void handleRender_(BaseRenderer br) {
		auto r = cast(Renderer)br;
		assert (r !is null);
		
		beginCustomRendering(r);
		scope (exit) endCustomRendering(r);
		
		_renderingHandler(vec2i.from(this.size), r.gl);		
	}
	
	
	protected void beginCustomRendering(Renderer r) {
		auto gl = r.gl;
		gl.MatrixMode(GL_PROJECTION);
		gl.PushMatrix();
		gl.LoadIdentity();
		gl.MatrixMode(GL_MODELVIEW);
		gl.PushMatrix();
		gl.LoadIdentity();
		
		gl.PushAttrib(GL_ALL_ATTRIB_BITS);
		gl.DisableClientState(GL_TEXTURE_COORD_ARRAY);
		gl.DisableClientState(GL_VERTEX_ARRAY);
		gl.DisableClientState(GL_COLOR_ARRAY);
		gl.Disable(GL_TEXTURE_2D);
		gl.Disable(GL_BLEND);
		gl.Color3f(1, 1, 1);
	}
	

	protected void endCustomRendering(Renderer r) {
		auto gl = r.gl;
		gl.PopAttrib();

		gl.MatrixMode(GL_MODELVIEW);
		gl.PopMatrix();
		gl.MatrixMode(GL_PROJECTION);
		gl.PopMatrix();
		gl.MatrixMode(GL_MODELVIEW);
	}

	
	protected {
		void delegate(vec2i, GL) _renderingHandler;
	}


	mixin MWidget;
}
+/
