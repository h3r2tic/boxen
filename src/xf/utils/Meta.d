module xf.utils.Meta;

private {
	import
		tango.core.Traits,
		tango.core.Tuple;
}



// ----------------------------------------------------------------------------------------------------------------
// From scrapple.tools

template isArray(T) { const bool isArray=false; }
template isArray(T: T[]) { const bool isArray=true; }

template isPointer(T) { const bool isPointer=false; }
template isPointer(T: T*) { const bool isPointer=true; }

char[] fmtLong(long l) {
  if (l<0) return "-"~fmtLong(-l);
  char[] res;
  do {
    res = "0123456789"[cast(int)(l%10)] ~ res;
    l /= 10;
  } while (l);
  return res;
}

char[] fmtReal(real r) {
  if (r != r) return "NaN";
  if (r > real.max) return "Inf";
  if (r<0) return "-"~fmtReal(-r);
  char[] res;
  auto rest = r - cast(long) r;
  for (int i=0; i<10; ++i) {
    rest *= 10;
    if (!(rest>=0 && rest<10)) return "ERROR";
    res ~= "0123456789"[cast(int) rest];
    rest -= cast(int) rest;
  }
  while (res.length && res[$-1] == 0) res = res[0..$-1];
  return fmtLong(cast(long) r) ~ "." ~ res;
}


char[] Format(T...)(T t) {
	char[] res;
	foreach (i, elem; t) {
		alias typeof(elem) E;
		static if (is(E: char[])) res ~= elem; else
			//static if (isPointer!(E)) res ~= fmtPointer(cast(void*) elem); else
				static if (isArray!(E)) {
					res ~= "[";
					foreach (i2, v; elem) {
						res ~= Format(v);
						if (i2 < elem.length - 1) res ~= ", ";
					}
					res ~= "] ";
				} else static if (is(typeof(elem.keys))) {
						res ~= "[";
						bool first=true;
						foreach (key, value; elem) {
							if (first) first=false;
							else res ~= ", ";
							res ~= Format(key, ": ", value);
						}
						res ~= "] ";
					} else static if (is(typeof(elem.toString()): char[])) {
							res ~= elem.toString();
						} else static if (is(E: long)) res ~= fmtLong(elem); else
								static if (is(E: real)) res ~= fmtReal(elem); else
									res ~= "[Unsupported: "~E.stringof~"] ";
	}
	return res;
}

template Unstatic(T) { alias T Unstatic; }
template Unstatic(T: T[]) { alias T[] Unstatic; }

template StupleMembers(T...) {
	static if (T.length) {
		const int id=T[0..$-1].length;
		const char[] str=StupleMembers!(T[0..$-1]).str~"Unstatic!(T["~id.stringof~"]) _"~id.stringof~"; ";
	} else const char[] str="";
}

struct Stuple(T...) {
	alias Tuple!() StupleMarker;
	mixin(StupleMembers!(T).str);
	char[] toString() {
		char[] res="stuple(";
		foreach (id, entry; this.tupleof) {
			if (id) res ~= ", ";
			res ~= Format(entry);
		}
		return res~")";
	}
	
	
	Ret opShr(Ret, Par ...)(Ret delegate(Par) dg) {
		return dg(this.tupleof);
	}
	
	Ret opShr(Ret, Par ...)(Ret function(Par) dg) {
		return dg(this.tupleof);
	}
}


template UnstaticAll(T ...) {
	static if (T.length > 1) {
		alias Tuple!(UnstaticAll!(T[0..$-1]), Unstatic!(T[$-1])) UnstaticAll;
	} else {
		alias Unstatic!(T[0]) UnstaticAll;
	}
}


Stuple!(UnstaticAll!(T)) stuple(T ...)(T t) {
	return Stuple!(UnstaticAll!(T))(t);
}


template Repeat(T, int count) {
	static if (!count) alias Tuple!() Repeat;
	else alias Tuple!(T, Repeat!(T, count-1)) Repeat;
}

Stuple!(Repeat!(T, U.length)) toTStuple(T, U...)(U u) {
	Stuple!(Repeat!(T, U.length)) res = void;
	foreach (i, v; u)
		res.tupleof[i] = cast(T) v;
	return res;
}


// ----------------------------------------------------------------------------------------------------------------
// delegate to function conversion without extra allocations


///
Ret delegate(Par) functionToDelegate(Ret, Par ...)(Ret function(Par) func) {
	struct Foo {
		void* _placeholder;
		static assert (Foo.sizeof == typeof(func).sizeof);
		Ret wrapper(Par p) {
			return (cast(Ret function(Par))this)(p);
		}
	}
	return &(cast(Foo*)cast(void*)func).wrapper;
}



// ----------------------------------------------------------------------------------------------------------------


template createFructIteratorImpl(char[] name) {
	mixin("alias ParameterTupleOf!(this._"~name~") _Params;");
	alias typeof(this) _ThisType;
	
	static int function(_Params) _getIterFunc() {
		return mixin("&_ThisType._" ~ name);
	}
	
	struct _Fruct {
		_ThisType				_this;
		_Params[0..$-1]	params;

		int opApply(_Params[$-1] dg) {
			int delegate(_Params) handler;
			handler.funcptr = _getIterFunc;
			handler.ptr = cast(void*)_this;
			return handler(params, dg);
		}
	}
}


/**
	Example:
	---
	private int _edgeHedges(HEdge* first, int delegate(ref HEdge*) dg) {
		HEdge* foo;
		dg(foo);
		dg(foo);
		return 0;
	}
	mixin createFructIterator!(`edgeHedges`);
	---
*/
template createFructIterator(char[] name) {
	private {
		import tango.core.Traits : ParameterTupleOf;
		import xf.utils.Meta : createFructIteratorImpl;
		
		mixin(`
			static if (!is(typeof(this._`~name~`))) {
				static assert (false, "class `~typeof(this).stringof~` does not contain a function _`~name~` required for the fruct");
			} else {
				mixin createFructIteratorImpl!(name);
			}
		`);
	}

	mixin(`_Fruct `~name~`(_Params[0..$-1] params) {
		return _Fruct(this, params);
	}`);
}
