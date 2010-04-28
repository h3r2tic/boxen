module xf.utils.GfxApp;

private {
	import
		xf.Common,
		xf.game.MainProcess,
		xf.core.Registry,
		xf.core.MessageHub,
		xf.core.Message;
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
	
	
	void configureWindow(Window wnd) {
		wnd
			.title("GfxApp")
			.showCursor(true)
			.fullscreen(false)
			.swapInterval(0)
			.width(1040)
			.height(650);	// 1.6 aspect ratio
	}


	void run() {
		keyboard = new SimpleKeyboardReader(inputHub.mainChannel);

		renderer = create!(IRenderer)();
		configureWindow(window = renderer.window);
		window.create();
		renderer.initialize();
		
		jobHub.addRepeatableJob({
			if (keyboard.keyDown(KeySym.Escape)) {
				exitApp();
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


	void exitApp() {
		messageHub.sendMessage(new QuitMessage);
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

	
	IRenderer				renderer;
	Window					window;
	SimpleKeyboardReader	keyboard;
	int						inputUpdateFrequency = 200;
}
