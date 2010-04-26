module ColorWheel;

private {
	import tango.core.stacktrace.TraceExceptions;
	
	import xf.hybrid.Hybrid;
	import xf.hybrid.backend.GL;

	// for Thread.yield
	import tango.core.Thread;
}



void main() {
	version (DontMountExtra) {} else gui.vfsMountDir(`../../`);
	scope cfg = loadHybridConfig(`./ColorWheel.cfg`);
	scope renderer = new Renderer;

	bool programRunning = true;
	while (programRunning) {
		gui.begin(cfg);
			if (gui().getProperty!(bool)("main.frame.closeClicked")) {
				programRunning = false;
			}
		gui.end();
		gui.render(renderer);
		Thread.yield();
	}
}
