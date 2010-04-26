module Calc;

private {
	import xf.hybrid.Hybrid;
	import xf.hybrid.backend.GL;

	// for Thread.yield
	import tango.core.Thread;
	import tango.util.Convert;
}



void main() {
	version (DontMountExtra) {} else gui.vfsMountDir(`../../`);
	scope cfg = loadHybridConfig(`./Calc.cfg`);
	scope renderer = new Renderer;
	
	gui.begin(cfg);
		Group(`main`)
			.grabKeyboardFocus()
			.addHandler((KeyboardEvent e) {
				if (e.sinking && e.down) {
					if (e.unicode >= '0' && e.unicode <= '9') {
						onDigit(e.unicode - '0');
					} else if (KeySym.Return == e.keySym) {
						evalOp();
					} else switch (e.unicode) {
						case '/':
							onOp((long a, long b) { return b == 0 ? 0 : a / b; });
							break;
						case '*':
							onOp((long a, long b) { return a * b; });
							break;
						case '+':
							onOp((long a, long b) { return a + b; });
							break;
						case '-':
							onOp((long a, long b) { return a - b; });
							break;
						case '=':
							evalOp();
							break;
						default: break;
					}
				}
				return EventHandling.Continue;
			});
	gui.end();

	bool programRunning = true;
	while (programRunning) {
		gui.begin(cfg);
			if (gui().getProperty!(bool)("main.frame.closeClicked")) {
				programRunning = false;
			}
			
			gui.push(`main.buttons`);
			
			for (int dig = 0; dig <= 9; ++dig) {
				if (GenericButton("d" ~ cast(char)('0'+dig)).clicked) {
					onDigit(dig);
				}
			}
			
			if (GenericButton("div").clicked) {
				onOp((long a, long b) { return b == 0 ? 0 : a / b; });
			}

			if (GenericButton("mul").clicked) {
				onOp((long a, long b) { return a * b; });
			}

			if (GenericButton("add").clicked) {
				onOp((long a, long b) { return a + b; });
			}

			if (GenericButton("sub").clicked) {
				onOp((long a, long b) { return a - b; });
			}

			if (GenericButton("chSign").clicked) {
				auto lab = Label(`.main.display`);
				if (lab.text != "0") {
					if (lab.text.length > 0 && '-' == lab.text[0]) {
						lab.text = lab.text[1..$];
					} else {
						lab.text = '-' ~ lab.text;
					}
				}
			}

			if (GenericButton("equals").clicked) {
				evalOp();
			}

			gui.pop();
		gui.end();
		gui.render(renderer);
		Thread.yield();
	}
}


long										prevNum;
bool										enteringNewNum = true;
long delegate(long a, long b)	curOp;


void onDigit(int d) {
	auto lab = Label(`.main.display`);

	char[] text;
	if (enteringNewNum || "0" == lab.text) {
		text = "" ~ cast(char)(d + '0');
		enteringNewNum = false;
	} else {
		text = lab.text ~ cast(char)(d + '0');
	}
	
	char[] convText = to!(char[])(to!(long)(text));
	if (convText == text) {
		lab.text = text;
	}
}


void evalOp() {
	auto lab = Label(`.main.display`);
	
	if (curOp !is null) {
		lab.text = to!(char[])(curOp(prevNum, to!(long)(lab.text)));
		curOp = null;
	}

	enteringNewNum = true;
}


void onOp(long delegate(long a, long b) op) {
	evalOp();
	curOp = op;
	prevNum = to!(long)(Label(`.main.display`).text);
}
