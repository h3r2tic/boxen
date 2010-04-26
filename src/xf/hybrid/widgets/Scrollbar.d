module xf.hybrid.widgets.Scrollbar;

private {
	import tango.math.Math;

	import xf.hybrid.Common;
	import xf.hybrid.CustomWidget;
	import xf.hybrid.widgets.Button : GenericButton;
	import xf.hybrid.widgets.WidgetSlider : WidgetSlider;
}



/**
	Base class for HScrollbar and VScrollbar

	Properties:
	---
	// size of the handle, in the [0..1] range
	float handleSize
	
	// position of the upper part of the handle in the [0..1-handleSize] range
	float position
	
	// amount of space that should be skipped when clicking
	// above or below the scrollbar handle
	float skipSize
	
	// amount of space that should be skipped when clicking
	// the scrollbar buttons
	inline float smallSkipSize
	
	// parameters that control the exponential acceleration
	inline float repeatWait
	inline float repeatFactor
	inline float repeatAccel
	---
*/
class Scrollbar(bool horizontal) : CustomWidget {
	alias WidgetSlider!(horizontal) Slider;
	
	const bool vertical = !horizontal;
	const static char[] nameForWidgetRegistry = horizontal ? "HScrollbar" : "VScrollbar";
	
	
	protected EventHandling handleButton1Click(ClickEvent e) {
		if (e.bubbling && !e.handled && _repeatDt < _repeatWait) {
			_slider.position = _slider.position - _smallSkipSize;
			_repeatDt = 0;
			return EventHandling.Stop;
		}
		return EventHandling.Continue;
	}
	

	protected EventHandling handleButton2Click(ClickEvent e) {
		if (e.bubbling && !e.handled && _repeatDt < _repeatWait) {
			_slider.position = _slider.position + _smallSkipSize;
			_repeatDt = 0;
			return EventHandling.Stop;
		}
		return EventHandling.Continue;
	}


	// Provides continuous scrolling if button held (like keyboard repeat)
	override EventHandling handleTimeUpdate(TimeUpdateEvent e) {
		if(e.sinking) {
			if(_repeatDt == 0) {		// Initial state
				if(_button1.active)
					_repeatBtn1 = true;
				else if(_button2.active)
					_repeatBtn1 = false;
				else			// Nothing to do
					return super.handleTimeUpdate(e);
			} else if(!(_button1.active || _button2.active) ||
					  _repeatBtn1 != _button1.active) {
				// State change merits a reset
				_repeatDt = 0;
				return super.handleTimeUpdate(e);	
			}

			// Button is being held
			_repeatDt += e.delta;
			if(_repeatBtn1)
				_slider.position = _slider.position - (skipSize * pow(_repeatDt, _repeatAccel) * _repeatFactor);
			else
				_slider.position = _slider.position + (skipSize * pow(_repeatDt, _repeatAccel) * _repeatFactor);
			
			
		}
		return super.handleTimeUpdate(e);
	}

	
	this() {
		super();
		
		getAndRemoveSub("button1", &_button1);
		getAndRemoveSub("button2", &_button2);
		getAndRemoveSub("slider", &_slider);

		_smallSkipSize = .03f;
		_repeatWait = .1f;
		_repeatFactor = 2f;
		_repeatAccel = 2f;
		
		_button1.addHandler(&handleButton1Click);
		_button2.addHandler(&handleButton2Click);
	}
	
	
	protected {
		GenericButton	_button1;
		GenericButton	_button2;
		Slider			_slider;

		bool _repeatBtn1;
		float _repeatDt = 0.f;
	}
	
	mixin(defineProperties("float handleSize, float position, float fraction, float skipSize, inline float smallSkipSize, inline float repeatWait, inline float repeatFactor, inline float repeatAccel"));
	mixin MWidget;
}


/**
	Horizontal scrollbar
*/
alias Scrollbar!(true)	HScrollbar;


/**
	Vertical scrollbar
*/
alias Scrollbar!(false)	VScrollbar;


/**
	A button widget used by the scrollbars
	Properties:
	---
	// 0 -> right, 1 -> up, 2 -> left, 3 -> down
	int arrowDir
	---
*/
class ScrollbarButton : GenericButton {
	mixin MWidget;
	mixin(defineProperties("int arrowDir"));
}
