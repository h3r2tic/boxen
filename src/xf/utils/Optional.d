module xf.utils.Optional;

private {
	import tango.core.Traits;
}



struct Optional(T) {
	alias T type;
	
	
	private {
		const bool isRefType = isReferenceType!(T);
		static if (isRefType) {
			alias T TRef;
			TRef getRef(T t) {
				return t;
			}
		} else {
			alias T* TRef;
			TRef getRef(ref T t) {
				return &t;
			}
		}
		
		T		_value;
		bool	_available = false;
	}
	
	
	TRef value() {
		if (available) {
			return getRef(_value);
		} else {
			assert (false);
		}
	}
	
	
	void value(T t) {
		_available = true;
		_value = t;
	}
	
	
	bool available() {
		return _available;
	}
	
	
	void reset() {
		_available = false;
		_value = _value.init;
	}
}
