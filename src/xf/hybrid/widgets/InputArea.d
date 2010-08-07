module xf.hybrid.widgets.InputArea;

private {
	import xf.hybrid.Common;
	import xf.hybrid.CustomWidget;
	import xf.hybrid.Font : Font, Glyph;
	import xf.hybrid.GuiRenderer;
	import xf.hybrid.Shape;
	import xf.hybrid.Style;
	
	import xf.input.KeySym : KeySym;
	static import xf.input.Input;
	
	import Unicode = tango.text.Unicode;
	
	alias xf.input.Input.KeyboardInput.Modifiers	Modifiers;
}



/**
	A generic text input widget with a blinking caret, selection and special key handling
	Properties:
	---
	char[] text
	inline Font font
	char[] fontFace
	int fontSize
	inline out bool hasFocus
	---
*/
class InputArea : Widget {
	typeof(this) fontFace(char[] s) {
		font = Font(_fontFace = s, fontSize);
		return this;
	}
	
	
	char[] fontFace() {
		return _fontFace;
	}
	
	
	typeof(this) fontSize(int s) {
		font = Font(fontFace, _fontSize = s);
		return this;
	}
	
	
	int fontSize() {
		return _fontSize;
	}


	this() {
		font = Font(_fontFace = `verdana.ttf`, _fontSize = 13);
		this.addHandler(&this.handleClick);
		this.addHandler(&this.handleKey);
		this.addHandler(&this.handleTimeUpdate);
		this.addHandler(&this.handleLoseFocus);
		this.addHandler(&this.handleGainFocus);
	}
	
	
	override vec2 minSize() {
		assert (font !is null);
		return vec2(0, font.lineSkip);
	}


	/**
		A representation of text selection; if from == to, nothing is selected
	*/
	struct SelectionRange {
		int from;		/// first index
		int to;			/// last index + 1
	}
	
	
	/**
		Return the current selection
	*/
	SelectionRange selectionRange() {
		if (_selectionLimit < _caretPos) {
			return SelectionRange(_selectionLimit, _caretPos);
		} else {
			return SelectionRange(_caretPos, _selectionLimit);
		}
	}
	
	
	/**
		Tells whether any text is selected
	*/
	bool anythingSelected() {
		auto selRange = selectionRange;
		return selRange.from < selRange.to;
	}
	
	
	/**
		Enters selection mode. Moving the caret will select text
	*/
	void startSelection() {
		_selecting = true;
	}
	

	/**
		Stops selection mode, doesn't deselect anything
	*/
	void stopSelection() {
		_selecting = false;
	}
	
	
	/**
		Tells whether the widget is in selection mode
	*/
	bool selecting() {
		return _selecting;
	}

	
	/**
		Deselects any text selected, doesn't exit selection mode
	*/
	void deselect() {
		_selectionLimit = _caretPos;
	}
	
	
	char[] text() {
		return convertToUtf8();
	}
	
	
	typeof(this) text(char[] t) {
		setFromUtf8(t);
		return this;
	}


	protected EventHandling handleClick(ClickEvent e) {
		if (e.bubbling && !e.handled) {
			if (_ignoreNextClick) {
				_ignoreNextClick = false;
			} else {
				recalcVisible();
				
				int newPos = _visibleFrom;
				
				assert (font !is null);
				font.layoutText(_text[_visibleFrom .. _visibleTo], (int charIndex, dchar c, vec2 pen, inout Glyph g) {
					if (e.pos.x > rndint(pen.x + g.advance.x / 2)) {
						newPos = _visibleFrom + charIndex + 1;
					}
				});			
				moveCaret(newPos);
			}
				
			return EventHandling.Stop;
		}
		return EventHandling.Continue;
	}
	
	
	override void render(GuiRenderer r) {
		assert (font !is null);
		recalcVisible();
		
		r.applyStyle(null);		// reset any settings
		r.flushStyleSettings();
		
		Style style = this.style;
		
		if (_visibleFrom != _visibleTo) {
			if (style.color.available) {
				r.color(*style.color.value);
			} else {
				r.color(vec4.one);
			}
			
			font.print(globalOffset, _text[_visibleFrom .. _visibleTo]);
		}

		if (anythingSelected) {
			auto selRange = selectionRange();
			if (selRange.from < _visibleTo && selRange.to > _visibleFrom) {
				if (style.textInput.available) {
					r.color(style.textInput.value.selectionBgColor);
				} else {
					r.color(vec4(1, 1, 1, .5f));
				}
				
				float selMinX, selMaxX;
				
				if (selRange.from <= _visibleFrom) {
					selMinX = 0.f;
				} else {
					selMinX = font.width(_text[_visibleFrom .. selRange.from]);
				}
				
				if (selRange.to >= _visibleTo) {
					selMaxX = min(this.size.x, font.width(_text[_visibleFrom .. selRange.to]));
				} else {
					selMaxX = font.width(_text[_visibleFrom .. selRange.to]);
				}

				r.rect(Rect(vec2(selMinX, 0), vec2(selMaxX, this.size.y)));
			}
		}
		
		if (shouldDrawCaret) {
			float caretX = font.width(_text[_visibleFrom .. _caretPos]);

			r.disableTexturing();
			if (style.textInput.available) {
				r.color(style.textInput.value.caretColor);
			} else {
				r.color(vec4(1, 0, 0, 1));
			}
			
			r.rect(Rect(vec2(caretX, 0), vec2(caretX+_caretWidth, size.y)));
		}
	}
	
	
	private int spaceForCaret() {
		if (_caretPos == _visibleTo) {
			return _caretWidth;
		} else {
			return 0;
		}
	}
	
	
	protected void makeRoomRight() {
		int maxWidth = cast(int)(this.size.x * shiftRoomSpace);
		_visibleTo = _caretPos;
		
		assert (font !is null);
		font.layoutText(_text[_caretPos .. $], (int charIndex, dchar c, vec2 pen, inout Glyph g) {
			if (rndint(pen.x + g.advance.x) + spaceForCaret <= maxWidth) {
				_visibleTo = _caretPos + charIndex + 1;
			}
		});
		
		expandLeftVisibleEdge();
	}
	
	
	protected void makeRoomLeft() {
		int maxWidth = cast(int)(this.size.x * shiftRoomSpace);
		
		assert (font !is null);
		int leftStrWidth = font.width(_text[0 .. _caretPos]);
		if (leftStrWidth + _caretWidth <= maxWidth) {
			_visibleFrom = 0;
		} else {
			font.layoutText(_text[0 .. _caretPos], (int charIndex, dchar c, vec2 pen, inout Glyph g) {
				if (leftStrWidth - rndint(pen.x) + spaceForCaret > maxWidth) {
					_visibleFrom = charIndex + 1;
				}
			});
		}
		
		expandRightVisibleEdge();
	}
	
	
	/**
		Moves the caret ahead of char at index pos
	*/
	void moveCaret(int pos) {
		_caretPos = min(max(0, pos), _text.length);
		
		if (!selecting) {
			_selectionLimit = _caretPos;
		}
		
		if (pos >= _visibleTo) {
			makeRoomRight();
		} else if (pos <= _visibleFrom) {
			makeRoomLeft();
		}
	}
	
	
	/**
		Moves the caret by one char to the left
	*/
	void moveCaretLeft() {
		moveCaret(_caretPos - 1);
	}
	
	
	/**
		Moves the caret by one char to the right
	*/
	void moveCaretRight() {
		moveCaret(_caretPos + 1);
	}
	
	
	protected {
		void recalcVisible() {
			if (_sizeChanged) {
				_sizeChanged = false;
				int sel = _selectionLimit;
				moveCaret(_caretPos);
				_selectionLimit = sel;
				expandRightVisibleEdge();
			}
		}
		
		override void onSizeChanged() {
			this._sizeChanged = true;
		}

		char[] convertToUtf8() {
			_utf8Buffer.length = 0;
			foreach (char ch; _text) {
				_utf8Buffer ~= ch;
			}
			return _utf8Buffer;
		}
		
		void setFromUtf8(char[] t) {
			_text.length = 0;
			foreach (dchar ch; t) {
				_text ~= ch;
			}
			onTextReset();
		}
		
		void onTextReset() {
			_selectionLimit = _caretPos = 0;
			_selecting = false;
			_visibleFrom = 0;
			_visibleTo = 0;
			expandRightVisibleEdge();
		}
		
		void expandLeftVisibleEdge() {
			_visibleFrom = 0;

			assert (font !is null);
			int leftStrWidth = font.width(_text[0 .. _visibleTo]);
			if (leftStrWidth > size.x) {
				font.layoutText(_text[0 .. _visibleTo], (int charIndex, dchar c, vec2 pen, inout Glyph g) {
					if (leftStrWidth - rndint(pen.x) + spaceForCaret > size.x) {
						_visibleFrom = charIndex + 1;
					}
				});
			}
		}

		void expandRightVisibleEdge() {
			_visibleTo = _visibleFrom;
			
			assert (font !is null);
			font.layoutText(_text[_visibleFrom .. $], (int charIndex, dchar c, vec2 pen, inout Glyph g) {
				int maxW = rndint(pen.x + g.advance.x);
				if (maxW + spaceForCaret <= this.size.x) {
					_visibleTo = _visibleFrom+charIndex+1;
				}
			});
		}
	}
	
	
	protected {
		char[]	_fontFace;
		int		_fontSize;

		dchar[]	_text;
		int		_caretPos = 0;	// it sits before a dchar with this index
		int		_selectionLimit = 0;	
		bool		_selecting;
		
		bool		_sizeChanged;
		
		int		_caretWidth = 1;
		
		int		_visibleFrom;
		int		_visibleTo;
		
		const float shiftRoomSpace = .3f;
		
		
		
		
		struct Key {
			KeySym	keySym;
			dchar		unicode;
			Modifiers	modifiers = Modifiers.NONE;
		}
		
		Key	_heldKey;
		float	_keyHoldTime;
		float	_timeSinceKeyRepeat;
		
		static float	_keyRepeatFreq		= 20.f;
		static float	_keyRepeatDelay	= 0.5f;
		
		float	_timeSinceCaretBlink = 0.f;
		//bool	_hasFocus = false;
		bool	_caretBlinkOn = true;
		
		bool _ignoreNextClick;
	}


	protected EventHandling handleTimeUpdate(TimeUpdateEvent e) {
		if (e.bubbling) {
			_updateTime(e.delta);
		}
		return super.handleTimeUpdate(e);
	}
	
	
	protected float caretBlinkFreq() {
		if (style.textInput.available) {
			return style.textInput.value.caretBlinkFreq;
		} else {
			return 10.f;
		}
	}
	
	
	protected void setCaretBlinkOn() {
		_caretBlinkOn = true;
		_timeSinceCaretBlink = 0.f;
	}
	
	
	protected bool shouldDrawCaret() {
		return _hasFocus && _caretBlinkOn;
	}
	
	
	protected void _updateTime(float delta) {
		if (_hasFocus) {
			_timeSinceCaretBlink += delta;
			if (_timeSinceCaretBlink >= 1.f / caretBlinkFreq) {
				_timeSinceCaretBlink = 0.f;
				_caretBlinkOn = !_caretBlinkOn;
			}
		}
		
		if (_keyHoldTime !<>= 0) {
			return;
		}
		
		_keyHoldTime += delta;
		if (_keyHoldTime >= _keyRepeatDelay) {
			_timeSinceKeyRepeat += _keyHoldTime - _keyRepeatDelay;
			_keyHoldTime = _keyRepeatDelay;
			
			float keyRepeatCycle = 1.f / _keyRepeatFreq;
			while (_timeSinceKeyRepeat >= keyRepeatCycle) {
				_timeSinceKeyRepeat -= keyRepeatCycle;
				_handleKey(_heldKey);
			}
		}
	}


	protected EventHandling handleKey(KeyboardEvent e) {
		if (!e.bubbling || e.handled) {
			return EventHandling.Continue;
		}
		
		auto key = Key(e.keySym, e.unicode, e.modifiers);
		
		if (e.down) {
			_heldKey = key;
			_keyHoldTime = 0.f;
			_timeSinceKeyRepeat = 0.f;
		} else if	(	(_heldKey.keySym == key.keySym && _heldKey.unicode == key.unicode)
					||	(_heldKey.modifiers != key.modifiers) )
		{
			_keyHoldTime = _timeSinceKeyRepeat = float.nan;
		}
		
		if (KeySym.Shift_L == e.keySym || KeySym.Shift_R == e.keySym) {
			if (e.down) {
				startSelection();
			} else {
				stopSelection();
			}
		}
		
		if (e.down) {
			_handleKey(key);
		}
		
		return EventHandling.Stop;
	}
	
	
	protected EventHandling handleLoseFocus(LoseFocusEvent e) {
		stopSelection();
		_keyHoldTime = _timeSinceKeyRepeat = float.nan;
		_hasFocus = false;
		_selectionLimit = _caretPos;
		return EventHandling.Continue;
	}
	

	protected EventHandling handleGainFocus(GainFocusEvent e) {
		_selectionLimit = 0;
		startSelection();
		moveCaret(_text.length);
		stopSelection();
		_ignoreNextClick = true;
		_hasFocus = true;
		return EventHandling.Continue;
	}
	
	
	protected void skipTokenSequence(int dir) {
		dchar atcaret() {
			switch (dir) {
				case 1: return _caretPos >= _text.length ? dchar.init : _text[_caretPos];
				case -1: return _caretPos == 0 ? dchar.init : _text[_caretPos-1];
				default: assert (false);
			}
		}
		
		void move() {
			switch (dir) {
				case 1: return moveCaretRight();
				case -1: return moveCaretLeft();
				default: assert (false);
			}
		}
		
		dchar firstc;
		if (dchar.init == (firstc = atcaret)) {
			move();		// skipTokenSequence should move at least once, e.g. to deselect
			return;
		}
		
		int classify(dchar c) {
			try {
				if (Unicode.isLetterOrDigit(c)) return 0;
				if (Unicode.isWhitespace(c)) return 1;
			} catch {}
			return c;
		}
		
		int prev = classify(firstc);
		int cur;
		dchar curchar;
		
		do {
			move();
			cur = classify(curchar = atcaret);
		} while (curchar != dchar.init && cur == prev);
	}

	
	protected void _handleKey(ref Key key) {
		void doSelection() {
			if (key.modifiers & Modifiers.SHIFT) {
				startSelection();
			} else {
				stopSelection();
			}
		}
		
		setCaretBlinkOn();
		
		switch (key.keySym) {
		case KeySym.b:
			if(key.modifiers & Modifiers.CTRL)
				moveCaretLeft();
			else if(key.modifiers & Modifiers.ALT)
				skipTokenSequence(-1);
			else
				goto default;
			
		case KeySym.Left: {
			doSelection();
			if (key.modifiers & Modifiers.CTRL ||
				key.modifiers & Modifiers.ALT) {
				skipTokenSequence(-1);
			} else {
				moveCaretLeft();
			}
		} break;

		case KeySym.f:
			if(key.modifiers & Modifiers.CTRL)
				moveCaretRight();
			else if(key.modifiers & Modifiers.ALT)
				skipTokenSequence(1);
			else
				goto default;
			
		case KeySym.Right: {
			doSelection();
			if (key.modifiers & Modifiers.CTRL ||
				key.modifiers & Modifiers.ALT) {
				skipTokenSequence(1);
			} else {
				moveCaretRight();
			}
		} break;

		case KeySym.d:
			if(!(key.modifiers & Modifiers.CTRL || key.modifiers & Modifiers.ALT))
				goto default;
		case KeySym.Delete: {
			if (!anythingSelected) {
				if(key.modifiers & Modifiers.ALT) {
					auto end = _caretPos;
					skipTokenSequence(1);
					_selectionLimit = end;
				}
				else
					_selectionLimit = min(_text.length, _caretPos+1);
			}
			deleteSelection();
		} break;

		case KeySym.BackSpace: {
			if (!anythingSelected) {
				if(key.modifiers & Modifiers.ALT) {
					auto end = _caretPos;
					skipTokenSequence(-1);
					_selectionLimit = end;
				}
				else
					_selectionLimit = max(0, _caretPos-1);
			}
			deleteSelection();
		} break;

		case KeySym.a:
			if(!(key.modifiers & Modifiers.CTRL))
				goto default;
		case KeySym.Home: {
			doSelection();
			moveCaret(0);
		} break;

		case KeySym.e:
			if(!(key.modifiers & Modifiers.CTRL))
				goto default;
		case KeySym.End: {
			doSelection();
			moveCaret(_text.length);
		} break;
		
		case KeySym.Return: {
			if(onEnter)
				_onEnter(this);
		} break;

		default: {
			if (key.unicode != dchar.init) {
				dchar[1] foo;
				foo[0] = key.unicode;
				insertTextAtCaret(foo);
				return;
			}
		} break;
		}
	}
	
	
	/**
		Works just like typing the text at the current caret position
	*/
	void insertTextAtCaret(dchar[] t) {
		stopSelection();
		
		if (anythingSelected) {
			deleteSelection();
		}
		
		_text = _text[0 .. _caretPos] ~ t ~ _text[_caretPos .. $];
		_selectionLimit = _caretPos = (_caretPos + t.length);
		
		if (_caretPos > _visibleTo) {
			_visibleTo = _caretPos;
			expandLeftVisibleEdge();
		} else {
			expandRightVisibleEdge();
		}
	}
	
	
	/**
		Deletes the current selection, updates caret pos and visibility ranges
	*/
	void deleteSelection() {
		auto range = selectionRange;
		stopSelection();
		
		bool recalcTo = false;
		if (range.from <= _visibleTo) {
			recalcTo = true;
		}
		
		bool recalcFrom = false;
		if (range.from < _visibleFrom) {
			recalcFrom = true;
		}
		
		_text = _text[0 .. range.from] ~ _text[range.to .. $];
		
		if (_caretPos > range.from) {
			if (_caretPos < range.to) {
				_caretPos = range.from;
			} else {
				_caretPos -= (range.to - range.from);
			}
		}
		
		moveCaret(_caretPos);
		
		if (recalcTo) {
			expandRightVisibleEdge();
		}
		
		if (recalcFrom) {
			expandLeftVisibleEdge();
		}
	}


	private {
		char[]	_utf8Buffer;
	}


	mixin(defineProperties("char[] text, inline Font font, char[] fontFace, int fontSize, inline out bool hasFocus, inline void delegate(InputArea) onEnter"));
	mixin MWidget;
}
