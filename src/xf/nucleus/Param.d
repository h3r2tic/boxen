module xf.nucleus.Param;

private {
	import xf.Common;
	import xf.nucleus.TypeSystem;
	import xf.nucleus.Log : error = nucleusError;
}



enum ParamDirection {
	In, Out, InOut
}


cstring toString(ParamDirection dir) {
	switch (dir) {
		case ParamDirection.In: return "in";
		case ParamDirection.Out: return "out";
		case ParamDirection.InOut: return "inout";
		default: assert (false);
	}
}


ParamDirection ParamDirectionFromString(cstring str) {
	switch (str) {
		case "in": return ParamDirection.In;
		case "out": return ParamDirection.Out;
		case "inout": return ParamDirection.InOut;
		default: error("Invalid ParamDirection string: '{}'", str); assert (false);
	}
}


struct Param {
	// Overlaps with Semantic
	private alias void* delegate(uword) Allocator;
	private union {
		Semantic	_semantic;
		Allocator	_allocator;
	}

	ParamDirection	dir;
	private cstring	_name;



	static Param opCall(Allocator allocator) {
		Param res;
		res._allocator = allocator;
		return res;
	}


	Param dup(Allocator allocator = null) {
		Param res;
		res._semantic = this._semantic.dup(allocator);
		res.dir = this.dir;
		res._name = res._allocString(this.name);
		return res;
	}



	cstring name() {
		return _name;
	}

	void name(cstring n) {
		_name = _allocString(n);
	}


	bool hasTypeConstraint() {
		return _semantic.hasTrait("type");
	}

	void removeTypeConstraint() {
		if (hasTypeConstraint) {
			_semantic.removeTrait("type");
		}
	}	

	cstring type() {
		return _semantic.getTrait("type");
	}

	void type(cstring t) {
		_semantic.addTrait("type", t);
	}


	cstring dirStr() {
		return .toString(dir);
	}


	bool isInput() {
		return ParamDirection.In == dir;
	}
	

	// TODO: default value
	// TODO: tags / non-trait semantics

	bool opEquals(ref Param) {
		assert (false, "TODO");
	}


	void writeOut(void delegate(cstring) sink) {
		sink(dirStr);
		sink(" ");
		sink(name);

		if (_semantic.numTraits > 0) {
			sink("<");
			uword i = 0;
			foreach (k, v; _semantic.iterTraits) {
				if (i++ > 0) {
					sink(" + ");
				}

				sink(k);
				sink(":");
				sink(v);
			}
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
			char* p = cast(char*)_allocator(s.length);
			if (p is null) {
				error("Type._allocator returned null :(");
			}
			return p[0..s.length] = s;
		}
	}
}
