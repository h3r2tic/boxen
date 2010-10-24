module xf.hybrid.widgets.WidgetSlider;

private {
	import tango.math.Math;

	import xf.hybrid.Common;
	import xf.hybrid.CustomWidget;
	import xf.hybrid.model.Core;
	import tango.util.log.Trace;
}



class WidgetSlider(bool horizontal) : Widget {
	const bool vertical = !horizontal;
	const static char[] nameForWidgetRegistry = horizontal ? "HWidgetSlider" : "VWidgetSlider";
	
	
	override int children(int delegate(ref IWidget) dg) {
		IWidget w = _child;
		return _child is null || !_child.widgetEnabled ? 0 : dg(w);
	}


	override bool childrenGoAbove() {
		return false;
	}


	override typeof(this) removeChildren() {
		if (_child !is null) {
			_child.parent = null;
			_child = null;
		}
		return this;
	}
	
	
	override typeof(this) removeChild(IWidget w) {
		assert (cast(Widget)w is _child);
		_child.parent = null;
		_child = null;
		return this;
	}


	override protected typeof(this) addChild(IWidget w) {
		assert (_child is null);
		assert (cast(Widget)w !is null);
		_child = cast(Widget)w;
		_child.parent = this;
		return this;
	}


	override vec2 desiredSize() {
		return size;
	}
	
	
	private final float	v0(vec2 v)		{ return v.cell[horizontal ? 0 : 1]; }
	private final float	v1(vec2 v)		{ return v.cell[horizontal ? 1 : 0]; }
	private final float*	v0p(ref vec2 v)	{ return &v.cell[horizontal ? 0 : 1]; }
	private final float*	v1p(ref vec2 v)	{ return &v.cell[horizontal ? 1 : 0]; }


	override EventHandling handleMinimizeLayout(MinimizeLayoutEvent e) {
		vec2 ms = userSize;
		
		if (_child !is null) {
			*v1p(ms) = v1(_child.desiredSize);
		}
		
		this.overrideSizeForFrame(ms);
		return EventHandling.Continue;
	}


	override EventHandling handleExpandLayout(ExpandLayoutEvent e) {
		if (e.sinking) {
			if (_child !is null) {
				float frac = fraction();
				
				vec2 po = vec2.zero;
				*v0p(po) = _position * v0(this.size);
				_child.parentOffset = po;
				//Trace.formatln("this.size = {}; child.parentOffset = {}", this.size, _child.parentOffset);
				
				vec2 s = _child.desiredSize;
				*v0p(s) = max(_handleSize * v0(this.size), v0(s));
				_child.overrideSizeForFrame(s);
				
				if (0 == v0(this.size)) {
					_realHandleSize = 0.f;
				} else {
					_realHandleSize = v0(s) / v0(this.size);
				}

				fraction = frac;
			}
		}
		return EventHandling.Continue;
	}
	

	bool globalHandleMouseButton(MouseButtonEvent e) {
		if (MouseButton.Left == e.button) {
			_repeatDt = 0;
			_repeating = false;
			if (!e.down) {
				_dragging = false;
				return true;
			}
		}
		return false;
	}

	
	EventHandling handleMouseButton(MouseButtonEvent e) {
		if (MouseButton.Left == e.button && e.bubbling && !e.handled) {
			if (v0(this.size) > 0) {
				vec2 mpoint = e.pos;
				float mpos = v0(mpoint) / v0(this.size);

				if (e.down) {
					gui.addGlobalHandler(&this.globalHandleMouseButton);

					float oldPos = _position;
					if (mpos < _position) {
						if(skip)
							position(mpos - (_realHandleSize/2.f));
						else {
							position(_position - _skipSize);
							_repeatDirNeg = true;
							_repeating = true;
						}
					} else if (mpos > _position + _realHandleSize) {
						if(skip)
							position(mpos - (_realHandleSize/2.f));
						else {
							position(_position + _skipSize);
							_repeatDirNeg = false;
							_repeating = true;
						}
					} else {
						_dragging = true;
						_dragPos = (mpos - _position) / _realHandleSize;
					}
					if(onSlide)
						_onSlide(_position);
				}
			}
			
			return EventHandling.Stop;
		} else {
			return EventHandling.Continue;
		}
	}
	
	
	EventHandling handleMouseMove(MouseMoveEvent e) {
		if (_dragging) {
			float mpos = v0(e.pos) / v0(this.size);

			float prevP = _position;
			_position = (mpos - _realHandleSize * _dragPos);
			if (_position < 0.f) {
				_position = 0.f;
			}
			if (_position + _realHandleSize > 1.f) {
				_position = 1.f - _realHandleSize;
			}

			if (prevP != _position) {
				_changed = true;
			}

			if(onSlide)
				_onSlide(_position);
		}		
		return EventHandling.Continue;
	}
	

	EventHandling handleClick(ClickEvent e) {
		if (e.bubbling && !e.handled) {
			return EventHandling.Stop;
		} else {
			return EventHandling.Continue;
		}
	}


	override EventHandling handleTimeUpdate(TimeUpdateEvent e) {
		if(skip)
			return super.handleTimeUpdate(e);
		
		if(_repeating && e.sinking) {
			float prevP = _position;
			
			_repeatDt += e.delta;
			if(_repeatDt < _repeatInterval)
				return super.handleTimeUpdate(e);
			
			float delta = _skipSize * (_repeatDt / _repeatInterval);
			_repeatDt = 0;
			if(_repeatDirNeg)
				if(_position - delta < 0.f)
					_position = 0.f;
				else
					_position -= delta;
			else
				if(_position + delta + _realHandleSize > 1.f)
					_position = 1.f - _realHandleSize;
				else
					_position += delta;

			if (prevP != _position) {
				_changed = true;
			}
					
			if(onSlide)
				_onSlide(_position);
		}
		return super.handleTimeUpdate(e);
	}



	override void onGuiStructureBuilt() {
		this._changed = false;
		super.onGuiStructureBuilt();
	}


	bool changed() {
		return _changed;
	}


	this() {
		_handleSize = 0.f;
		_position = 0.f;
		_skipSize = .1f;
		addHandler(&handleMouseButton);
		addHandler(&handleMouseMove);
		addHandler(&handleClick);

		_repeatInterval = .2f;

		_skip = true;
	}

	
	protected {
		Widget	_child;
		float	_realHandleSize = 0.f;
		float	_handleSize;
		bool	_dragging;
		float	_dragPos;
		float	_position;
		bool	_changed = false;

		bool _repeating, _repeatDirNeg;
		float _repeatDt = 0.f;
	}
	
	
	typeof(this) position(float f) {
		float prevP = _position;
		_position = f;
		if (_position < 0.f) {
			_position = 0.f;
		}
		if (_position + _realHandleSize > 1.f) {
			_position = 1.f - _realHandleSize;
		}
		if (prevP != _position) {
			_changed = true;
		}
		return this;
	}
	
	
	float position() {
		return _position;
	}
	
	typeof(this) fraction(float f) {
		if (f >= 1.f) {
			position = 1.f; // will be ajusted in checks
		} else if (f <= 0.f) {
			position = 0.f;
		} else {
			float prevP = _position;
			_position = f * (1.f - _realHandleSize);
			if (prevP != _position) {
				_changed = true;
			}
		}
		
		return this;
	}

	float fraction() {
		return _position / (1.f - _realHandleSize);
	}
	
	
	float handleSize() {
		return _realHandleSize;
	}
	
	typeof(this) handleSize(float f) {
		if (_handleSize != f) {
			_changed = true;
		}
		_handleSize = f;
		return this;
	}


	mixin(defineProperties("float handleSize, float position, float fraction, inline float skipSize, inline float repeatInterval, inline bool skip, inline void delegate(float) onSlide"));
	mixin MWidget;
}


alias WidgetSlider!(true)	HWidgetSlider;
alias WidgetSlider!(false)	VWidgetSlider; 
