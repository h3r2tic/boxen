module xf.hybrid.widgets.Combo;

private {
	import xf.hybrid.Common;
	import xf.hybrid.CustomWidget;
	import xf.hybrid.widgets.Input : Input;
	import xf.hybrid.widgets.Button : GenericButton;
	import xf.hybrid.widgets.ClipView : ClipView;
	import xf.hybrid.widgets.TextList : TextList;
	
	import tango.util.log.Trace;
	import tango.util.Convert : to;
}



// TODO: set _selectedIdx to the proper value when some value from the popup is entered into the input box manually

/**
	Combo of an edit field and a drop-down list
	Properties:
	---
	char[] selected
	char[] addItem
	int selectedIdx
	out char[][] items
	---
*/
class Combo : CustomWidget {
	/**
		Adds a single retained item
	*/
	typeof(this) addItem(char[] i) {
		_textList.addItem(i);
		return this;
	}
	char[] addItem() { assert (false); return null; }
	
	
	/**
		Removes all retained items
	*/
	typeof(this) removeItems() {
		_textList.removeItems();
		_selectedIdx = _selectedIdx.init;
		_origSelectedText = _origSelectedText.init;
		return this;
	}
	
	
	EventHandling handleButtonClick(ClickEvent e) {
		if (e.bubbling && !e.handled) {
			_showingPopup = !_showingPopup;
			installGlobalButtonHandler();
			return EventHandling.Stop;
		}
		return EventHandling.Continue;
	}
	
	
	/**
		Returns the currently selected text - either in the edit field or the drop-down
	*/
	char[] selected() {
		return _input.text;
	}
	
	
	/**
		Sets the edit field's text. Does not change selectedIdx
	*/
	typeof(this) selected(char[] text) {
		_input.text = text;
		return this;
	}
	
	
	/**
		Returns the currently selected item from the drop-down or -1 if it was entered manually
	*/
	int selectedIdx() {
		return _origSelectedText == _input.text ? _selectedIdx : -1;
	}
	
	
	/**
		Returns all retained text items from the drop-down
	*/
	char[][] items() {
		return _textList.items;
	}
	
	
	/**
		Sets the text in the edit field using an item from the drop-down
	*/
	typeof(this) selectedIdx(int i) {
		auto items = _textList.items();
		if (i >= 0 && i < items.length) {
			selected = _origSelectedText = items[i];
			_selectedIdx = i;
		}
		return this;
	}
	
	
	protected void _onItemPicked() {
		_input.text = _origSelectedText = _textList.pickedText;
		_selectedIdx = _textList.pickedIdx;
	}


	override void onGuiStructureBuilt() {
		super.onGuiStructureBuilt();
		
		if (_showingPopup) {
			if (_textList.anythingPicked) {
				_onItemPicked();
				
				_showingPopup = false;
				_textList.resetPick();
			} else {
				gui.addOverlay(_popup);
				
				// TODO: exactly calculate the size in case the popup is not scrolled
				_popup.userSize = vec2(this.size.x, _popupHeight);
			}
		}
	}


	override EventHandling handleExpandLayout(ExpandLayoutEvent e) {
		auto res = super.handleExpandLayout(e);
		if (e.bubbling) {
			if (_showingPopup) {
				_popup.parentOffset = this.globalOffset + vec2(0, this.size.y);
			}
		}
		return res;
	}
	
	
	protected bool globalButtonHandler(MouseButtonEvent e) {
		if (e.down && !_popup.containsGlobal(e.pos) && !_button.containsGlobal(e.pos)) {
			_globalButtonHandlerInstalled = false;
			_showingPopup = false;
			return true;
		} else {
			return false;
		}
	}
	
	
	protected void installGlobalButtonHandler() {
		if (!_globalButtonHandlerInstalled && _showingPopup) {
			_globalButtonHandlerInstalled = true;
			gui.addGlobalHandler(&this.globalButtonHandler);
			Trace.formatln("installGlobalButtonHandler");
		}
	}
	
	
	protected {
		bool	_globalButtonHandlerInstalled = false;
	}


	this() {
		super();
		
		getAndRemoveSub("input", &_input);
		getAndRemoveSub("button", &_button);
		getAndRemoveSub("popup", &_popup);
		getAndRemoveSub("textList", &_textList);

		_popup.parent.removeChild(_popup);
		assert (_popup.parent is null);

		_button.addHandler(&this.handleButtonClick);
	}
	
	
	private {
		Input				_input;
		GenericButton	_button;
		Widget				_popup;
		TextList				_textList;
		bool					_showingPopup;
		float					_popupHeight = 150.f;
		int					_selectedIdx = -1;
		char[]				_origSelectedText;
	}
	
	mixin(defineProperties("char[] selected, char[] addItem, int selectedIdx, out char[][] items"));
	mixin MWidget;
}
