module xf.hybrid.widgets.Slider;

private {
	import tango.math.Math : abs, floor, ceil;
	import tango.io.Stdout;
	
	import xf.hybrid.Common;
	import xf.hybrid.CustomWidget;
	import xf.hybrid.widgets.WidgetSlider;
	
	import xf.utils.Meta;
}



/**
	Base class for the HSlider and VSlider
	
	Properties:
	---
	// In the [ minValue .. maxValue ] range
	float position
	
	// 0 by default
	inline float minValue
	
	// 1 by default
	inline float maxValue
	
	inline float snapIncrement
	
	// Linear by default
	inline float delegate(float) outputMap
	inline float delegate(float) inputMap
	---
*/
class Slider(bool horizontal) : CustomWidget {
	const bool vertical = !horizontal;
	const static char[] nameForWidgetRegistry = horizontal ? "HSlider" : "VSlider";
	
	
	this() {
		getAndRemoveSub("wslider", &_wslider);
		_wslider.onSlide = &snap;
		_snapIncrement = 0f;
		
		_position = 0.f;
		_minValue = 0.f;
		_maxValue = 1.f;
		
		_outputMap = &linearOutputMap;
		_inputMap = &linearInputMap;
	
		this.addHandler(&this.handleMouseEnter);
		this.addHandler(&this.handleMouseLeave);
	}
	
	
	protected final float linearInputMap(float f) {
		return (f - _minValue) / (_maxValue - _minValue);
	}
	

	protected final float linearOutputMap(float f) {
		return f * (_maxValue - _minValue) + _minValue;
	}

	
	protected {
		alias .WidgetSlider!(horizontal) WidgetSlider;
		
		WidgetSlider	_wslider;
		float			_position;
		float			_snapDelta = 0;
	}
	
	protected void snap(float pos) {
		// TODO
		//position(_outputMap(pos));
		
		// digited: at least enable user callbacks (may be improved to events later
		// TODO : do something with this temp code
		if(onSlide)
			_onSlide(_wslider.fraction);
	}
	
	typeof(this) position(float f) {
		if (_inputMap !is null) {
			f = _inputMap(f);
		}
		
		_position = max(0.f, min(1.f, f));
		
		static if (horizontal) {
			_wslider.position = _position * (1.f - _wslider.handleSize);
		} else {
			_wslider.position = (1.f - _position) * (1.f - _wslider.handleSize);
		}
		return this;
	}	
	
	
	float position() {
		float wsiz = (1.f - _wslider.handleSize);
		if (wsiz > 0.f) {
			static if (horizontal) {
				_position = _wslider.position / wsiz;
			} else {
				_position = 1.f - _wslider.position / wsiz;
			}
		}
		return _outputMap is null ? _position : _outputMap(_position);
	}


	protected EventHandling handleMouseEnter(MouseEnterEvent e) {
		enableStyle("hover");
		return EventHandling.Continue;
	}
	
	protected EventHandling handleMouseLeave(MouseLeaveEvent e) {
		disableStyle("hover");
		return EventHandling.Continue;
	}


	bool changed() {
		return _wslider.changed;
	}
	
	mixin(defineProperties("float position, inline float minValue, inline float maxValue, inline float snapIncrement, inline float delegate(float) outputMap, inline float delegate(float) inputMap, inline void delegate(float) onSlide"));
	mixin MWidget;
}


/**
	Horizontal slider
*/
alias Slider!(true)	HSlider;

/**
	Vertical slider
*/
alias Slider!(false)	VSlider;
