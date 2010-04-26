module xf.hybrid.widgets.Input;

private {
	import xf.hybrid.Common;
	import xf.hybrid.CustomWidget;
	import xf.hybrid.Font : Font;
	import xf.hybrid.widgets.InputArea;
}



/**
	The common text input field
	Properties:
	---
	char[] text
	Font font
	char[] fontFace
	int fontSize
	out bool hasFocus
	---

	InputArea subwidget has a void delegate() onEnter for handling return keypress event.
*/
class Input : CustomWidget {
	this() {
		getAndRemoveSub("inputArea", &_inputArea);
	}
	
	
	/**
	*/
	InputArea inputArea() {
		return _inputArea;
	}
	
	
	protected {
		InputArea _inputArea;
	}


	mixin(defineProperties("char[] text, Font font, char[] fontFace, int fontSize, out bool hasFocus"));
	mixin MWidget;
}
