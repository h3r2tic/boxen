module xf.gfx.api.gl3.backend.root.Win32;

private {
	import
		xf.gfx.Window,
		xf.gfx.WindowEvent;

	import
		xf.gfx.api.gl3.Common,
		xf.gfx.api.gl3.GLContext,
		xf.gfx.api.gl3.OpenGL,
		xf.gfx.api.gl3.ext.WGL_ARB_pixel_format,
		xf.gfx.api.gl3.ext.WGL_ARB_create_context,
		xf.gfx.api.gl3.ext.WGL_EXT_framebuffer_sRGB,
		xf.gfx.api.gl3.ext.WGL_EXT_swap_control,
		xf.gfx.api.gl3.GLContextData;
	
	import xf.input.Input;
	import Input = xf.gfx.api.gl3.backend.native.Win32Input;
	
	import
		xf.platform.win32.wingdi,
		xf.platform.win32.winuser,
		xf.platform.win32.winnt,
		xf.platform.win32.windef,
		xf.platform.win32.winbase;
		
	alias xf.platform.win32.windef.POINT POINT;
	
	import xf.gfx.api.gl3.platform.Win32;
	
	import tango.stdc.stringz : fromStringz;
	import tango.core.Thread;
	import tango.io.Stdout;
	
	alias xf.platform.win32.wingdi.DM_BITSPERPEL DM_BITSPERPEL;
	alias xf.platform.win32.wingdi.DM_PELSWIDTH DM_PELSWIDTH;
	alias xf.platform.win32.wingdi.DM_PELSHEIGHT DM_PELSHEIGHT;
}



extern (Windows) void function(GLint, GLint, GLsizei, GLsizei) glAddSwapHintRectWIN;

private extern (Windows) int gl3_backend_root_Win32_windowProc(HWND hwnd, uint umsg, WPARAM wparam, LPARAM lparam) {
	auto window = cast(GLRootWindow)cast(void*)GetWindowLong(hwnd, GWL_USERDATA);
	
	if (WM_CREATE == umsg && window is null) {
		CREATESTRUCT* creation = cast(CREATESTRUCT*)lparam;
		assert (creation !is null);
		
		window = cast(GLRootWindow)cast(void*)creation.lpCreateParams;
		SetWindowLong(hwnd, GWL_USERDATA, cast(uint)cast(void*)window);
	}
	
	if (window !is null) {
		return window.windowProc(umsg, wparam, lparam);
	} else {
		return DefWindowProc(hwnd, umsg, wparam, lparam);
	}
}


extern (Windows) {
	HGLRC function(HDC hDC, HGLRC hShareContext, int *attribList) wglCreateContextAttribsARB;
}


class GLRootWindow : GLContext {
	uint _reportedWidth, _reportedHeight;


	~this() {
		if (created) {
			destroy();
		}
	}

	
	char[] title() {
		return _title;
	}


	GLRootWindow title(char[] t) {
		if (created) {
			SetWindowText(_hwnd, (t ~ \0).ptr);
		}
		
		_title = t;
		return this;
	}
	
	
	GLRootWindow decorations(bool d) {
		return this;
	}
	
	
	bool decorations() {
		return false;
	}
	
	
	bool visible() {
		return _visible;
	}


	GLRootWindow fullscreen(bool f) {
		_fullscreen = f;
		return this;
	}
	
	
	bool fullscreen() {
		return _fullscreen;
	}


	bool interceptCursor() {
		return _interceptCursor;
	}
	
	
	GLRootWindow	interceptCursor(bool b) {
		_interceptCursor = b;
		return this;
	}


	override typeof(this) width(uint w) {
		super.width(w);
		moveResizeWindow();
		return this;
	}
	alias GLContext.width width;
	
	
	override typeof(this) height(uint h) {
		super.height(h);
		moveResizeWindow();
		return this;
	}
	alias GLContext.height height;
	
	
	GLRootWindow position(vec2i xy) {
		_xpos = xy.x;
		_ypos = xy.y;
		moveResizeWindow();
		return this;
	}
	
	
	vec2i position() {
		return vec2i(_xpos, _ypos);
	}
	
	
	typeof(this) swapInterval(uint i) {
		_swapInterval = i;
		if (created) {
			version (WINE) {}
			else _gl.SwapIntervalEXT(_swapInterval);
		}
		return this;
	}
	
	uint swapInterval() {
		return _swapInterval;
	}


	InputChannel	inputChannel() {
		return _channel;
	}
	
	
	GLRootWindow inputChannel(InputChannel ch) {
		this._channel = ch;
		return this;
	}


	protected {
		void moveResizeWindow() {
			if (!created) return;
			.MoveWindow(_hwnd, _xpos, _ypos, _width, _height, 1);
		}


		bool changeScreenResolution(uint width, uint height, uint bits) {
			
			DEVMODE dmScreenSettings;
			with (dmScreenSettings) {
				dmSize				= DEVMODE.sizeof;
				dmPelsWidth		= width;
				dmPelsHeight		= height;
				dmBitsPerPel		= bits;
				dmFields			= DM_BITSPERPEL | DM_PELSWIDTH | DM_PELSHEIGHT;
			}
			
			return DISP_CHANGE_SUCCESSFUL == ChangeDisplaySettings (&dmScreenSettings, CDS_FULLSCREEN);
		}
	
		
		static HINSTANCE hinstance() {
			return GetModuleHandle(null);
		}
	
	
		static void registerWindowClass() {
			WNDCLASSEX windowClass;
			with (windowClass) {
				cbSize = windowClass.sizeof;
				style = CS_HREDRAW | CS_VREDRAW | CS_OWNDC;
				lpfnWndProc = cast(typeof(lpfnWndProc))&.gl3_backend_root_Win32_windowProc;		// bug in core32 ? it expects lparam, wparam instead of wrapam, lparam
				hInstance = hinstance();
				hbrBackground = cast(HBRUSH)(COLOR_APPWORKSPACE);
				hCursor = LoadCursor(null, IDC_ARROW);
				lpszClassName = className;
			}
			
			assert (windowClass.hInstance !is null);
			assert (windowClass.lpfnWndProc !is null);
			
			if (!RegisterClassEx(&windowClass)) {
				throw new Exception("Could not register window class '" ~ (className is null ? "(null)" : fromStringz(className)) ~ "'");
			} else {
				classRegistered = true;
			}
		}
		
		
		static void unregisterWindowClass() {
			synchronized (win32Mutex) {
				if (classRegistered) {
					UnregisterClass(className, hinstance());
					classRegistered = false;
				}
			}
		}
		

		int windowProc(uint umsg, WPARAM wparam, LPARAM lparam) {
			bool keyDown = WM_KEYDOWN == umsg;

			bool passThrough = false;

			switch (umsg) {
				case WM_SYSKEYDOWN:
				case WM_KEYDOWN:
				case WM_SYSKEYUP:
				case WM_KEYUP: {
					passThrough = true;
					
					if (_channel !is null && _hasFocus) {
						KeySym keysym;
						if (Input.translateKey(wparam, lparam, keyDown, keysym)) {
							//writefln("key hit. down = ", keyDown);

							Input.key(_channel, keysym, keyDown, wparam, lparam);
						} else break;
					}
				} break;
				
				// no flicker when resizing
				case WM_ERASEBKGND: return 0;

				case WM_LBUTTONDOWN: {
					passThrough = true;

					if (_channel !is null && _hasFocus) {
						SetCapture(_hwnd);
						Input.mouseButtonDown(_channel, MouseInput.Button.Left);
					}
				} break;
				
				case WM_RBUTTONDOWN: {
					passThrough = true;

					if (_channel !is null && _hasFocus) {
						SetCapture(_hwnd);
						Input.mouseButtonDown(_channel, MouseInput.Button.Right);
					}
				} break;
				
				case WM_MBUTTONDOWN: {
					passThrough = true;

					if (_channel !is null && _hasFocus) {
						SetCapture(_hwnd);
						Input.mouseButtonDown(_channel, MouseInput.Button.Middle);
					}
				} break;


				case WM_LBUTTONUP: {
					passThrough = true;

					if (_channel !is null && _hasFocus) {
						if (!_interceptCursor) ReleaseCapture();
						Input.mouseButtonUp(_channel, MouseInput.Button.Left);
					}
				} break;

				case WM_RBUTTONUP: {
					passThrough = true;

					if (_channel !is null && _hasFocus) {
						if (!_interceptCursor) ReleaseCapture();
						Input.mouseButtonUp(_channel, MouseInput.Button.Right);
					}
				} break;

				case WM_MBUTTONUP: {
					passThrough = true;

					if (_channel !is null && _hasFocus) {
						if (!_interceptCursor) ReleaseCapture();
						Input.mouseButtonUp(_channel, MouseInput.Button.Middle);
					}
				} break;


				case WM_MOUSEMOVE: {
					passThrough = true;

					if (_channel !is null && _hasFocus) {
						// signed position
						int curX = cast(int)cast(short)LOWORD(lparam);
						int curY = cast(int)cast(short)HIWORD(lparam);
						
						int deltaX, deltaY;

						if (_interceptCursor) {
							RECT rect;
							GetClientRect(_hwnd, &rect);
							int width = rect.right+1;
							int height = rect.bottom+1;
							
							int warpX = width / 2;
							int warpY = height / 2;

							deltaX = curX - warpX;
							deltaY = curY - warpY;

							if (0 == deltaX && 0 == deltaY) return 0;

							_cursorX = _prevCursorX + deltaX;
							_cursorY = _prevCursorY + deltaY;
						} else {
							deltaX = curX - _prevCursorX;
							deltaY = curY - _prevCursorY;

							if (0 == deltaX && 0 == deltaY) return 0;
							
							_cursorX = curX;
							_cursorY = curY;
						}

						POINT pt;
						GetCursorPos(&pt);
						Input.mouseMove(_channel, _cursorX, _cursorY, deltaX, deltaY, pt.x, pt.y);
						
						_prevCursorX = _cursorX;
						_prevCursorY = _cursorY;
						
						if (_interceptCursor) {
							warpMouseToCenter();
						}
					}
				} break;

				case WM_MOUSEWHEEL: {
					passThrough = true;

					if (_channel !is null) {
						int _delta = GET_WHEEL_DELTA_WPARAM(wparam);
						Input.mouseWheel(_channel, _delta, MouseInput.Button.WheelDown, MouseInput.Button.WheelUp);
					}
				} break;
				
				// WTF, Vista-only? D:
				/+case WM_MOUSEHWHEEL: {
					if (_channel !is null) {
						int _delta = GET_WHEEL_DELTA_WPARAM(wparam);
						Input.mouseHWheel(_channel, _delta, MouseInput.Button.WheelLeft, MouseInput.Button.WheelRight);
					}
				} break;+/

				case WM_SYSCOMMAND: {
					passThrough = true;
				} break;

				case WM_MOVE: {
					short newX = cast(short)LOWORD(lparam);
					short newY = cast(short)HIWORD(lparam);
					
					if (_channel !is null) {
						auto event = WindowEvent(WindowEvent.Type.Moved);
						event.xPos = newX;
						event.yPos = newY;
						event.xDelta = newX - _xpos;
						event.yDelta = newY - _ypos;
						_channel << event;
					}

					_xpos = newX;
					_ypos = newY;
					
					return 0;
				}

				case WM_SIZE: {
					switch (wparam) {
						case SIZE_MINIMIZED: {
							_visible = false;

							if (_channel !is null) {
								_channel << WindowEvent(WindowEvent.Type.Minimized);
							}
						} break;
		
						case SIZE_RESTORED: {
							_visible = true;
							_reportedWidth = LOWORD(lparam);
							_reportedHeight = HIWORD(lparam);

							if (_reshapeCallback !is null) {
								_reshapeCallback(_reportedWidth, _reportedHeight);
							}

							if (_channel !is null) {
								_channel << WindowEvent(WindowEvent.Type.Resized, _reportedWidth, _reportedHeight);
							}
						} break;

						case SIZE_MAXIMIZED: {
							_visible = true;
							_reportedWidth = LOWORD(lparam);
							_reportedHeight = HIWORD(lparam);
							
							if (_reshapeCallback !is null) {
								_reshapeCallback(_reportedWidth, _reportedHeight);
							}

							if (_channel !is null) {
								_channel << WindowEvent(WindowEvent.Type.Maximized, _reportedWidth, _reportedHeight);
							}
						} break;
						
						default: break;
					}
				} break;
				
				case WM_QUIT:
				case WM_CLOSE: {
					if (_channel !is null) {
						_channel << WindowEvent(WindowEvent.Type.Closed);
					}

					if (created) {
						destroy();
					}
					break;
				}

				default: break;
			}

			if (passThrough) {
				auto desktopHWND = getDesktopHWND();
				assert (desktopHWND !is null);
				SendMessage(desktopHWND, umsg, wparam, lparam);
			}
			
			return DefWindowProc(_hwnd, umsg, wparam, lparam);
		}
	}
	

	GLRootWindow showCursor(bool s) {
		return this;
	}


	override GLRootWindow create() {
		assert (classRegistered);

		void printWinError() {
			DWORD err = GetLastError(); 
			char[512] errorMsg = 0;

			auto len = FormatMessage(
				FORMAT_MESSAGE_FROM_SYSTEM |
				FORMAT_MESSAGE_IGNORE_INSERTS,
				null,
				err,
				MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
				errorMsg.ptr,
				512, null);

			Stdout.formatln(`Last winapi error (code={}): {}`, err, errorMsg[0 .. len]);
		}
		
		// Win32-based applications that use Microsoft's implementation of GL to render onto a window must include WS_CLIPCHILDREN and WS_CLIPSIBLINGS window styles for that window.
		// http://support.microsoft.com/kb/q126019/
		uint windowStyle = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX | (WS_CLIPCHILDREN | WS_CLIPSIBLINGS);
		uint windowExtendedStyle = WS_EX_TOOLWINDOW;
	
		RECT windowRect;
		windowRect.top = 0;
		windowRect.left = 0;
		windowRect.right = _width;
		windowRect.bottom = _height;
	
		if (_fullscreen) {
			if (!changeScreenResolution(_width, _height, _colorBits)) {
				_fullscreen = false;
			}
			else {
				windowExtendedStyle |= WS_EX_TOPMOST;
			}
		}
		
		if (_fullscreen) {
			windowStyle = WS_POPUP | (WS_CLIPCHILDREN | WS_CLIPSIBLINGS);
		}

		//ShowCursor(false);
		
		if (!_fullscreen) {
			AdjustWindowRectEx(&windowRect, windowStyle, 0, windowExtendedStyle);
		}

	
		union CastHack {
			GLRootWindow thisptr;
			void* ptr;
		}
		CastHack chack;
		chack.thisptr = this;
		
		_hwnd = CreateWindowEx (
				windowExtendedStyle,
				className,
				(_title ~ \0).ptr,
				windowStyle,
				_xpos, _ypos,											// window position
				windowRect.right - windowRect.left,
				windowRect.bottom - windowRect.top,
				HWND_DESKTOP,										// parent
				null,															// menu
				hinstance(),
				chack.ptr);										// user data
				
		//if (!decorations) {
			windowStyle = WS_POPUP | (WS_CLIPCHILDREN | WS_CLIPSIBLINGS);

			windowRect.top = 0;
			windowRect.left = 0;
			windowRect.right = _width;
			windowRect.bottom = _height;
			AdjustWindowRectEx(&windowRect, windowStyle, 0, windowExtendedStyle);

			SetWindowLong(_hwnd, GWL_STYLE, windowStyle);
			SetWindowPos(	_hwnd,
									cast(HANDLE)null,
									0, 0,
									windowRect.right - windowRect.left,
									windowRect.bottom - windowRect.top,
									SWP_NOZORDER | SWP_NOMOVE | SWP_NOACTIVATE | SWP_DRAWFRAME);
		//}	
		
		if (_hwnd is null) {
			printWinError();
			throw new Exception("could not create a window (CreateWindowEx)");
		}
		
		scope (failure) {
			DestroyWindow(_hwnd);
			_hwnd = null;
		}
	
		_hdc = GetDC(_hwnd);
		if (_hdc is null) {
			printWinError();
			throw new Exception("window hDC is null");
		}
		
		scope (failure) {
			ReleaseDC(_hwnd, _hdc);
			_hdc = null;
		}
		
		if (isGLContextDataSet(_gl)) {
			auto ctx = new GLContextData;
			ctx.initialize();
			setGLContextData(_gl, ctx);
			assert (isGLContextDataSet(_gl));
			findAndLoadLibs();
		}

		if (0 == _colorBits) {
			_colorBits = GetDeviceCaps(GetDC(HWND_DESKTOP), BITSPIXEL);
		}
		
		PIXELFORMATDESCRIPTOR pfd;
		if (preInitDone) {
			if (!wglSetPixelFormat(_hdc, overridePixelFormat, &pfd)) {
				throw new Exception("wglSetPixelFormat failed");
			}
		} else {
			with (pfd) {
				nSize = pfd.sizeof;
				nVersion = 1;
				dwFlags =
					PFD_DRAW_TO_WINDOW
				|	PFD_SUPPORT_OPENGL
				|	PFD_DOUBLEBUFFER
				|	PFD_SWAP_EXCHANGE;
				iPixelType = PFD_TYPE_RGBA;
				cColorBits = cast(ubyte)_colorBits;
				cAlphaBits = cast(ubyte)_alphaBits;
				cDepthBits = cast(ubyte)_depthBits;
				cStencilBits = cast(ubyte)_stencilBits;
			}
			
			uint pixelFormat = ChoosePixelFormat(_hdc, &pfd);
			if (0 == pixelFormat) {
				printWinError();
				throw new Exception("ChoosePixelFormat failed");
			}
			
			if (!SetPixelFormat(_hdc, pixelFormat, &pfd)) {
				printWinError();
				throw new Exception("SetPixelFormat failed");
			}
		}

		
		/+{
			auto tmpRc = cast(typeof(_hrc))xf.gfx.api.gl3.platform.Win32.wglCreateContext(_hdc);
			if (tmpRc is null) {
				throw new Exception("wglCreateContext failed");
			}
			
			xf.gfx.api.gl3.platform.Win32.wglMakeCurrent(_hdc, tmpRc);
			
			wglCreateContextAttribsARB = cast(typeof(wglCreateContextAttribsARB))
				xf.gfx.api.gl3.platform.Win32.wglGetProcAddress("wglCreateContextAttribsARB");
				
			if (wglCreateContextAttribsARB is null) {
				throw new Exception("The WGL_ARB_create_context extension is missing. If your GPU has OpenGL 3.x support, your drivers are probably out of date.");
			}
			
			xf.gfx.api.gl3.platform.Win32.wglMakeCurrent(_hdc, null);
			
			assert (wglCreateContextAttribsARB !is null);
			
			int[] attribList;
			attribList ~= WGL_CONTEXT_MAJOR_VERSION_ARB;
			attribList ~= 3;
			attribList ~= WGL_CONTEXT_MINOR_VERSION_ARB;
			attribList ~= 1;
			// Cg doesn't like it :F
			/+attribList ~= WGL_CONTEXT_FLAGS_ARB;
			attribList ~= xf.gfx.api.gl3.WGL.WGL_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB;+/
			attribList ~= 0;
			_hrc = wglCreateContextAttribsARB(_hdc, null, attribList.ptr);
		}+/
		{
			_hrc = cast(typeof(_hrc))xf.gfx.api.gl3.platform.Win32.wglCreateContext(_hdc);
		}
		if (_hrc is null) {
			printWinError();
			throw new Exception("wglCreateContextAttribsARB failed. You probably don't have OpenGL 3.x support");
		}
		
		scope (failure) {
			xf.gfx.api.gl3.platform.Win32.wglDeleteContext(_hrc);
			_hrc = null;
		}
	
	
		if (!xf.gfx.api.gl3.platform.Win32.wglMakeCurrent(_hdc, _hrc)) {
			printWinError();
			throw new Exception("wglMakeCurrent failed");
		}
		
		if (!preInitDone) {
			preInitDone = true;
			bool recreate = false;
			//if (!(_gl.ext(WGL_ARB_pixel_format) in {
			
			version (WINE) {}
			else {
				static float[] fAttributes = [ 0.f, 0.f ];
				int[] formatAttribs; {
					formatAttribs ~= WGL_DRAW_TO_WINDOW_ARB;
					formatAttribs ~= xf.gfx.api.gl3.GL.TRUE;
					formatAttribs ~= WGL_ACCELERATION_ARB;
					formatAttribs ~= WGL_FULL_ACCELERATION_ARB;
					formatAttribs ~= WGL_COLOR_BITS_ARB;
					formatAttribs ~= _colorBits;
					formatAttribs ~= WGL_ALPHA_BITS_ARB;
					formatAttribs ~= _alphaBits;
					formatAttribs ~= WGL_DEPTH_BITS_ARB;
					formatAttribs ~= _depthBits;
					formatAttribs ~= WGL_STENCIL_BITS_ARB;
					formatAttribs ~= _stencilBits;
					formatAttribs ~= WGL_DOUBLE_BUFFER_ARB;
					formatAttribs ~= xf.gfx.api.gl3.GL.TRUE;
					formatAttribs ~= WGL_SWAP_METHOD_ARB;
					formatAttribs ~= WGL_SWAP_EXCHANGE_ARB;

					if (_sRGB) {
						formatAttribs ~= WGL_FRAMEBUFFER_SRGB_CAPABLE_EXT;
						formatAttribs ~= xf.gfx.api.gl3.GL.TRUE;
					}
					
					formatAttribs ~= 0;
					formatAttribs ~= 0;
				}
				
				uint numFormats = 0;
				if (!_gl.ChoosePixelFormatARB(_hdc, formatAttribs.ptr, fAttributes.ptr, 1, &overridePixelFormat, &numFormats) || 0 == numFormats) {
					// throw new Exception("wglChoosePixelFormat failed");
				} else {
					recreate = true;
				}
			}
			/+})) {
				Stdout.formatln("[GLRootWindow] WARNING: WGL_ARB_pixel_format not supported");
			}+/
			
			if (recreate) {
				destroyWindowOnly();
				return create();
			}
		}
		
		ShowWindow(_hwnd, SW_NORMAL);
		_created = true;
		_visible = true;
		
		_contextOwnerThread = Thread.getThis();
		xf.gfx.api.gl3.platform.Win32.wglMakeCurrent(_hdc, _hrc);
		
		swapInterval = _swapInterval;
		
		return this;
	}


	static this() {
		win32Mutex = new Object;
		registerWindowClass();

		// ------------------------------------------------------------------------------------------------------------------------------------------------
		// I'm not very proud of what follows here, but it seems that without this 'step', creating multiple threads with GL windows fails
		// just at SetPixelFormat. Somehow w32 needs to get warmed up or something before going into threads oO
		// ------------------------------------------------------------------------------------------------------------------------------------------------

		auto _hwnd = CreateWindow(
				className,
				"hackWindow".ptr,
				WS_OVERLAPPED | WS_CLIPCHILDREN | WS_CLIPSIBLINGS,
				0, 0, 16, 16,
				HWND_DESKTOP,						// parent
				null,											// menu
				hinstance(),
				null);										// user data
	
		
		if (_hwnd !is null) {
			scope (exit) DestroyWindow(_hwnd);
			auto _hdc = GetDC(_hwnd);
			
			if (_hdc !is null) {
				scope (exit) ReleaseDC(_hwnd, _hdc);
				PIXELFORMATDESCRIPTOR pfd;
				ChoosePixelFormat(_hdc, &pfd);
			}
		}
	}
	
	
	private void destroyWindowOnly() {
		if (_hwnd !is null) {
			if (_hdc !is null)
			{
				xf.gfx.api.gl3.platform.Win32.wglMakeCurrent(_hdc, null);
				if (_hrc !is null) {
					xf.gfx.api.gl3.platform.Win32.wglDeleteContext(_hrc);
					_hrc = null;
				}

				ReleaseDC(_hwnd, _hdc);
				_hdc = null;
			}

			DestroyWindow(_hwnd);
			_hwnd = null;
		}
		
		_created = false;
		_visible = false;
	}
	
	
	override GLRootWindow destroy() {
		preInitDone = false;
		
		destroyWindowOnly();
	
		if (_fullscreen) {
			ChangeDisplaySettings(null, 0);		// default
			//ShowCursor(true);
		}
		
		return this;
	}


	ubyte*	dibBuf = null;
	size_t	dibBufSize = 0;
	uint	swMode = uint.max;
	
	GLRootWindow show() {
		if (_hdc !is null) {
			/**
				The mirror driver is used in VNC solutions to efficiently
				monitor changes to the display. Unfortunately it doesn't support
				hardware-accelerated rendering. We can force VNC software
				to send updates of the 3d view by faking a rendering of some
				non-hardware stuff to the window. The code below draws an invisible
				line, which is enough to invalidate the whole rectangle.
			*/
			auto desktopHWND = getDesktopHWND();
			HWND targetHWND = _hwnd;
			uint targetOffsetX = 0;
			uint targetOffsetY = 0;
			bool releaseDC = false;
			
			if (.GetDesktopWindow == desktopHWND) {
				if (swMode != SW_HIDE) {
					ShowWindow(_hwnd, SW_HIDE);
					swMode = SW_HIDE;
				}

				targetHWND = desktopHWND;
				targetOffsetX = _xpos;
				targetOffsetY = _ypos;
				releaseDC = true;
			} else {
				if (swMode != SW_NORMAL) {
					SetWindowLong(_hwnd, GWL_HWNDPARENT, cast(LPARAM)desktopHWND);
					ShowWindow(_hwnd, SW_NORMAL);
					swMode = SW_NORMAL;
				}
			}

			auto targetDC = GetDC(targetHWND);

			size_t dibSize = _width * _height * 4;
			if (dibBuf is null || dibSize != dibBufSize) {
				ubyte[] meh = dibBuf[0..dibBufSize];
				meh.length = dibSize;
				dibBufSize = dibSize;
				dibBuf = meh.ptr;
			}

			BITMAPINFO bmi;
			bmi.bmiHeader.biSize = BITMAPINFOHEADER.sizeof;
			bmi.bmiHeader.biWidth = _width;
			bmi.bmiHeader.biHeight = _height;
			bmi.bmiHeader.biPlanes = 1;
			bmi.bmiHeader.biBitCount = 32;
			bmi.bmiHeader.biCompression = BI_RGB;
			bmi.bmiHeader.biSizeImage = bmi.bmiHeader.biWidth * bmi.bmiHeader.biHeight * 4;

			_gl.ReadPixels(0, 0, _width, _height, BGRA, UNSIGNED_BYTE, dibBuf);

			_gl.BindFramebuffer(FRAMEBUFFER, 0);
			_gl.SwapIntervalEXT(0);

			/*
			 * This is a massive hack against nvidia's crappy desktop rotation that
			 * runs at around 10fps when the user is not interacting with the
			 * machine.
			 */
			 
			*cast(void**)&glAddSwapHintRectWIN = xf.gfx.api.gl3.platform.Win32.wglGetProcAddress("glAddSwapHintRectWIN");
			assert (glAddSwapHintRectWIN !is null);
			glAddSwapHintRectWIN(0, 0, 0, 0);

			SwapBuffers(_hdc);

			/+ interlaced
			
			void blitLine(int y) {
				SetDIBitsToDevice(
					targetDC, targetOffsetX, targetOffsetY+y, _width, 1,
					0, y, 0, _height,
					dibBuf, &bmi, DIB_RGB_COLORS
				);
			}

			static int yoff = 0;
			yoff ^= 1;

			for (int y = yoff; y < _height; y += 2) {
				blitLine(y);
			}+/

			SetDIBitsToDevice(
				targetDC, targetOffsetX, targetOffsetY, _width, _height,
				0, 0, 0, _height,
				dibBuf, &bmi, DIB_RGB_COLORS
			);

			if (releaseDC) {
				ReleaseDC(targetHWND, targetDC);
			}
		}
		return this;
	}
	
	
	GLRootWindow update() {
		MSG msg;
		
		while (PeekMessage(&msg, _hwnd, 0, 0, PM_REMOVE)) {
			DispatchMessage(&msg);
		}
		
		return this;
	}


	private HWND getDesktopHWND() {
		auto desktopHWND = FindWindow("DesktopBackgroundClass", "");
		if (desktopHWND is null) {
			desktopHWND = GetDesktopWindow();
		}
		return desktopHWND;
	}


	GLuint fb;


	import
		xf.gfx.api.gl3.ext.ARB_framebuffer_object,
		xf.gfx.api.gl3.ext.EXT_framebuffer_object;

	override void useInHandler(void delegate(GL) dg) {
		assert (Thread.getThis is _contextOwnerThread);
		assert (isGLContextDataSet(_gl));

		if (0 == fb) {
			_gl.GenFramebuffers(1, &fb);
			_gl.BindFramebuffer(FRAMEBUFFER, fb);

			{
				GLuint id;
				_gl.GenRenderbuffers(1, &id);
				_gl.BindRenderbuffer(RENDERBUFFER, id);
				_gl.RenderbufferStorage(
					RENDERBUFFER,
					RGBA8,
					_width,
					_height
				);
				_gl.FramebufferRenderbuffer(
					FRAMEBUFFER, COLOR_ATTACHMENT0_EXT,
					RENDERBUFFER, id
				);
			}

			{
				GLuint id;
				_gl.GenRenderbuffers(1, &id);
				_gl.BindRenderbuffer(RENDERBUFFER, id);
				_gl.RenderbufferStorage(
					RENDERBUFFER,
					DEPTH_COMPONENT24,
					_width,
					_height
				);
				_gl.FramebufferRenderbuffer(
					FRAMEBUFFER, DEPTH_ATTACHMENT,
					RENDERBUFFER, id
				);
			}
		}

		_gl.BindFramebuffer(FRAMEBUFFER, fb);
		
		dg(_gl);
	}
/+	
	
	override void useInHandler(void delegate(GL) dg) {
		assert (_gl !is null);

		synchronized (this) {
			dg(_gl);
		}
	}
	+/
	
	static typeof(this) opCall() {
		return new typeof(this);
	}
	
	
	private {
		HWND		_hwnd;
		HDC			_hdc;
		HGLRC		_hrc;
		
		GL			_gl;
		
		static bool			classRegistered = false;
		static const char* 	className = "DogWindow";
		
		bool	preInitDone = false;
		int		overridePixelFormat = 0;
		
		Thread	_contextOwnerThread;
	}
	
	static private Object win32Mutex;


	private {
		void warpMouseToCenter() {
			RECT rect;
			GetClientRect(_hwnd, &rect);
			int width = rect.right+1;
			int height = rect.bottom+1;

			POINT point;
			point.x = width / 2;
			point.y = height / 2;
			ClientToScreen(_hwnd, &point);
			SetCursorPos(point.x, point.y);
		}

		InputChannel	_channel;
		bool			_interceptCursor;

		int				_cursorX	= 0;
		int				_cursorY	= 0;
		int				_prevCursorX	= 0;
		int				_prevCursorY	= 0;
	}


	protected {
		char[]	_title	= "xf.gfx.api.gl3.GLRootWindow";
		bool	_fullscreen		= false;
		bool	_visible		= false;
		int		_xpos			= CW_USEDEFAULT;
		int		_ypos			= CW_USEDEFAULT;
		uint	_swapInterval	= 1;
		bool	_hasFocus		= false;
	}
}


// DMD/OPTLINK sucks. if this symbol is not declared in a central point, the linker will complain about different symbol definitions and crap
alias use!(GLRootWindow) use__GLWindow_symbolinstance;
