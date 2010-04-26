module xf.hybrid.Event;

private {
	import xf.hybrid.GuiRenderer;
	import xf.input.KeySym;
	import xf.input.Input;

	import xf.omg.core.LinearAlgebra;
}


alias xf.input.Input.MouseInput.Button MouseButton;


/**
	Base event class
*/
abstract class Event {
	bool	sinking;		///
	bool	handled;	///
	
	///
	final bool bubbling() {
		return !sinking;
	}
	
	///
	final void bubbling(bool b) {
		sinking = !b;
	}
}


/**
	Determines whether sinking and bubbling should continue after a given widget has handled an event
*/
enum EventHandling {
	Stop,		///
	Continue	///
}


/**
	Base class for all mouse events
*/
class MouseEvent : Event {
}


/**
*/
class MouseMoveEvent : MouseEvent {
	vec2 pos;			/// position relative to the widget
	vec2 delta;		/// change in position
	vec2 rootPos;	/// position relative to the root of the display within the OS
}


private template MOneButtonState() {
	/// button index
	MouseButton button() {
		return _button;
	}
	
	/// ditto
	void button(MouseButton btn)
	in {
		bool found = false;
		for (int i = 0; (1 << i) <= MouseButton.max; ++i) {
			if ((1 << i) & btn) {
				assert (!found, "multiple MouseButton values not allowed here");
				found = true;
			}
		}
		assert (found, "empty MouseButton not allowed here");
	}
	body {
		_button = btn;
	}

	private MouseButton _button;
}


/**
*/
class MouseButtonEvent : MouseEvent {
	vec2		pos;			/// position relative to the widget
	bool		down;		/// tells whether the button was pressed down or lifted up
	mixin	MOneButtonState;
}


/**
*/
class ClickEvent : MouseEvent {
	vec2		pos;			/// position relative to the widget
	mixin	MOneButtonState;
}


/**
	Tells the widget that the cursor has left its area
*/
class MouseLeaveEvent : MouseEvent {
}


/**
	Tells the widget that the cursor has entered its area
*/
class MouseEnterEvent : MouseEvent {
}


/**
	Keyboard key press/release event
*/
class KeyboardEvent : Event {
	/**enum Modifiers {
		NONE 	= 0x0000,
		LSHIFT	= 0x0001,
		RSHIFT	= 0x0002,
		LCTRL	= 0x0040,
		RCTRL	= 0x0080,
		LALT		= 0x0100,
		RALT		= 0x0200,
		LMETA	= 0x0400,
		RMETA	= 0x0800,
		NUM		= 0x1000,
		CAPS	= 0x2000,
		MODE	= 0x4000,
	
		CTRL	= LCTRL	|	RCTRL,
		SHIFT	= LSHIFT	|	RSHIFT,
		ALT		= LALT		|	RALT,
		META	= LMETA	|	RMETA
	}*/
	alias xf.input.Input.KeyboardInput.Modifiers Modifiers;

	KeySym	keySym;		///
	bool			down;			/// tells whether the key was pressed down or lifted up
	dchar		unicode;		/// printable representation of the key given by the OS; dchar.init when none was provided
	Modifiers	modifiers = Modifiers.NONE;	/// modifiers being held when the key was pressed / released
}


/**
	Tells a widget that it just lost keyboard focus
*/
class LoseFocusEvent : Event {
}


/**
	Tells a widget that it just gained keyboard focus
*/
class GainFocusEvent : Event {
}


///
class MinimizeLayoutEvent : Event {
}


///
class ExpandLayoutEvent : Event {
}


///
class CalcOffsetsEvent : Event {
}


///
class UpdateEvent : Event {
}


///
class RenderEvent : Event {
	GuiRenderer renderer;	///
}


///
class TimeUpdateEvent : Event {
	float delta;	///
	
	///
	this (float delta) {
		this.delta = delta;
	}
}
