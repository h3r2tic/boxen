module Main;

version (StackTracing) import tango.core.tools.TraceExceptions;

import
	xf.Common,
	xf.utils.GfxApp,
	xf.test.gfx.Common,
	
	xf.omg.core.LinearAlgebra,
	xf.omg.core.CoordSys,
	
	tango.io.Stdout;

interface Hybrid {
	import
		xf.hybrid.Hybrid,
		xf.hybrid.WidgetConfig,
		xf.hybrid.backend.Gfx;
}
	


void main() {
	(new TestApp).run;
}


class TestApp : GfxApp {
	Hybrid.Renderer guiRenderer;
	Hybrid.Config	guiConfig;

	
	override void configureWindow(Window wnd) {
		super.configureWindow(wnd);
		wnd.title = "Hybrid hello world";
	}
	
	
	override void initialize() {
		guiRenderer = new Hybrid.Renderer(renderer);

		Hybrid.gui.overrideInputChannel(inputHub.mainChannel);
		
		Hybrid.gui.vfsMountDir(`../../../hybrid/`);
		guiConfig = Hybrid.loadHybridConfig(`./GUI.cfg`);
	}


	override void render() {
		renderer.resetState();
		renderer.clearBuffers();

		Hybrid.gui.begin(guiConfig);
		
		Hybrid.TopLevel("main") [{
		}].userSize = vec2(window.width, window.height);
		
		Hybrid.gui.end();
		Hybrid.gui.render(guiRenderer);
	}
}
