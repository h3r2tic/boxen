module xf.hybrid.widgets.TextList;

private {
	import xf.hybrid.Common;
	import xf.hybrid.CustomWidget;
	import xf.hybrid.widgets.Label;
	import xf.hybrid.widgets.Picker;
	import tango.io.Stdout;
}



/**
	A vertical list of text items
	
	Properties:
	---
	out int pickedIdx
	out char[][] items
	---
*/
class TextList : CustomWidget {
	/**
		Add a single retained item
	*/
	typeof(this) addItem(char[] t) {
		t = t.dup;
		_items ~= t;
		_picker.getSub(null).addChild((new Label).icfg(`fontSize = 12;`).text(t).layoutAttribs("hexpand hfill"));
		return this;
	}
	
	
	/**
		Remove all retained items
	*/
	typeof(this) removeItems() {
		_items.length = 0;
		_picker.getSub(null).removeChildren();
		return this;
	}
	
	
	this() {
		getAndRemoveSub("picker", &_picker);
	}


	void resetPick() {
		_picker.resetPick();
	}
	
	
	/**
		Tells whether any item was picked
	*/
	bool anythingPicked() {
		return _picker.anythingPicked();
	}
	
	
	/**
		Returns the text of the picked item
	*/
	char[] pickedText() {
		assert (anythingPicked);
		return _items[pickedIdx];
	}
	
	
	char[][] items() {
		return _items;
	}
	
	
	protected {
		char[][] _items;
		Picker	_picker;
	}


	mixin(defineProperties("out int pickedIdx, out char[][] items"));
	mixin MWidget;
}
