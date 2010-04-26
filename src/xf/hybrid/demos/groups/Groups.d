module HelloWorld;

private {
	import xf.hybrid.Hybrid;
	import xf.hybrid.backend.GL;

	// for Thread.yield
	import tango.core.Thread;
}



void main() {
	version (DontMountExtra) {} else gui.vfsMountDir(`../../`);
	scope cfg = loadHybridConfig(`./Groups.cfg`);
	scope renderer = new Renderer;

	bool programRunning = true;
	while (programRunning) {
		gui.begin(cfg);
			if (gui().getProperty!(bool)("wnd.frame.closeClicked")) {
				programRunning = false;
			}
			
			Group(`main`) [{
				gui.push(`main`);
					Button(`forble`).text = "borble";
				gui.pop;
			}];
		gui.end();
		gui.render(renderer);
		Thread.yield();
	}
}
