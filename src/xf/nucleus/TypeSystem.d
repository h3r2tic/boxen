module xf.nucleus.TypeSystem;

private {
	import xf.Common;
	import
		xf.mem.MultiArray,
		xf.mem.ArrayAllocator;
	import
		xf.nucleus.Log : error = nucleusError, log = nucleusLog;
}



private template ScrapDgAllocator() {
	void* _reallocate(void* old, size_t oldBegin, size_t oldEnd, size_t bytes) {
		void* n = _outer._allocator(bytes);
		if (old) {
			assert (bytes > oldEnd);
			assert (oldBegin <= oldEnd);
			memcpy(n+oldBegin, old+oldBegin, oldEnd-oldBegin);
		}
		return n;
	}
	
	void _dispose(void* ptr) {}
}


struct Semantic {
	static Semantic opCall(Allocator allocator) {
		Semantic res;
		res._allocator = allocator;
		return res;
	}

	
	void	addTrait(cstring name, cstring value) {
		final i = _traits.growBy(1);
		_traits.name[i] = _allocString(name);
		_traits.value[i] = _allocString(value);
	}
	
	cstring	getTrait(cstring name) {
		for (uword i = 0; i < _traits.length; ++i) {
			if (_traits.name[i] == name) {
				return _traits.value[i];
			}
		}

		error("No trait named '{}'", name);
		assert (false);
	}
	
	bool	hasTrait(cstring name) {
		for (uword i = 0; i < _traits.length; ++i) {
			if (_traits.name[i] == name) {
				return true;
			}
		}
		return false;
	}
	
	bool	hasTrait(cstring name, cstring value) {
		for (uword i = 0; i < _traits.length; ++i) {
			if (_traits.name[i] == name && _traits.value[i] == value) {
				return true;
			}
		}
		return false;
	}
	
	void	removeTrait(cstring name) {
		assert (false, `TODO`);
	}
	
	TraitFruct	iterTraits() {
		return TraitFruct(this);
	}


	private {
		alias void* delegate(uword) Allocator;
		Allocator _allocator;

		cstring _allocString(cstring s) {
			char* p = cast(char*)_allocator(s.length);
			if (p is null) {
				error("Semantic._allocator returned null :(");
			}
			return p[0..s.length] = s;
		}

		int _iterTraits(int delegate(ref cstring name, ref cstring value) sink) {
			for (uword i = 0; i < _traits.length; ++i) {
				// TODO: copy the name and value to the stack
				if (int r = sink(_traits.name[i], _traits.value[i])) {
					return r;
				}
			}
			return 0;
		}

		mixin(multiArray("_traits",

		`	cstring	name
			cstring	value`,
			
			`ArrayExpandPolicy.FixedAmount!(4)`,
			`ScrapDgAllocator`
		));
	}
}


private struct TraitFruct {
	Semantic*	sem;

	int opApply(int delegate(ref cstring name, ref cstring value) sink) {
		return sem._iterTraits(sink);
	}
}
