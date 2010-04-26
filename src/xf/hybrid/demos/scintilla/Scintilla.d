module xf.hybrid.demos.scintilla.Scintilla;

private {
	import xf.hybrid.Hybrid;
	import xf.hybrid.backend.GL;

	// for Thread.yield
	import tango.core.Thread;
}


version (Windows) {} else static assert (false, "TODO");


void main() {
	version (DontMountExtra) {} else gui.vfsMountDir(`../../`);
	scope cfg = loadHybridConfig(`./Scintilla.cfg`);
	scope renderer = new Renderer;

	gui.begin(cfg);
		SciEditor(`main.sci1`).insertText(import("Scintilla.d")).grabKeyboardFocus();
		SciEditor(`main.sci2`).insertText(import("Scintilla.cfg"));
	gui.end();

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
