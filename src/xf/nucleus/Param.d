module xf.nucleus.Param;

private {
	import xf.Common;
	import xf.nucleus.TypeSystem;
	import xf.nucleus.Log : error = nucleusError, log = nucleusLog;
	import xf.mem.Array;
	import xf.mem.ArrayAllocator;
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
	// Overlaps with Semantic and SemanticExp
	private alias void* delegate(uword) Allocator;
	private union {
		Semantic	_semantic;
		SemanticExp	_semanticExp;
		Allocator	_allocator;
	}

	ParamDirection	dir;
	bool			hasPlainSemantic = false;
	private cstring	_name;



	static Param opCall(Allocator allocator) {
		Param res;
		res._allocator = allocator;
		return res;
	}


	Param dup(Allocator allocator = null) {
		Param res;
		if (hasPlainSemantic) {
			res._semantic = this._semantic.dup(allocator);
		} else {
			res._semanticExp = this._semanticExp.dup(allocator);
		}
		res.hasPlainSemantic = hasPlainSemantic;
		res.dir = this.dir;
		res.name = this._name;
		return res;
	}


	Semantic* semantic() {
		assert (hasPlainSemantic, "Trying to access a plain semantic while it's an expression");
		return &_semantic;
	}

	SemanticExp* semanticExp() {
		assert (!hasPlainSemantic, "Trying to access a semantic expression while it's plain.");
		return &_semanticExp;
	}


	cstring name() {
		return _name;
	}

	void name(cstring n) {
		_name = _allocString(n);
	}


	bool hasTypeConstraint() {
		return semantic.hasTrait("type");
	}

	void removeTypeConstraint() {
		if (hasTypeConstraint) {
			semantic.removeTrait("type");
		}
	}	

	cstring type() {
		return semantic.getTrait("type");
	}

	void type(cstring t) {
		semantic.addTrait("type", t);
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

		if (hasPlainSemantic) {
			if (semantic.numTraits > 0) {
				sink("<");
				semantic.writeOut(sink);
				sink(">");
			}
		} else {
			if (semanticExp.numTraits > 0) {
				sink("<");
				semanticExp.writeOut(sink);
				sink(">");
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



/+interface IParamSupport {
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
}+/


struct ParamList {
	alias void* delegate(uword) Allocator;
	
	// Several pieces of code assume this layout. Don't touch :P
	union {
		Array!(
				Param,
				ArrayExpandPolicy.FixedAmount!(4),
				ScrapDgArrayAllocator
				
		)				_params;
		Allocator		_allocator;
	}


	static ParamList opCall(Allocator alloc, Param[] params = null) {
		ParamList res;
		res._allocator = alloc;

		// TODO: optimize me
		foreach (p; params) {
			res.add(p);
		}
		
		return res;
	}

	
	uword length() {
		return _params.length;
	}


	Param* opIndex(uword i) {
		assert (i < _params.length);
		return _params.ptr + i;
	}


	uword indexOf(Param* p) {
		return p - _params.ptr;
	}

	
	int opApply(int delegate(ref Param) dg) {
		foreach (ref p; _params) {
			if (auto r = dg(p)) {
				return r;
			}
		}
		return 0;
	}
	

	int opApply(int delegate(ref int, ref Param) dg) {
		foreach (ref i, ref p; _params) {
			if (auto r = dg(i, p)) {
				return r;
			}
		}
		return 0;
	}

	bool getInput(cstring name, Param** res) {
		foreach (ref p; _params) {
			if (p.isInput && p.name == name) {
				*res = &p;
				return true;
			}
		}
		return false;
	}

	bool getOutput(cstring name, Param** res) {
		foreach (ref p; _params) {
			if (!p.isInput && p.name == name) {
				*res = &p;
				return true;
			}
		}
		return false;
	}


	Param* add(ParamDirection dir, cstring name) {
		assert (name.length > 0);
		final pidx = _params.pushBack(Param(_allocator));
		final p = _params.ptr + pidx;
		p.dir = dir;
		p.name = name;
		return p;
	}

	
	Param* add(Param p) {
		assert (p.name.length > 0);
		final pidx = _params.pushBack(p.dup(_allocator));
		return _params.ptr + pidx;
	}
	
	
	void remove(cstring name) {
		foreach (i, ref p; _params) {
			if (p.name == name) {
				_params.removeKeepOrder(i);
				return;
			}
		}
		assert (false, name);
	}
	

	void removeNoThrow(cstring name) {
		foreach (i, ref p; _params) {
			if (p.name == name) {
				_params.removeKeepOrder(i);
				return;
			}
		}
	}

	
	void remove(bool delegate(ref Param) dg) {
		_params.removeKeepOrder(dg);
	}


	Param* get(cstring name) {
		foreach (ref p; _params) {
			if (p.name == name) {
				return &p;
			}
		}
		return null;
	}

	ParamList dup(Allocator allocator) {
		ParamList res;
		res._allocator = allocator;
		res._params.resize(length);
		
		foreach (int i, ref Param p; *this) {
			res._params[i] = p.dup(allocator);
		}

		return res;
	}
}


// TODO: mem
/+template MParamSupport() {
	static assert (
		is(typeof(this) == class)
		|| is(typeof(this.ThisStructHasReferenceSemantics))
	);

	private import xf.nucleus.TypeSystem : Semantic;
	private import xf.Common;
	
	
	protected Param[]	_params;
	bool				_paramsOwner = true;
	
	Param[] params() {
		return _params;
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


	Param* addParam(ParamDirection dir, cstring type, cstring name) {
		/+assert (name.length > 0);
		if (!_paramsOwner) {
			_params = _params.dup;
			_paramsOwner = true;
		}
		_params ~= xf.nucleus.CommonDef.Param(dir, type, name, sem);+/
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


	int paramIndex(Param* p) {
		final res = p - _params.ptr;
		assert (&_params[res] is p);
		return res;
	}
}+/



/**
 * Given an output parameter of a kernel function, possibly having a
 * SemanticExp and not yet a plain semantic, this utility can compute the resulting
 * static Semantic. It must have a way to query the semantics of formal and actual
 * parameters of the function the 'outputParam' belongs to - these must be provided
 * as delegates.
 * 
 * The result should have a valid allocator, which will be used in case
 * the outputParam doesn't yet have a plain semantic. If it does,
 * then the result will simply be assigned from the output param's semantic
 */
void findOutputSemantic(
	Param* outputParam,
	Semantic delegate(cstring name) getFormalParamSemantic,
	Semantic delegate(cstring name) getActualParamSemantic,
	Semantic* result
) {
	assert (!outputParam.isInput);
	
	if (outputParam.hasPlainSemantic) {
		*result = *outputParam.semantic();
	} else {
		final exp = outputParam.semanticExp();
		foreach (name, value, op; exp.iterTraits()) {
			switch (op) {
				case SemanticExp.TraitOp.Add: {
					cstring realName;
					
					if (name.startsWith("in.", &realName)) {
						Semantic parSem;
						
						if (realName.endsWith(".actual", &realName)) {
							parSem = getActualParamSemantic(realName);
						} else {
							parSem = getFormalParamSemantic(realName);
						}

						foreach (n, v; parSem.iterTraits) {
							result.addTrait(n, v);
						}
					} else {
						result.addTrait(name, value);
					}
				} break;

				case SemanticExp.TraitOp.Remove: {
					void rem(cstring n, cstring v) {
						if (v.length > 0) {
							if (result.hasTrait(n, v)) {
								result.removeTrait(n);
							}
						} else {
							if (result.hasTrait(n)) {
								result.removeTrait(n);
							}
						}
					}

					cstring realName;
					
					if (name.startsWith("in.", &realName)) {
						Semantic parSem;
						
						if (realName.endsWith(".actual", &realName)) {
							parSem = getActualParamSemantic(realName);
						} else {
							parSem = getFormalParamSemantic(realName);
						}

						foreach (n, v; parSem.iterTraits) {
							rem(n, v);
						}
					} else {
						rem(name, value);
					}
				} break;

				default: assert (false);
			}
		}
	}
}
