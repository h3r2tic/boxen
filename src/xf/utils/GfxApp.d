module xf.utils.GfxApp;

private {
	import
		xf.Common,
		xf.game.MainProcess,
		xf.core.MessageHub,
		xf.core.Message,
		
		xf.gfx.api.gl3.ext.WGL_EXT_swap_control,
		xf.gfx.api.gl3.ext.EXT_framebuffer_sRGB,
		xf.gfx.api.gl3.backend.Native;
}

public {
	import
		xf.gfx.api.gl3.OpenGL,		// tmp
		xf.gfx.gl3.Renderer,

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
	
	
	void render(GL gl) {
	}
	
	
	void cleanup() {
	}


	void run() {
		keyboard = new SimpleKeyboardReader(inputHub.mainChannel);

		window = GLWindow();
		window
			.title(windowTitle)
			.showCursor(true)
			.fullscreen(false)
			.width(1040)
			.height(650)	// 1.6 aspect ratio
			/+.fullscreen(true)
			.width(1680)
			.height(1050)+/
		.create();
		
		use (window) in (GL gl) {
			renderer = new Renderer(gl);
			gl.SwapIntervalEXT(vsync ? 1 : 0);
			gl.Enable(FRAMEBUFFER_SRGB_EXT);
		};

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
			use (window) in (GL gl) {
				render(gl);
			};
			
			window.show;
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
	
	Renderer				renderer;
	GLWindow				window;
	SimpleKeyboardReader	keyboard;
	
	int						inputUpdateFrequency = 200;
}
