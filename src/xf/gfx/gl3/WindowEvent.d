module xf.gfx.gl3.WindowEvent;

private {
	import xf.input.Input;
}



struct WindowEvent {
	enum Type {
		Resized,
		Moved,
		Closed,
		Minimized,
		Maximized,
		LostFocus,
		GainedFocus		
	}
	
	
	Type			type;
	union {
		struct {
			uint	width;
			uint	height;
		}
		struct {
			int	xPos;
			int	yPos;
			int	xDelta;
			int	yDelta;
		}
	}
	
	mixin MInput;
}
