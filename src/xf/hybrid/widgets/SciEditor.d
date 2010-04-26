module xf.hybrid.widgets.SciEditor;

private {
	import xf.hybrid.Common;
	import xf.hybrid.Font;
	import xf.hybrid.GuiRenderer;
	import xf.hybrid.Scintilla;
	
	import xf.input.KeySym;

	import tango.stdc.stdlib : malloc, free;
	import tango.stdc.stdio : printf;
	import tango.stdc.stringz;
	import tango.text.convert.Format;
	
	import tango.core.Memory;
	import tango.time.StopWatch;

	alias KeyboardEvent.Modifiers Modifiers;
}



class SciEditor : Widget {
	mixin MWidget;
	
	HybridEditor		sci;
	HybridSurface	surf;
	StopWatch			stopWatch;
	
	
	
	typeof(this) insertText(char[] t, uint pos = 0) {
		char* cstr = cast(char*)malloc(t.length+1);
		if (cstr !is null) {
			cstr[0..t.length] = t[];
			cstr[t.length] = 0;
			sci.WndProc(SCI_INSERTTEXT, pos, cast(size_t)cstr);
			free(cstr);
		}
		return this;
	}
	
	
	typeof(this) text(char[] t) {
		char* cstr = cast(char*)malloc(t.length+1);
		if (cstr !is null) {
			cstr[0..t.length] = t[];
			cstr[t.length] = 0;
			sci.WndProc(SCI_SETTEXT, 0, cast(size_t)cstr);
			free(cstr);
		}
		return this;
	}
	

	char[] text() {
		size_t	len	= sci.WndProc(SCI_GETTEXTLENGTH, 0, 0);
		char[]	buf	= new char[len+1];
		sci.WndProc(SCI_GETTEXT, len+1, cast(size_t)buf.ptr);
		return	buf[0..$-1];
	}
	
	
	typeof(this) line(int l) {
		sci.WndProc(SCI_SETYCARETPOLICY, CARET_JUMPS, 1);
		sci.WndProc(SCI_SETYCARETPOLICY, CARET_EVEN, 1);
		sci.WndProc(SCI_SETYCARETPOLICY, CARET_STRICT, 0);
		sci.WndProc(SCI_SETYCARETPOLICY, CARET_SLOP, 0);
		sci.WndProc(SCI_GOTOLINE, l, 0);
		return this;
	}

	
	this() {
		stopWatch.start();
		
		bindScintilla!(HybridEditor, HybridSurface, int)("SciLexer.dll");

		sci = new HybridEditor;
		surf = HybridSurface.intrusivePooledAlloc(true);
		
		sci.WndProc(SCI_STYLESETFONT, 0, cast(size_t)"verdana".ptr);
		sci.WndProc(SCI_STYLESETSIZE, 0, 11);

		sci.WndProc(SCI_SETMARGINTYPEN, 0, SC_MARGIN_NUMBER);
		sci.WndProc(SCI_SETMARGINWIDTHN, 0, 30);
		sci.WndProc(SCI_SETMARGINWIDTHN, 1, 10);

		sci.WndProc(SCI_SETMARGINWIDTHN, 2, 0);
		sci.WndProc(SCI_SETMARGINWIDTHN, 3, 0);
		

		/+char[] text = import("Scintilla.d");

		sci.WndProc(SCI_INSERTTEXT, 0, cast(uint)text.ptr);+/
		sci.WndProc(SCI_SETCARETFORE, 0xf0e080, 0);
		
		sci.WndProc(SCI_SETTABWIDTH, 4, 0);
		sci.WndProc(SCI_SETUSETABS, 1, 0);
		
		addHandler(&handleKey);
		addHandler(&handleMouseButton);
		addHandler(&handleMouseMove);
		addHandler(&handleGainFocus);
		addHandler(&handleLoseFocus);

		setupColors();
	}
	
	
	protected void setupColors() {
		static const char keywords0[] = `export extern align pragma deprecated override package private protected public final static abstract const auto ref `;
		static const char keywords1[] = `alias class delegate enum function interface struct template typedef bool byte cent char cfloat cdouble creal dchar double float idouble ifloat int ireal long real short ubyte ucent uint ulong ushort wchar void macro `;
		static const char keywords2[] = `false true null asm assert body break case cast catch continue debug default delete do else finally for foreach goto if import in inout invariant is mixin module new out return scope super switch synchronized this throw try typeid typeof union unittest version volatile while with foreach_reverse ref`;

		sci.WndProc( SCI_SETLEXER, SCLEX_D, 0);
		assert (SCLEX_D == sci.WndProc(SCI_GETLEXER, 0, 0));
		
		sci.WndProc(SCI_SETSTYLEBITS, 5, 0);

		sci.WndProc(SCI_STYLESETFORE, STYLE_DEFAULT, 0xFFFFFF);
		sci.WndProc(SCI_STYLESETBACK, STYLE_DEFAULT, 0x2D2D2D);
		sci.WndProc(SCI_STYLECLEARALL, 0, 0);

		sci.WndProc(SCI_STYLESETFORE, STYLE_LINENUMBER, 0xB0B0B0);
		sci.WndProc(SCI_STYLESETBACK, STYLE_LINENUMBER, 0x383838/*0x202020*/);
		
		sci.WndProc(SCI_STYLESETFORE, SCE_D_DEFAULT, 0xFFFFFF);
		sci.WndProc(SCI_STYLESETBACK, SCE_D_DEFAULT, 0x2D2D2D);

		sci.WndProc(SCI_STYLESETFORE, SCE_D_COMMENT, 0x666666);
		sci.WndProc(SCI_STYLESETBACK, SCE_D_COMMENT, 0x2D2D2D);
		
		sci.WndProc(SCI_STYLESETFORE, SCE_D_COMMENTLINE, 0x606060);
		sci.WndProc(SCI_STYLESETBACK, SCE_D_COMMENTLINE, 0x2D2D2D);

		sci.WndProc(SCI_STYLESETFORE, SCE_D_COMMENTDOC, 0x3F703F);
		sci.WndProc(SCI_STYLESETBACK, SCE_D_COMMENTDOC, 0x2D2D2D);

		sci.WndProc(SCI_STYLESETFORE, SCE_D_COMMENTNESTED, 0x484848);
		sci.WndProc(SCI_STYLESETBACK, SCE_D_COMMENTNESTED, 0x2D2D2D);

		sci.WndProc(SCI_STYLESETFORE, SCE_D_NUMBER, 0xD37CAE);
		sci.WndProc(SCI_STYLESETBACK, SCE_D_NUMBER, 0x2D2D2D);
		
		sci.WndProc(SCI_STYLESETFORE, SCE_D_WORD, 0x91BAC8);
		sci.WndProc(SCI_STYLESETBACK, SCE_D_WORD, 0x2D2D2D);

		sci.WndProc(SCI_STYLESETFORE, SCE_D_WORD2, 0xE9DB8B);
		sci.WndProc(SCI_STYLESETBACK, SCE_D_WORD2, 0x2D2D2D);

		sci.WndProc(SCI_STYLESETFORE, SCE_D_TYPEDEF, 0x84E893);
		sci.WndProc(SCI_STYLESETBACK, SCE_D_TYPEDEF, 0x2D2D2D);

		sci.WndProc(SCI_STYLESETFORE, SCE_D_STRING, 0x8ECF47);
		sci.WndProc(SCI_STYLESETBACK, SCE_D_STRING, 0x2D2D2D);

		sci.WndProc(SCI_STYLESETFORE, SCE_D_CHARACTER, 0x00FFFF);
		sci.WndProc(SCI_STYLESETBACK, SCE_D_CHARACTER, 0x2D2D2D);

		sci.WndProc(SCI_STYLESETFORE, SCE_D_OPERATOR, 0xB4F1EB);
		sci.WndProc(SCI_STYLESETBACK, SCE_D_OPERATOR, 0x2D2D2D);

		sci.WndProc(SCI_STYLESETFORE, SCE_D_IDENTIFIER, 0xFFFFFF);
		sci.WndProc(SCI_STYLESETBACK, SCE_D_IDENTIFIER, 0x2D2D2D);

		sci.WndProc(SCI_SETKEYWORDS, 0, cast(size_t)keywords0.ptr);
		sci.WndProc(SCI_SETKEYWORDS, 1, cast(size_t)keywords1.ptr);
		sci.WndProc(SCI_SETKEYWORDS, 3, cast(size_t)keywords2.ptr);
		
		sci.WndProc(SCI_SETSELBACK, true, 0xFFFFFF);
		sci.WndProc(SCI_SETSELALPHA, 70, 0);
		
		sci.WndProc(SCI_SETCARETLINEVISIBLE, true, 0);
		sci.WndProc(SCI_SETCARETLINEBACK, 0x303030, 0);
		/+
SCI_SETSELFORE(bool useSelectionForeColour, int colour)
SCI_SETSELBACK(bool useSelectionBackColour, int colour)
SCI_SETSELALPHA(int alpha)
SCI_GETSELALPHA
		+/
		
		sci.WndProc(SCI_COLOURISE, 0, -1);
	}
	
	
	protected int TranslateKey(Key k) {
		switch (k.keySym) {
			case KeySym.Left:				return SCK_LEFT;
			case KeySym.Right:			return SCK_RIGHT;
			case KeySym.Up:				return SCK_UP;
			case KeySym.Down:			return SCK_DOWN;
			case KeySym.Home:			return SCK_HOME;
			case KeySym.End:				return SCK_END;
			case KeySym.Page_Up:		return SCK_PRIOR;
			case KeySym.Page_Down:	return SCK_NEXT;
			case KeySym.Delete:			return SCK_DELETE;
			case KeySym.Insert:			return SCK_INSERT;
			case KeySym.Return:			return SCK_RETURN;
			case KeySym.Escape:		return SCK_ESCAPE;
			case KeySym.BackSpace:	return SCK_BACK;
			case KeySym.Tab:				return SCK_TAB;
			default: return 0;
		}
	}


	protected void _handleKey(ref Key e) {
		bool consumed = false;
		
		auto mod = e.modifiers;

		int key = TranslateKey(e);

		if (key) {
			sci.KeyDown(key, (mod & Modifiers.SHIFT) != 0, (mod & Modifiers.CTRL) != 0, (mod & Modifiers.ALT) != 0, &consumed);
		}

		if (!consumed && e.unicode != dchar.init) {
			foreach (char c; (&e.unicode)[0..1]) {
				sci.AddCharUTF(&c, 1, false);
			}
		}
	}

	protected EventHandling handleKey(KeyboardEvent e) {
		if (!e.sinking) {
			return EventHandling.Continue;
		}

		auto key = Key(e.keySym, e.unicode, e.modifiers, e.down);
		
		if (key.down) {
			_heldKey = key;
			_keyHoldTime = 0.f;
			_timeSinceKeyRepeat = 0.f;
		} else if	(	(_heldKey.keySym == key.keySym && _heldKey.unicode == key.unicode)
					||	(_heldKey.modifiers != key.modifiers) )
		{
			_keyHoldTime = _timeSinceKeyRepeat = float.nan;
		}
		
		if (key.down) {
			_handleKey(key);
		}

		return EventHandling.Stop;
	}
	
	
	protected EventHandling handleMouseButton(MouseButtonEvent e) {
		if (e.sinking) {
			Point pt;
			pt.x = cast(int)e.pos.x;
			pt.y = cast(int)e.pos.y;
			
			uint time = stopWatch.microsec / 1000;
			
			if (e.down) {
				sci.ButtonDown(pt, time, false, false, false);
			} else {
				sci.ButtonUp(pt, time, false);
			}
			
			return EventHandling.Stop;
		} else {
			return EventHandling.Continue;
		}
	}
	
	
	protected EventHandling handleMouseMove(MouseMoveEvent e) {
		if (e.sinking) {
			Point pt;
			pt.x = cast(int)e.pos.x;
			pt.y = cast(int)e.pos.y;
			sci.ButtonMove(pt);
			return EventHandling.Stop;
		} else {
			return EventHandling.Continue;
		}
	}
	
	
	protected override EventHandling handleTimeUpdate(TimeUpdateEvent e) {
		if (e.bubbling) {
			sci.Tick();
			_updateTime(e.delta);
		}
		return super.handleTimeUpdate(e);
	}
	
	
	protected EventHandling handleGainFocus(GainFocusEvent) {
		sci.SetFocusState(true);
		return EventHandling.Continue;
	}
	

	protected EventHandling handleLoseFocus(LoseFocusEvent) {
		sci.SetFocusState(false);
		return EventHandling.Continue;
	}

	
	protected void _updateTime(float delta) {
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
	

	override void render(GuiRenderer r) {
		synchronized (this.classinfo) {
			this.renderer = r;
			sci.clientSize = vec2i.from(this.size);
			sci.Paint(surf.cctx, PRectangle(0, 0, cast(int)size.x, cast(int)size.y));
			this.renderer = null;
		}
	}


	/+override vec2 minSize() {
		return vec2(640, 480);
	}+/
	
	
	private static {
		GuiRenderer renderer;
	}	
	
	protected {
		struct Key {
			KeySym	keySym;
			dchar		unicode;
			Modifiers	modifiers = Modifiers.NONE;
			bool			down;
		}
		
		Key	_heldKey;
		float	_keyHoldTime;
		float	_timeSinceKeyRepeat;
		
		static float	_keyRepeatFreq		= 20.f;
		static float	_keyRepeatDelay	= 0.5f;
	}
}


class HybridEditor : DeeEditor {
	mixin MDeeEditor;

	this() {
		printf("HybridEditor.ctor called"\n);

		// We'll cache the graphics ourselves
		WndProc(SCI_SETBUFFEREDDRAW, 0, 0);
		// Turn on UniCode mode
		WndProc(SCI_SETCODEPAGE, SC_CP_UTF8, 0);
	}

	override void Initialise() { debug printf("HybridEditor.Initialise called"\n);}
	override void Finalise() { debug printf("HybridEditor.Finalise called"\n);}
//	override void RefreshColourPalette(Palette* pal, bool want) { debug printf("HybridEditor.RefreshColourPalette called"\n);}
	
	override PRectangle GetClientRectangle() {
		debug printf("HybridEditor.GetClientRectangle called"\n);
		/+int left;
		int top;
		int right;
		int bottom;+/
		return PRectangle(0, 0, clientSize.x, clientSize.y);
	}
	
	override void ScrollText(int linesToMove) {
		debug printf("HybridEditor.ScrollText called"\n);
	}
	
	override void UpdateSystemCaret() { debug printf("HybridEditor.UpdateSystemCaret called"\n);}
	
	override void SetVerticalScrollPos() {
		debug printf("HybridEditor.SetVerticalScrollPos called"\n);
	    //SetControl32BitValue( vScrollBar, topLine );
	}
	
	override void SetHorizontalScrollPos() {
		debug printf("HybridEditor.SetHorizontalScrollPos called"\n);
		//SetControl32BitValue( hScrollBar, xOffset );
	}
	
	override bool ModifyScrollBars(int nMax, int nPage) {
		debug printf("HybridEditor.ModifyScrollBars called"\n);
		
		/+
		// Minimum value = 0
		// TODO: This is probably not needed, since we set this when the scroll bars are created
		SetControl32BitMinimum( vScrollBar, 0 );
		SetControl32BitMinimum( hScrollBar, 0 );

		// Maximum vertical value = nMax + 1 - nPage (lines available to scroll)
		SetControl32BitMaximum( vScrollBar, Platform::Maximum( nMax + 1 - nPage, 0 ) );
		// Maximum horizontal value = scrollWidth - GetTextRectangle().Width() (pixels available to scroll)
		SetControl32BitMaximum( hScrollBar, Platform::Maximum( scrollWidth - GetTextRectangle().Width(), 0 ) );

		// Vertical page size = nPage
		SetControlViewSize( vScrollBar, nPage );
		// Horizontal page size = TextRectangle().Width()
		SetControlViewSize( hScrollBar, GetTextRectangle().Width() );

		// TODO: Verify what this return value is for
		// The scroll bar components will handle if they need to be rerendered or not
		+/
		return false;
	}
	
	override void ReconfigureScrollBars() {
		debug printf("HybridEditor.ReconfigureScrollBars called"\n);
		/+PRectangle rc = wMain.GetClientPosition();
		Resize(rc.Width(), rc.Height());+/
	}
	
	//override void AddCharUTF(char *s, uint len, bool treatAsDBCS) { debug printf("HybridEditor.AddCharUTF called"\n);}
	override void Copy() { debug printf("HybridEditor.Copy called"\n);}
	override void CopyAllowLine() { debug printf("HybridEditor.CopyAllowLine called"\n);}
	override bool CanPaste() { debug printf("HybridEditor.CanPaste called"\n); return true; }
	override void Paste() { debug printf("HybridEditor.Paste called"\n);}
	override void ClaimSelection() { debug printf("HybridEditor.ClaimSelection called"\n);}
	override void NotifyChange() { debug printf("HybridEditor.NotifyChange called"\n);}
	override void NotifyFocus(bool fcus) { debug printf("HybridEditor.NotifyFocus called"\n);}
	override int GetCtrlID() { debug printf("HybridEditor.GetCtrlID called"\n); return -1; }
	override void NotifyParent(SCNotification scn) { debug printf("HybridEditor.NotifyParent called"\n);}
	//override void NotifyStyleToNeeded(int endStyleNeeded) { debug printf("HybridEditor.NotifyStyleToNeeded called"\n);}
	override void NotifyDoubleClick(Point pt, bool shift, bool ctrl, bool alt) { debug printf("HybridEditor.NotifyDoubleClick called"\n);}
	override void CancelModes() { debug printf("HybridEditor.CancelModes called"\n);}
	//override int KeyCommand(uint iMessage) { debug printf("HybridEditor.KeyCommand called"\n); return -1; }
	override int KeyDefault(int key, int modifiers) { debug printf("HybridEditor.KeyDefault called"\n); return -1; }
	override void CopyToClipboard(SelectionText* selectedText) { debug printf("HybridEditor.CopyToClipboard called"\n);}
	override void DisplayCursor(Window.Cursor c) { debug printf("HybridEditor.DisplayCursor called"\n);}
	override bool DragThreshold(Point ptStart, Point ptNow) { debug printf("HybridEditor.DragThreshold called"\n); return false; }
	override void StartDrag() { debug printf("HybridEditor.StartDrag called"\n);}
	//override void ButtonDown(Point pt, uint curTime, bool shift, bool ctrl, bool alt) { debug printf("HybridEditor.ButtonDown called"\n);}
	override void SetTicking(bool on) { debug printf("HybridEditor.SetTicking called"\n);}
	override bool SetIdle(bool) { debug printf("HybridEditor.SetIdle called"\n); return false; }
	
	override void SetMouseCapture(bool on) {
		haveMouseCapture = on;
		debug printf("HybridEditor.SetMouseCapture called"\n);
	}
	
	override bool HaveMouseCapture() {
		debug printf("HybridEditor.HaveMouseCapture called"\n);
		return haveMouseCapture;
	}
	
	override bool PaintContains(PRectangle rc) { debug printf("HybridEditor.PaintContains called"\n); return true; }
	override bool ValidCodePage(int codePage) { debug printf("HybridEditor.ValidCodePage called"\n); return true; }
	override uint DefWndProc(uint iMessage, uint wParam, uint lParam) { debug printf("HybridEditor.DefWndProc called"\n); return 0; }
	//override uint WndProc(uint iMessage, uint wParam, uint lParam) { debug printf("HybridEditor.WndProc called"\n); return 0; }
	
	protected {
		bool		haveMouseCapture = false;
		vec2i	clientSize;
	}
}


class HybridSurface : DeeSurface {
	mixin MDeeSurface;
	mixin MIntrusivePooled;
	
	this() {
		printf("HybridSurface.ctor called"\n);
	}

	override void initialize(bool createNewBackend = false) {
		debug printf("HybridSurface.initialize called"\n);
		return super.initialize(createNewBackend);
	}
	
	vec3 toColor(uint co) {
		ubyte r = (co >> 16) & 0xff;
		ubyte g = (co >> 8) & 0xff;
		ubyte b = co & 0xff;
		const float mul = 1.f / 255.f;
		return vec3(mul * r, mul * g, mul * b);
	}

	vec3 toColor(ColourAllocated co) {
		return toColor(co.coAllocated);
	}
	
	Font getFont(void* font_) {
		return Font(`verdana.ttf`, 11);
	}
	
	override void Release() {
		debug printf("HybridSurface.Release called"\n);
		intrusiveLinkedUnlink();
		intrusivePooledRelease();
	}	
	
	override bool Initialised() { debug printf("HybridSurface.Initialised called"\n); return true; }
	override void PenColour(ColourAllocated fore) { debug printf("HybridSurface.PenColour called"\n);}
	
	override int LogPixelsY() {
		debug printf("HybridSurface.LogPixelsY called"\n);
		return 72;
	}
	
	override int DeviceHeightFont(int points) {
		debug printf("HybridSurface.DeviceHeightFont called"\n);
		int logPix = LogPixelsY();
		return (points * logPix + logPix / 2) / 72;
	}
		
	override void MoveTo(int x_, int y_) { debug printf("HybridSurface.MoveTo called"\n);}
	override void LineTo(int x_, int y_) { debug printf("HybridSurface.LineTo called"\n);}
	override void Polygon(Point *pts, int npts, ColourAllocated fore, ColourAllocated back) { debug printf("HybridSurface.Polygon called"\n);}
	
	override void RectangleDraw(PRectangle rc, ColourAllocated fore, ColourAllocated back) {
		debug printf("HybridSurface.RectangleDraw called"\n);
		return FillRectangle(rc, fore);
	}
	
	
	protected void drawClipped(void delegate() dg) {
		auto r = SciEditor.renderer;
		assert (r !is null);

		r.pushClipRect();
		r.clip(Rect(sciClipRect.min + r.getOffset, sciClipRect.max + r.getOffset));
		
		dg();
		
		r.popClipRect();
	}
	
	
	override void FillRectangle(PRectangle rc, ColourAllocated back) {
		debug printf("HybridSurface.FillRectangle called, rc: %.*s, color: %d"\n, rc.toString, back.coAllocated);
		
		auto r = SciEditor.renderer;
		assert (r !is null);
		
		r.applyStyle(null);
		r.flushStyleSettings();
		drawClipped({
			r.color(toColor(back));
			r.rect(Rect(vec2(rc.left, rc.top), vec2(rc.right, rc.bottom)));
		});
	}
	
	override void FillRectanglePattern(PRectangle rc, DeeSurface surfacePattern) { debug printf("HybridSurface.FillRectanglePattern called"\n);}
	override void RoundedRectangle(PRectangle rc, ColourAllocated fore, ColourAllocated back) { debug printf("HybridSurface.RoundedRectangle called"\n);}
	
	override void AlphaRectangle(PRectangle rc, int cornerSize, ColourAllocated fill, int alphaFill, ColourAllocated outline, int alphaOutline, int flags) {
		debug printf("HybridSurface.AlphaRectangle called"\n);

		auto r = SciEditor.renderer;
		assert (r !is null);
		
		r.applyStyle(null);
		r.flushStyleSettings();
		drawClipped({
			r.color(toColor(fill), 1.f / 255.f * alphaFill);
			r.rect(Rect(vec2(rc.left, rc.top), vec2(rc.right, rc.bottom)));
		});
	}
	
	override void Ellipse(PRectangle rc, ColourAllocated fore, ColourAllocated back) { debug printf("HybridSurface.Ellipse called"\n);}
	override void Copy(PRectangle rc, Point from, DeeSurface surfaceSource) { debug printf("HybridSurface.Copy called"\n);}

	override void DrawTextCommon(PRectangle rc, void* font_, int ybase, char *s, int len, uint fuOptions) { debug printf("HybridSurface.DrawTextCommon called"\n);}
	
	override void DrawTextNoClip(PRectangle rc, void* font_, int ybase, char *s, int len, ColourAllocated fore, ColourAllocated back) {
		debug printf("HybridSurface.DrawTextNoClip called"\n);
		/+FillRectangle(rc, back);
		DrawTextTransparent(rc, font_, ybase, s, len, fore);+/

		auto font = getFont(font_);
		auto r = SciEditor.renderer;
		assert (r !is null);

		r.applyStyle(null);
		r.flushStyleSettings();
		r.color(toColor(back));
		r.rect(Rect(vec2(rc.left, rc.top), vec2(rc.right, rc.bottom)));
		
		char[] text = s[0..len];
		vec2 pos = vec2(rc.left, ybase - font.height) + r.getOffset();

		r.flushStyleSettings();
		r.color(toColor(fore));
		font.print(vec2i.from(pos), text);
		//font.flush();
	}
	
	override void DrawTextClipped(PRectangle rc, void* font_, int ybase, char *s, int len, ColourAllocated fore, ColourAllocated back) {
		debug printf("HybridSurface.DrawTextClipped called"\n);
		FillRectangle(rc, back);
		DrawTextTransparent(rc, font_, ybase, s, len, fore);
	}

	override void DrawTextTransparent(PRectangle rc, void* font_, int ybase, char *s, int len, ColourAllocated fore) {
		debug printf("HybridSurface.DrawTextTransparent called with '%s', font: %d, rc: %.*s, color: %d, ybase: %d"\n, s, font_, rc.toString, fore.coAllocated, ybase);

		auto font = getFont(font_);
		auto r = SciEditor.renderer;
		assert (r !is null);
		
		char[] text = s[0..len];
		vec2 pos = vec2(rc.left, ybase - font.height) + r.getOffset();
		
		r.flushStyleSettings();
		drawClipped({
			r.color(toColor(fore));
			font.print(vec2i.from(pos), text);
		});
		//font.flush();
		
		debug printf("HybridSurface.DrawTextTransparent  done\n");
	}

	override void MeasureWidths(void* font_, char *s, int len, int *positions) {
		debug printf("HybridSurface.MeasureWidths called"\n);

		getFont(font_).layoutText(s[0..len], (int charIndex, dchar c, vec2i pen, ref Glyph g) {
			positions[charIndex] = pen.x + g.advance.x;
		});
	}
	
	override int WidthText(void* font_, char *s, int len) {
		return getFont(font_).width(s[0..len]);
		//debug printf("HybridSurface.WidthText called"\n);
		//return len * 6;
	}
	
	override int WidthChar(void* font_, char ch) {
		//debug printf("HybridSurface.WidthChar called"\n);
		return getFont(font_).width((&ch)[0..1]);
		//return 6;
	}
	
	override int Ascent(void* font_) {
		//debug printf("HybridSurface.Ascent called"\n);
		//return getFont(font_).ascent;
		
		// HACK... but it looks good xD
		return getFont(font_).ascent + getFont(font_).descent;
	}
	
	override int Descent(void* font_) {
		//debug printf("HybridSurface.Descent called"\n);
		return -getFont(font_).descent;
	}
	
	override int InternalLeading(void* font_) { debug printf("HybridSurface.InternalLeading called"\n); return 0; }
	override int ExternalLeading(void* font_) { debug printf("HybridSurface.ExternalLeading called"\n); return 0; }
	
	override int Height(void* font_) {
		debug printf("HybridSurface.Height called"\n);
		//return getFont(font_).lineSkip;
		return Ascent(font_) + Descent(font_);
	}
	
	override int AverageCharWidth(void* font_) {
		debug printf("HybridSurface.AverageCharWidth called"\n);
		return WidthChar(font_, 'n');
	}

	//override int SetPalette(Palette *pal, bool inBackGround) { debug printf("HybridSurface.SetPalette called"\n); return -1; }
	override void SetClip(PRectangle rc) {
		sciClipRect.min = vec2(rc.left, rc.top);
		sciClipRect.max = vec2(rc.right, rc.bottom);
		debug printf("HybridSurface.SetClip called"\n);
	}
	
	override void FlushCachedState() { debug printf("HybridSurface.FlushCachedState called"\n);}

	override void SetUnicodeMode(bool unicodeMode_) { debug printf("HybridSurface.SetUnicodeMode called"\n);}
	override void SetDBCSMode(int codePage_) { debug printf("HybridSurface.SetDBCSMode called"\n);}
	
	
	protected {
		Rect	sciClipRect;
	}
}
