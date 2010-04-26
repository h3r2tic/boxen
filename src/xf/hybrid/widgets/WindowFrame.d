module xf.hybrid.widgets.WindowFrame;

private {
	import xf.hybrid.Common;
	import xf.hybrid.CustomWidget;
	import xf.hybrid.widgets.Button : GenericButton;
}



class WindowFrame : CustomWidget {
	override bool childrenGoAbove() {
		return false;
	}

	
	this() {
		getAndRemoveSub("handle", &_handle);
		_handle.enableStyle("active");
	}
	
	
	Widget handle() {
		return _handle;
	}
	
	
	protected {
		Widget _handle;
	}	
	

	mixin(defineProperties("out bool minimizeClicked, out bool maximizeClicked, out bool closeClicked, char[] text"));
	mixin MWidget;
}



class WindowFrameButton : GenericButton {
	mixin(defineProperties("char[] addIcon"));
	mixin MWidget;
}
