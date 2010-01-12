module Main;

import tango.core.tools.TraceExceptions;

import
	xf.gfx.api.gl3.OpenGL,
	xf.gfx.api.gl3.ext.WGL_EXT_swap_control,
	xf.gfx.api.gl3.ext.WGL_EXT_extensions_string,
	xf.gfx.api.gl3.backend.Native;

import tango.io.Stdout		: Stdout;
import tango.stdc.stringz	: fromStringz;

import tango.math.Math;
import tango.time.StopWatch;
import tango.core.Thread;


void main() {
	
	// TIMER
	const uint	TICKS_PER_SECOND = 600;
	const uint	SKIP_USEC = 1000000 / TICKS_PER_SECOND;
	const uint	 MAX_FRAMESKIP = 10;
	
	StopWatch elapsed;
	elapsed.start();

	uint	 next_game_tick = elapsed.microsec;
	int	 drops;
	
	double new_time = elapsed.stop;
	double old_time = new_time;
	float fps = 0;
	double dt = 0;
	
	// DOG
	auto context = GLWindow();
	context
					.title("GL3 Test")
					.showCursor(true)
					.fullscreen(false)
					.width(200)
					.height(200)
	.create();
	
	// setup gl data
	use(context) in (GL gl) {
		version(Windows) {
			gl.SwapIntervalEXT(1);
			Stdout.formatln("refresh = {}", gl.GetSwapIntervalEXT());
			char* extp = gl.GetExtensionsStringEXT();
			if(extp !is null) {
				Stdout.formatln(fromStringz(extp));
			}
			
			extp = gl.GetString(EXTENSIONS);
			if(extp !is null) {
				Stdout.formatln(fromStringz(extp));
			}
				
			Stdout.formatln(fromStringz(gl.GetString(VERSION)));
		}
		
		/+gl.MatrixMode(PROJECTION);
		gl.LoadIdentity();+/
//		gl.gluPerspective(90.f, 1.333f, 0.1f, 100.f);
		/+gl.MatrixMode(MODELVIEW);
		gl.LoadIdentity();+/
		
		/+if(gl.ext(ARB_shader_objects).supported) {
			Stdout.formatln("ARB_shader_objects supported");
		} else {
			Stdout.formatln("ARB_shader_objects NOT supported");
		}+/
		
		
	};
	
	// draw/main loop
	while(context.created) {
		drops = 0;
		
		// synch to 60fps
		while (elapsed.microsec > next_game_tick && drops < MAX_FRAMESKIP) {
			new_time = elapsed.stop;
			dt = new_time - old_time;
			fps = 1.0f / dt;
			old_time = new_time;
			
			use(context) in (GL gl) {
				draw(gl);
			};
			
			Stdout.format("                                                                          \r");
			Stdout.format("{:d2}:{:d2} -- FRAME: {} DROP: {} --  FPS: {}\r", cast(uint)trunc(elapsed.stop), cast(uint)((elapsed.microsec/SKIP_USEC)-(trunc(elapsed.stop)*TICKS_PER_SECOND)), elapsed.microsec/SKIP_USEC, drops, fps).flush;
			
			next_game_tick += SKIP_USEC;
			drops++;
		}		
		
		context.update().show();

		Thread.yield();
		//Thread.sleep(0.016);
	}
	
} // end main()


void draw(GL gl) {
	gl.Clear(COLOR_BUFFER_BIT);
	
	gl.Enable(BLEND);
		gl.BlendFunc(SRC_ALPHA, ONE_MINUS_SRC_ALPHA);
		
		/+gl.Rotatef(.5f, 0, 0, 1);
		
		gl.immediate(TRIANGLES, {
			gl.Color4f(1, 0, 0, 0.5f);
			gl.Vertex3f(-1, -1, -2);

			gl.Color4f(0, 1, 0, 0.5f);
			gl.Vertex3f(1, -1, -2);
			
			gl.Color4f(0, 0, 1, 0.5f);
			gl.Vertex3f(0, 1, -2);			
			
		});+/
	gl.Disable(BLEND);
	
} // end draw()

