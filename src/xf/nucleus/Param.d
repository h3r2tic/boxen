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
			assert (s.length > 0);
			
			char* p = cast(char*)_allocator(s.length);
			if (p is null) {
				error("Type._allocator returned null :(");
			}
			return p[0..s.length] = s;
		}
	}
}



interface IParamSupport {
	Param[] params();
	void overrideParams(Param[] p);
	uint numParams();
	int iterParams(int delegate(ref Param) dg);
	bool getInputParam(cstring name, ref Param res);
	bool getOutputParam(cstring name, ref Param res);
	void addParam(ParamDirection dir, cstring type, cstring name, Semantic sem);
	void addParam(cstring type, cstring name, Semantic sem);
	void addParam(cstring type, cstring name);
	void addParam(Param p);
	void removeParamKeepOrder(cstring name);
	void removeParams(bool delegate(ref Param) dg);
	Param* getParam(cstring name);
	int paramIndex(Param* p);
}



template MParamSupport() {
	static assert (is(typeof(this) == class));

	private import xf.nucleus.TypeSystem : Semantic;
	
	
	protected Param[]	_params;
	bool				_paramsOwner = true;
	
	Param[] params() {
		return _params;
	}
	
	void overrideParams(Param[] p) {
		_params = p;
		_paramsOwner = true;
	}
	
	typeof(this) dupParamsTo(typeof(this) o) {
		o._params = this._params.dup;
		foreach (ref p; o._params) {
			p = p.dup;
		}
		o._paramsOwner = false;
		return o;
	}
	
	uint numParams() {
		return _params.length;
	}
	
	int iterParams(int delegate(ref Param) dg) {
		foreach (ref p; _params) {
			if (auto r = dg(p)) {
				return r;
			}
		}
		return 0;
	}
	
	bool getInputParam(cstring name, ref Param res) {
		foreach (ref p; _params) {
			if (p.isInput && p.name == name) {
				res = p;
				return true;
			}
		}
		return false;
	}

	bool getOutputParam(cstring name, ref Param res) {
		foreach (ref p; _params) {
			if (!p.isInput && p.name == name) {
				res = p;
				return true;
			}
		}
		return false;
	}

	void addParam(ParamDirection dir, cstring type, cstring name, Semantic sem) {
		/+assert (name.length > 0);
		if (!_paramsOwner) {
			_params = _params.dup;
			_paramsOwner = true;
		}
		_params ~= xf.nucleus.CommonDef.Param(dir, type, name, sem);+/
		assert (false, "TODO");
	}


	void addParam(cstring type, cstring name, Semantic sem) {
		/+assert (name.length > 0);
		if (!_paramsOwner) {
			_params = _params.dup;
			_paramsOwner = true;
		}
		_params ~= xf.nucleus.CommonDef.Param(xf.nucleus.CommonDef.Param.Direction.In, type, name, sem);+/
		assert (false, "TODO");
	}


	void addParam(cstring type, cstring name) {
		/+assert (name.length > 0);
		if (!_paramsOwner) {
			_params = _params.dup;
			_paramsOwner = true;
		}
		_params ~= xf.nucleus.CommonDef.Param(xf.nucleus.CommonDef.Param.Direction.In, type, name, Semantic.init);+/
		assert (false, "TODO");
	}
	
	
	void addParam(Param p) {
		/+assert (p.name.length > 0, p.toString);
		if (!_paramsOwner) {
			_params = _params.dup;
			_paramsOwner = true;
		}
		_params ~= p;+/
		assert (false, "TODO");
	}
	
	
	void removeParamKeepOrder(cstring name) {
		foreach (i, ref p; _params) {
			if (p.name == name) {
				for (; i+1 < _params.length; ++i) {
					_params[i] = _params[i+1];
				}
				_params = _params[0..$-1];
				return;
			}
		}
		assert (false, name);
	}
	
	
	void removeParams(bool delegate(ref Param) dg) {
		int dst = 0;
		foreach (i, ref p; _params) {
			if (!dg(p)) {
				if (i != dst) {
					_params[dst++] = p;
				} else {
					++dst;
				}
			}
		}
		_params = _params[0..dst];
	}


	Param* getParam(cstring name) {
		foreach (ref p; _params) {
			if (p.name == name) {
				return &p;
			}
		}
		return null;
	}


	int paramIndex(Param* p)
	out (res) {
		assert (&_params[res] is p);
	} body {
		return p - _params.ptr;
	}
}
