module xf.nucleus.TypeSystem;

private {
	import xf.Common;
	import
		xf.mem.Array,
		xf.mem.MultiArray,
		xf.mem.ArrayAllocator;
	import
		xf.utils.IntrusiveHash;
	import
		xf.nucleus.DataTypes,
		xf.nucleus.Log : error = nucleusError, log = nucleusLog;
		
	import Ascii = tango.text.Ascii;
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

private template ScrapDgArrayAllocator() {
	private import xf.Common;
	
	void* delegate(uword) _outerAllocator;
	
	void* _reallocate(void* old, size_t oldBegin, size_t oldEnd, size_t bytes) {
		void* n = _outerAllocator(bytes);
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
	// Overlaps with Param
	private {
		alias void* delegate(uword) Allocator;
		Allocator _allocator;
	}

	
	static Semantic opCall(Allocator allocator) {
		Semantic res;
		res._allocator = allocator;
		return res;
	}


	Semantic dup(Allocator allocator = null) {
		Semantic res;
		res._allocator = allocator is null ? _allocator : allocator;
		uword numTraits = _traits.length;
		res._traits.resize(numTraits);
		for (uword i = 0; i < numTraits; ++i) {
			res._traits.name[i] = res._allocString(_traits.name[i]);
			res._traits.value[i] = res._allocString(_traits.value[i]);
		}
		return res;
	}

	
	void	addTrait(cstring name, cstring value) {
		assert (name.length > 0);
		
		uword found = _lowerBoundBinarySearch(name);
		if (found < _traits.length) {
			if (_traits.name[found] == name) {
				if (_traits.value[found] != value) {
					_traits.value[found] = _allocString(value);
				}
				
				return;		// short-circuit
			} else {
				_traits.growBy(1);

				for (uword i = _traits.length-1; i > found; --i) {
					_traits.name[i] = _traits.name[i-1];
					_traits.value[i] = _traits.value[i-1];
				}
			}
		} else {
			_traits.growBy(1);
		}

		_traits.name[found] = _allocString(name);
		_traits.value[found] = _allocString(value);

		// TODO: wrap it in some version (DebugSemantics)
		_verifyOrder();
	}
	
	cstring	getTrait(cstring name) {
		uword found = _lowerBoundBinarySearch(name);
		
		if (found < _traits.length && _traits.name[found] == name) {
			return _traits.value[found];
		} else {
			error("No trait named '{}'", name);
			assert (false);
		}
	}
	
	bool	hasTrait(cstring name) {
		uword found = _lowerBoundBinarySearch(name);
		
		if (found < _traits.length && _traits.name[found] == name) {
			return true;
		} else {
			return false;
		}
	}
	
	bool	hasTrait(cstring name, cstring value) {
		uword found = _lowerBoundBinarySearch(name);
		
		if (found < _traits.length && _traits.name[found] == name) {
			return _traits.value[found] == value;
		} else {
			return false;
		}
	}
	
	void	removeTrait(cstring name) {
		uword found = _lowerBoundBinarySearch(name);
		uword numTraits = _traits.length;
		if (found < numTraits && _traits.name[found] == name) {
			if (found != numTraits-1) {
				for (; found < numTraits-1; ++found) {
					_traits.name[found] = _traits.name[found+1];
					_traits.value[found] = _traits.value[found+1];
				}
			}

			_traits.resize(numTraits-1);

			// TODO: wrap it in some version (DebugSemantics)
			_verifyOrder();
		} else {
			error("Semantic.removeTrait: trait does not exist: '{}'", name);
		}
	}

	private struct TraitFruct {
		Semantic*	sem;

		int opApply(int delegate(ref cstring name, ref cstring value) sink) {
			return sem._iterTraits(sink);
		}
	}
	
	TraitFruct	iterTraits() {
		return TraitFruct(this);
	}


	uword numTraits() {
		return _traits.length;
	}


	bool opEquals(ref Semantic s) {
		if (_traits.length != s._traits.length) {
			return false;
		}

		uword num = _traits.length;
		for (uword i = 0; i < num; ++i) {
			if (_traits.name[i] != s._traits.name[i]) {
				return false;
			}

			if (_traits.value[i] != s._traits.value[i]) {
				return false;
			}
		}

		return true;
	}


	hash_t toHash() {
		hash_t hash = 0;
		final strHash = &typeid(char[]).getHash;
		
		foreach (ref n, ref v; iterTraits) {
			hash += strHash(&n);
			hash += strHash(&v);
		}

		return hash;
	}


	void writeOut(void delegate(cstring) sink) {
		uword i = 0;
		foreach (k, v; iterTraits) {
			if (i++ > 0) {
				sink(" + ");
			}

			sink(k);
			sink(":");
			sink(v);
		}
	}


	// don't use where performance matters
	cstring toString() {
		char[] str;
		writeOut((cstring s) { str ~= s; });
		return str;
	}


	private {
		cstring _allocString(cstring s) {
			if (s.length > 0) {
				char* p = cast(char*)_allocator(s.length);
				if (p is null) {
					error("Semantic._allocator returned null :(");
				}
				return p[0..s.length] = s;
			} else {
				return null;
			}
		}

		uword _lowerBoundBinarySearch(cstring name) {
			final names = _traits.name;
			uword l = 0;
			uword r = _traits.length;

			if (0 == r - l) {
				return 0;
			}

		iter:
			uword w = r - l;
			assert (w > 0);
			
			if (1 == w) {
				if (Ascii.compare(name, names[l]) <= 0) {
					return l;
				} else {
					return r;
				}
			}

			int mid = (l + r - 1) / 2;
			int cmp = Ascii.compare(name, names[mid]);
			
			if (cmp < 0) {
				if (2 == w) {
					assert (mid == l);
					return mid;
				} else {
					r = mid;
					goto iter;
				}
			} else if (cmp > 0) {
				l = mid+1;
				goto iter;
			} else {
				return mid;
			}
		}

		void _verifyOrder() {
			uword num = _traits.length;
			for (uword i = 1; i < num; ++i) {
				assert (Ascii.compare(_traits.name[i-1], _traits.name[i]) < 0);
			}
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


		// For the type conversion implicit graph search algorighm
		mixin MIntrusiveHash!(void*);
	}
}


struct SemanticExp {
	enum TraitOp {
		Add,
		Remove
	}

	struct Item {
		cstring	name;
		cstring value;
		TraitOp	op;
	}

	// Overlaps with Param
	private {
		alias void* delegate(uword) Allocator;
		union {
			Array!(
					Item,
					ArrayExpandPolicy.FixedAmount!(4),
					ScrapDgArrayAllocator
					
			)				_traits;
			Allocator		_allocator;
		}
	}

	// Check the implied overlap of the Array's mixed in allocator and the _allocator
	static assert (SemanticExp.init._traits.offsetof == 0);
	static assert (SemanticExp.init._traits._outerAllocator.offsetof == 0);
	static assert (is(typeof(_traits._outerAllocator) == SemanticExp.Allocator));

	
	static SemanticExp opCall(Allocator allocator) {
		SemanticExp res;
		res._allocator = allocator;
		return res;
	}


	SemanticExp dup(Allocator allocator = null) {
		SemanticExp res;
		res._allocator = allocator is null ? _allocator : allocator;
		uword numTraits = _traits.length;
		res._traits.resize(numTraits);
		for (uword i = 0; i < numTraits; ++i) {
			res._traits[i].name = res._allocString(_traits[i].name);
			res._traits[i].value = res._allocString(_traits[i].value);
			res._traits[i].op = _traits[i].op;
		}
		return res;
	}

	
	void	addTrait(cstring name, cstring value, TraitOp op) {
		assert (name.length > 0);
		final i = _traits.growBy(1);
		_traits[i].name = _allocString(name);
		_traits[i].value = _allocString(value);
		_traits[i].op = op;
	}

	private struct TraitFruct {
		SemanticExp*	sem;

		int opApply(int delegate(ref cstring, ref cstring, ref TraitOp) sink) {
			return sem._iterTraits(sink);
		}
	}
	
	TraitFruct	iterTraits() {
		return TraitFruct(this);
	}


	uword numTraits() {
		return _traits.length;
	}


	void writeOut(void delegate(cstring) sink) {
		uword i = 0;
		foreach (k, v, op; iterTraits) {
			switch (op) {
				case TraitOp.Add: {
					if (i++ > 0) {
						sink(" + ");
					}
				} break;

				case TraitOp.Remove: {
					sink(" - ");
					++i;
				} break;

				default: assert (false, "Added a new Semantic op? :O");
			}

			sink(k);
			sink(":");
			sink(v);
		}
	}


	// don't use where performance matters
	cstring toString() {
		char[] str;
		writeOut((cstring s) { str ~= s; });
		return str;
	}


	private {
		cstring _allocString(cstring s) {
			if (s.length > 0) {
				char* p = cast(char*)_allocator(s.length);
				if (p is null) {
					error("SemanticExp._allocator returned null :(");
				}
				return p[0..s.length] = s;
			} else {
				return null;
			}
		}

		int _iterTraits(int delegate(ref cstring, ref cstring, ref TraitOp) sink) {
			for (uword i = 0; i < _traits.length; ++i) {
				// TODO: copy the name and value to the stack
				if (int r = sink(_traits[i].name, _traits[i].value, _traits[i].op)) {
					return r;
				}
			}
			return 0;
		}
	}
}




interface ISemanticComparator {
	bool missing(cstring name, cstring value);
	bool additional(cstring name, cstring value);
	bool existing(cstring name, cstring val1, cstring val2);
}


void compareSemantics(Semantic s1, Semantic s2, ISemanticComparator comp) {
	auto nArr1 = s1._traits.name[0..s1._traits.length];
	auto nArr2 = s2._traits.name[0..s2._traits.length];
	auto vArr1 = s1._traits.value[0..s1._traits.length];
	auto vArr2 = s2._traits.value[0..s2._traits.length];
	
	while (nArr1.length > 0 && nArr2.length > 0) {
		int cval = Ascii.compare(nArr1[0], nArr2[0]);
		
		if (cval < 0) {
			bool res = comp.additional(nArr1[0], vArr1[0]);
			if (!res) return;
			nArr1 = nArr1[1..$];
			vArr1 = vArr1[1..$];
		} else if (cval > 0) {
			bool res = comp.missing(nArr2[0], vArr2[0]);
			if (!res) return;
			nArr2 = nArr2[1..$];
			vArr2 = vArr2[1..$];
		} else {
			bool res = comp.existing(nArr1[0], vArr1[0], vArr2[0]);
			if (!res) return;
			nArr1 = nArr1[1..$];
			vArr1 = vArr1[1..$];

			nArr2 = nArr2[1..$];
			vArr2 = vArr2[1..$];
		}
	}
	
	foreach (i, n; nArr1) {
		bool res = comp.additional(n, vArr1[i]);
		if (!res) return;
	}

	foreach (i, n; nArr2) {
		bool res = comp.missing(n, vArr2[i]);
		if (!res) return;
	}
}


bool canPassSemanticFor(
		Semantic arg,
		Semantic param,
		bool acceptAdditional,
		int* extraCost = null,
		Semantic* modOutput = null
) {
	bool result = true;
	
	class Comparator : ISemanticComparator {
		bool missing(cstring name, cstring value) {
			//log.trace("sem is missing trait {}", t);
			return result = false;
		}
		bool additional(cstring name, cstring value) {
			//log.trace("sem has an additional trait {}", t);
			if (acceptAdditional) {
				if (extraCost !is null) {
					++*extraCost;
				}
				
				if (modOutput) {
					modOutput.addTrait(name, value);
				}
				
				return result = true;
			} else {
				return result = false;
			}
		}
		bool existing(cstring name, cstring val1, cstring val2) {
			if ("type" == name) {
				void tryNormalize(cstring type, void delegate(string) sink) {
					TypeParsingError err;
					if (!normalizeTypeName(type, sink, &err)) {
						sink(cast(string)type);
					}
				}

				tryNormalize(val1, (string type1) {
					tryNormalize(val2, (string type2) {
						if (true == (result = (type1 == type2))) {
							if (modOutput) {
								// cast valid since addTrait copies the string
								modOutput.addTrait(name, type2);
							}
						}
					});
				});
				
				return result;
			} else {
				//log.trace("t.{}  vs  t2.{}", t, t2);
				if (true == (result = (val1 == val2))) {
					if (modOutput) {
						modOutput.addTrait(name, val2);
					}
				}
				
				return result;
			}
		}
	}
	
	scope comp = new Comparator;
	compareSemantics(arg, param, comp);

	return result;
}
