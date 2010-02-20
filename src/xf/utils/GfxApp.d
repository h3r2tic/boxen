module xf.utils.GfxApp;

private {
	import
		xf.Common,
		xf.game.MainProcess,
		xf.core.Registry,
		xf.core.MessageHub,
		xf.core.Message,
		xf.gfx.api.gl3.backend.Native;
}

public {
	import
		xf.gfx.IRenderer,

		xf.omg.core.LinearAlgebra,

		xf.core.InputHub,
		xf.core.JobHub,
		
		xf.utils.Use,
		
		xf.input.Input,
		xf.input.KeySym;
}



abstract class GfxApp {
	void initialize() {
	}
	
	
	void render() {
	}
	
	
	void cleanup() {
	}


	void run() {
		keyboard = new SimpleKeyboardReader(inputHub.mainChannel);

		renderer = create!(IRenderer)();
		window = renderer.window;
		window
			.title(windowTitle)
			.showCursor(true)
			.fullscreen(false)
			.swapInterval(vsync ? 1 : 0)
			.width(1040)
			.height(650)	// 1.6 aspect ratio
			/+.fullscreen(true)
			.width(1680)
			.height(1050)+/
		.create();
		renderer.initialize();
		
		jobHub.addRepeatableJob({
			if (keyboard.keyDown(KeySym.Escape)) {
				messageHub.sendMessage(new QuitMessage);
			}
			
			if (window.created) {
				window.update();
			}
		}, inputUpdateFrequency);
		
		window.inputChannel = inputHub.mainChannel;
		initialize();

		inputHub.mainChannel.addReader(this.new LocalInputReader);
		
		jobHub.addPostFrameJob({
			render();
			renderer.swapBuffers();
		});
		jobHub.exec(new MainProcess);
		
		cleanup();
		
		if (window && window.created) {
			window.destroy();
			window = null;
		}
	}
	
	
	private class LocalInputReader : InputReader {
		void onKInput(KeyboardInput* i) {
			this.outer.onInput(i);
		}

		void onMInput(MouseInput* i) {
			this.outer.onInput(i);
		}

		this() {
			registerReader(&this.onKInput);
			registerReader(&this.onMInput);
		}
	}
	
	
	void onInput(KeyboardInput* i) {
	}


	void onInput(MouseInput* i) {
	}

	
	cstring	windowTitle	= "GfxApp";
	bool	vsync		= false;
	
	IRenderer				renderer;
	Window					window;
	SimpleKeyboardReader	keyboard;
	
	int						inputUpdateFrequency = 200;
}
