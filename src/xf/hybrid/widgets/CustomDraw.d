module xf.hybrid.widgets.CustomDraw;

private {
	import xf.hybrid.Common;
	import xf.hybrid.Style;
	import xf.hybrid.Shape : Rectangle;
}



class CustomDraw : Widget {
	/**
		Sets the delegate that will do the actual rendering. The handler will be called automatically by the renderer
		and should not be invoked manually. The params it gets are the viewport size and a Dog context
	*/
	typeof(this) renderingHandler(void delegate(vec2i, GuiRenderer) dg) {
		_renderingHandler = dg;
		return this;
	}
	
	
	override EventHandling handleRender(RenderEvent e) {
		if (!widgetVisible) {
			return EventHandling.Stop;
		}
		
		if (e.sinking && _renderingHandler !is null) {
			if (auto r = e.renderer) {
				r.pushClipRect();
				vec2 offBefore = r.getOffset();
				scope (exit) {
					r.setOffset(offBefore);
					r.popClipRect();
				}

				r.clip(Rect(this.globalOffset, this.globalOffset + this.size));
				r.setOffset(this.globalOffset);
				_renderingHandler(vec2i.from(this.size), r);
				//r.direct(&this.handleRender_, Rect(this.globalOffset, this.globalOffset + this.size));
			}
		}

		return EventHandling.Continue;
	}
	
	
	/+protected void handleRender_(GuiRenderer r) {
		_renderingHandler(vec2i.from(this.size), r);
	}+/
	
	
	/+protected void beginCustomRendering(Renderer r) {
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
	}+/

	
	protected {
		void delegate(vec2i, GuiRenderer) _renderingHandler;
	}


	mixin MWidget;
}
