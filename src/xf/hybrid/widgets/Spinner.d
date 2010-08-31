module xf.hybrid.widgets.Spinner;

private {
	import tango.core.Traits;

	import xf.Common;
	import xf.hybrid.Common;
	import xf.hybrid.CustomWidget;
	import xf.hybrid.widgets.Button : GenericButton;
	import xf.hybrid.widgets.InputArea : InputArea;
	import xf.input.KeySym;
	import xf.omg.core.Misc;
	import xf.omg.core.Algebra;

	import xf.utils.Meta;
	
	import tango.util.Convert : to;
	import tango.util.log.Trace;
}



/**
	The tiny up/down arrow button used in Spinners
*/
class SpinnerButton : GenericButton {
	mixin MWidget;
}



/**
	A widget template capable of manipulating pretty much any numeric value using buttons
	for increasing and decreasing the value
	Properties:
	---
	T value
	inline T min
	inline T max
	
	inline float repeatWait
	inline float repeatFactor
	inline float repeatAccel
	inline T baseIncrement
	inline float scaleAccel
	---
*/
class Spinner(T) : CustomWidget {
	const static char[] nameForWidgetRegistry
		= cast(char)toUpperASCII(T.stringof[0]) ~ T.stringof[1..$] ~ "Spinner";


	protected override char[] configCustomWidgetName() {
		return "Spinner";
	}


	EventHandling handleButton1Click(ClickEvent e) {
		if (e.bubbling && !e.handled && _repeatDt < _maxClickDelay) {
			_changeValue(-_baseIncrement);
			_repeatDt = 0;
			return EventHandling.Stop;
		}
		return EventHandling.Continue;
	}
	

	EventHandling handleButton2Click(ClickEvent e) {
		if (e.bubbling && !e.handled && _repeatDt < _maxClickDelay) {
			_changeValue(_baseIncrement);
			_repeatDt = 0;
			return EventHandling.Stop;
		}
		return EventHandling.Continue;
	}


	// Provides continuous scrolling if button held (like keyboard repeat)
	override EventHandling handleTimeUpdate(TimeUpdateEvent e) {
		if(e.sinking) {
			if(_repeatDt == 0.f) {
				if(_button1.active || _keyUp)
					_repeatDown = true;
				else if(_button2.active || _keyDown)
					_repeatDown = false;
				else {// Repeat should not happen
					_repeatDt = 0.f;
					return super.handleTimeUpdate(e);
				}
			} else
				if((_repeatDown != (_button1.active || _keyUp)) ||
				   (_repeatDown == (_button2.active || _keyDown))) {
					_repeatDt = 0.f;
					return super.handleTimeUpdate(e);
				}
			
			// Button is being held
			_repeatDt += e.delta;
			if(_repeatDt >= _repeatWait) {
				float delta = _repeatFactor * (1.f + _scaleAccel * abs(cast(real)(_value))) * (pow(_repeatDt, _repeatAccel) * _baseIncrement);
				if (_repeatDown) {
					_changeValue(scalar!(T)(-delta));
				} else {
					_changeValue(scalar!(T)(delta));
				}
			}
		}
		
		return super.handleTimeUpdate(e);
	}

	
	EventHandling handleKey(KeyboardEvent e) {
		if(e.bubbling) {
			switch(e.keySym) {
			case KeySym.Up:
				_keyDown = e.down;
				if(_keyDown && _repeatDt < _repeatWait)
					_changeValue(+_baseIncrement);
				break;
			case KeySym.Down:
				_keyUp = e.down;
				if(_keyUp && _repeatDt < _repeatWait)
					_changeValue(-_baseIncrement);
				break;
			default:
				break;
			}
			return EventHandling.Stop;
		}
		return EventHandling.Continue;
	}
	
	void _changeValue(T delta) {
		_value += delta;
		if (_value < min || _value > max) {
			_value -= delta;
		} else {
			foreach (h; onSpin) {
				h(delta);
			}
		}
	}


	this() {
		getAndRemoveSub("button1", &_button1);
		getAndRemoveSub("button2", &_button2);

		addHandler(&handleKey);

		_button1.addHandler(&handleButton1Click);
		_button2.addHandler(&handleButton2Click);
		
		static if(isFloatingPointType!(T)) {
			_min = -T.max;
			_value = 0.0;
		} else {
			_min = T.min;
		}
		_max = T.max;

		_repeatWait = .1f;
		_repeatFactor = 3f;
		_repeatAccel = 1.5f;

		static if (isFloatingPointType!(T)) {
			_baseIncrement = .01f;
			_scaleAccel = .02f;
		} else {
			T inc;
			_baseIncrement = ++inc;
			_scaleAccel = .0002f;
		}
	}
	
	
	typeof(this) value(T v) {
		T delta = v - this._value;
		this._value = v;
		foreach (h; onSpin) {
			h(delta);
		}
		return this;
	}
	
	
	T value() {
		return _value;
	}


	public {
		void delegate(T delta)[] onSpin;
	}
	
	
	protected {
		GenericButton _button1;
		GenericButton _button2;

		bool	_keyDown, _keyUp;
		bool	_repeatDown;
		float	_repeatDt = 0.f;
		float	_maxClickDelay = .3f;
		T		_value;
	}


	mixin(defineProperties(
			  "T value, inline T min, inline T max, inline float repeatWait,"
			  "inline float repeatFactor, inline float repeatAccel, inline T baseIncrement, inline float scaleAccel"
			  ));
	mixin MWidget;
}


/**
	The basic instances of the Spinner widget template
*/
alias Spinner!(ubyte)		UbyteSpinner;
alias Spinner!(int)			IntSpinner;		/// ditto
alias Spinner!(float)		FloatSpinner;		/// ditto
alias Spinner!(double)	DoubleSpinner;	/// ditto



/**
	A widget template which combines a text input area and a Spinner widget template instance.
	It allows for more ways to input and manipulate the data. The value may be entered verbatim
	into the text field, but also manipulated using the Up and Down arrow keys
	Properties:
	---
	T value
	---
*/
class InputSpinner(T) : CustomWidget {
	const static char[] nameForWidgetRegistry
		= cast(char)toUpperASCII(T.stringof[0]) ~ T.stringof[1..$] ~ "InputSpinner";


	protected override char[] configCustomWidgetName() {
		return "InputSpinner";
	}
	

	override char[] getTypeForAlias(char[] name) {
		if ("Spinner" == name) {
			return cast(char)toUpperASCII(T.stringof[0]) ~ T.stringof[1..$] ~ "Spinner";
		}
		return super.getTypeForAlias(name);
	}
	
	
	protected void onSpin(T delta) {
		try {
			_input.text = to!(char[])(_spinner.value);
		} catch {}
	}
	

	protected EventHandling handleKey(KeyboardEvent e) {
		_spinner.handleEvent(e);
				
		if (KeySym.Return == e.keySym) {
			return EventHandling.Stop;
		}
		
		if (!e.bubbling) {
			return EventHandling.Continue;
		}

		if(_input.text.length)
			try {
				T newval = to!(T)(_input.text);
				if (newval >= _spinner.min && newval <= _spinner.max) {
					_spinner._value = newval;
				} else {
					_input.text = to!(char[])(_spinner.value);
				}
			} catch {
				try {
					_input.text = to!(char[])(_spinner.value);
				} catch {}
			}
		
		return EventHandling.Stop;
	}

	
	this() {
		getAndRemoveSub("spinner", &_spinner);
		getAndRemoveSub("input", &_input);
		_spinner.onSpin ~= &this.onSpin;
		addHandler(&handleKey);
	}
	
	
	protected {
		Spinner!(T)	_spinner;
		InputArea		_input;
	}


	mixin(defineProperties("T value"));
	mixin MWidget;
}


/**
	The basic instances of the InputSpinner widget template
*/
alias InputSpinner!(ubyte)	UbyteInputSpinner;
alias InputSpinner!(int)	IntInputSpinner;		/// ditto
alias InputSpinner!(float)	FloatInputSpinner;		/// ditto
alias InputSpinner!(double)	DoubleInputSpinner;	/// ditto
