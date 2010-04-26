module HelloWorld;

private {
	import xf.hybrid.Hybrid;
	import xf.hybrid.backend.GL;
	
	import xf.hybrid.model.Core;
	import xf.hybrid.Layout;
	import xf.hybrid.WidgetConfig : PropAssign;

	// for Thread.yield
	import tango.core.Thread;
	import tango.io.Stdout;
	import tango.util.log.Trace;
}


class MyLayout : ILayout {
	float	radius	= 100.f;
	vec2	size		= { x: 320, y: 240 };
	
	void minimize(IWidget parent) {
		int numChildren = 0;
		foreach (ch; &parent.children) {
			++numChildren;
		}
		
		vec2 offsetForChild(int i) {
			float angle = cast(float)i / numChildren * pi * 2;
			return vec2(cos(angle), sin(angle)) * radius;
		}
		
		parent.overrideSizeForFrame(this.size);
		vec2 center = parent.size * .5f;
		
		int i = 0;
		foreach (ch; &parent.children) {
			ch.overrideSizeForFrame(ch.desiredSize);
			ch.parentOffset = offsetForChild(i) + center - ch.size * 0.5;
			++i;
		}
	}
	
	void expand(IWidget parent) {
		return;
	}
	
	void configure(PropAssign[]) {
		return;
	}
}

static this() {
	registerLayout("MyLayout", function ILayout() {
		return new MyLayout;
	});
}


void main() {
	version (DontMountExtra) {} else gui.vfsMountDir(`../../`);
	scope cfg = loadHybridConfig(`./CustomLayout.cfg`);
	scope renderer = new Renderer;
	
	int numButtons = 1;

	bool programRunning = true;
	while (programRunning) {
		gui.begin(cfg);
			if (gui().getProperty!(bool)("main.frame.closeClicked")) {
				programRunning = false;
			}
			Group(`main`) [{
				for (int i = 0; i < numButtons; ++i) {
					if (Button(i).clicked) {
						++numButtons;
					}
				}
			}];
		gui.end();
		gui.render(renderer);
		Thread.yield();
	}
}
