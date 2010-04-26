module xf.hybrid.widgets.Angle;

private {
	import tango.math.Math;

	import xf.hybrid.Common;
	import xf.hybrid.CustomWidget;

	import xf.hybrid.backend.gl.Widgets : GLViewport;
	import xf.dog.Dog;

	import xf.omg.core.Algebra;
}

/**
    Allows intuitive specification of an angle.
	All angles are counterclockwise from zero, which is counterclockwise
	from directly to the right. min and max are limits, and are
	visualized.
	TODO: Themable colors
	Properties:
	---
	inline float zero

	inline float angle

	inline float min
	inline float max

	inline bool filled

	inline uint angleWidth
	inline uint limitWidth
	---
*/

class Angle : CustomWidget {
	this() {
		_zero = 0;
		_angle = 0;
		_angleWidth = 2;
		_limitWidth = 1;
		_filled = true;
		
		getAndRemoveSub("glView", &_glView);
		_glView.renderingHandler(&this.draw);

		addHandler(&handleMouseButton);
		addHandler(&handleMouseMove);
	}

	protected void updateAngle(float x, float y) {
		_angle = atan2(y, x) - (_zero * PI/180);
		if(angle < 0) {
			_angle += 2*PI;
		}
        
        _angle *= 180/PI;
        
		if(_angle > _max) {	
			_angle = _max;
		} else if(_angle < _min) {
			_angle = _min;
		}
	}

	EventHandling handleMouseButton(MouseButtonEvent e) {
		if(e.button == MouseButton.Left && e.down) {
			gui.addGlobalHandler(&globalHandleMouseButton);
			_tracking = true;
			updateAngle(e.pos.x - size.x/2.0, size.y/2.0 - e.pos.y);
			return EventHandling.Stop;
		}
		return EventHandling.Continue;
	}

	bool globalHandleMouseButton(MouseButtonEvent e) {
		if(e.button == MouseButton.Left && !e.down) {
			_tracking = false;
			return true;
		}
		return false;
	}

	EventHandling handleMouseMove(MouseMoveEvent e) {
		if(_tracking) {
			updateAngle(e.pos.x - size.x/2.0, size.y/2.0 - e.pos.y);
		}
		return EventHandling.Continue;
	}

	protected void draw(vec2i size, GL gl) {
		_size = size;
		float _radius = size.x/2.0;

		// Setup
		gl.LoadIdentity();
		gl.MatrixMode(GL_PROJECTION);
		gl.LoadIdentity();
		gl.gluOrtho2D(-size.x/2, size.x/2, -size.y/2, size.y/2);
		gl.MatrixMode(GL_MODELVIEW);
		gl.Disable(GL_DEPTH_TEST);
		gl.ShadeModel(GL_SMOOTH);
		gl.Enable(GL_BLEND);
		gl.Enable(GL_POINT_SMOOTH);
		gl.Enable(GL_LINE_SMOOTH);
		gl.Enable(GL_POLYGON_SMOOTH);
		gl.BlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		gl.Hint(GL_POINT_SMOOTH_HINT, GL_NICEST);
		gl.Hint(GL_LINE_SMOOTH_HINT, GL_NICEST);
		gl.Hint(GL_POLYGON_SMOOTH_HINT, GL_NICEST);
		gl.Hint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
		gl.LoadIdentity();

		// Draw background circle
		gl.Color3f(0, 0, 0);
		// Pick a reasonable resolution
		int bgSegs = cast(int)(_radius) + 8;
		if(bgSegs > 64) {
			bgSegs = 64;
		}
		double bgCoef = 2.0*PI/bgSegs;
		if(_filled) {
			gl.immediate(GL_TRIANGLE_FAN, {
					gl.Vertex2f(0, 0);
					for(int n = 0; n <= bgSegs; n++){
						double rads = n*bgCoef;
						gl.Vertex2f((_radius-2)*cos(rads), (_radius-2)*sin(rads));
					}
				});
		}
		// Smooth outline
		gl.LineWidth(4);
		gl.immediate(GL_LINE_LOOP, {
				for(int n = 0; n < bgSegs; n++){
					double rads = n*bgCoef;
					gl.Vertex2f((_radius-2)*cos(rads), (_radius-2)*sin(rads));
				}
			});

		// Draw angle
		float realAngle = _angle + _zero;
        realAngle *= PI/180;
		gl.LineWidth(_angleWidth);
		gl.Color3f(.25, 1, .25); // Green
		gl.immediate(GL_LINES, {
				gl.Vertex2f(0, 0);
				gl.Vertex2f(cos(realAngle) * _radius, sin(realAngle) * _radius);
			});

		// Draw limits if they exist
		if(!(isNaN(_min) || isNaN(_max))) {
			float realMin = _min + _zero;
			float realMax = _max + _zero;
            realMin *= PI/180;
            realMax *= PI/180;
			gl.LineWidth(_limitWidth);
			gl.Color3f(1, .25, .25); // Red
			gl.immediate(GL_LINES, {
					gl.Vertex2f(0, 0);
					gl.Vertex2f(cos(realMin) * _radius, sin(realMin) * _radius);

					gl.Vertex2f(0, 0);
					gl.Vertex2f(cos(realMax) * _radius, sin(realMax) * _radius);
				});
		}
	}

	protected {
		GLViewport _glView;
		bool _tracking = false;
		vec2i _size;
	}

	mixin(defineProperties(
			  "inline float zero, inline float angle,"
			  "inline float min, inline float max,"
			  "inline bool filled, inline uint angleWidth,"
			  "inline uint limitWidth"
			  ));
	mixin MWidget;
}