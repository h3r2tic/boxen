module xf.hybrid.WidgetFactory;

private {
	import xf.hybrid.model.Core;
	import xf.hybrid.Log;
}



private extern(C) int printf(char*, ...);


///
void registerWidget(T)(char[] name = T.stringof) {
	//printf(`Registering widget: %.*s`\n, name);
	_widgetFactories[name] = function IWidget() { return new T; };
	//_widgetInserters[T.stringof] = function IWidget(size_t id)	{ return T.addImmediately_(id); };
}


///
IWidget createWidget(char[] name) {
	if (auto fact = name in _widgetFactories) {
		return (*fact)();
	} else {
		hybridError("createWidget: unknown widget type '{}'.", name);
		assert (false);
	}
}



///
private struct RegisteredWidgetIterator {
	///
	int opApply(int delegate(ref char[] name) dg) {
		foreach (k, v; _widgetFactories) {
			char[] n = k;
			if (auto res = dg(n)) {
				return res;
			}
		}
		
		return 0;
	}
}


///
RegisteredWidgetIterator registeredWidgets() {
	return RegisteredWidgetIterator();
}


/+Widget insertWidget_(char[] name, size_t id) {
	return _widgetInserters[name](id);
}+/


private {
	IWidget function()[char[]]			_widgetFactories;
	//IWidget function(size_t)[char[]]	_widgetInserters;
}
