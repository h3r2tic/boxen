module xf.nucleus.Param;

private {
	import xf.Common;
	import xf.nucleus.TypeSystem;
	import xf.nucleus.Log : error = nucleusError, log = nucleusLog;
	import xf.mem.Array;
	import xf.mem.ArrayAllocator;

	extern (C) extern size_t strlen(char*);
}



enum ParamDirection : ubyte {
	In, Out, InOut
}

enum ParamValueType : ubyte {
	Float,
	Float2,
	Float3,
	Float4,
	String,
	Ident,
	ObjectRef
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
	// TODO: tags / non-trait semantics


	// Overlaps with Semantic and SemanticExp
	private alias void* delegate(uword) Allocator;
	private union {
		Semantic	_semantic;
		SemanticExp	_semanticExp;
		Allocator	_allocator;
	}

	private cstring	_name;
	
	void*			value;

	ParamDirection	dir;
	ParamValueType	valueType;
	bool			hasPlainSemantic = false;


	uword valueSize() {
		if (value) {
			switch (valueType) {
				case ParamValueType.Float:	return 4;
				case ParamValueType.Float2: return 8;
				case ParamValueType.Float3: return 12;
				case ParamValueType.Float4: return 16;
				case ParamValueType.Ident:	// fall through
				case ParamValueType.String: return 1+strlen(cast(char*)value);
				case ParamValueType.ObjectRef: return 0;
				default: assert (false);
			}
		} else return 0;
	}


	static Param opCall(Allocator allocator) {
		Param res;
		res._allocator = allocator;
		return res;
	}


	bool opEquals(ref Param other) {
		if (
				_name != other._name
			||	dir != other.dir
			|| (value is null) != (other.value is null)
			|| hasPlainSemantic != other.hasPlainSemantic
		) {
			return false;
		}

		if (hasPlainSemantic) {
			if (_semantic != other._semantic) {
				return false;
			}
		} else {
			if (_semanticExp != other._semanticExp) {
				return false;
			}
		}

		if (value !is null) {
			if (valueType != other.valueType) {
				return false;
			}

			uword vs = valueSize();
			if (vs != other.valueSize()) {
				return false;
			}

			if (value[0..vs] != other.value[0..vs]) {
				return false;
			}
		}

		return true;
	}


	void copyValueFrom(Param* p) {
		if (p.value) {
			if (p.valueType != ParamValueType.ObjectRef) {
				uword size = p.valueSize;
				value = _allocator(size);
				memcpy(value, p.value, size);
				valueType = p.valueType;
			} else {
				value = p.value;
				valueType = p.valueType;
			}
		} else {
			value = null;
		}
	}


	void setValue(float val) {
		valueType = ParamValueType.Float;
		value = _allocator(4);
		*(cast(float*)value) = val;
	}

	void setValue(float a, float b) {
		valueType = ParamValueType.Float2;
		value = _allocator(8);
		*cast(float*)(value+0) = a;
		*cast(float*)(value+4) = b;
	}

	void setValue(float a, float b, float c) {
		valueType = ParamValueType.Float3;
		value = _allocator(12);
		*cast(float*)(value+0) = a;
		*cast(float*)(value+4) = b;
		*cast(float*)(value+8) = c;
	}

	void setValue(float a, float b, float c, float d) {
		valueType = ParamValueType.Float4;
		value = _allocator(16);
		*cast(float*)(value+0) = a;
		*cast(float*)(value+4) = b;
		*cast(float*)(value+8) = c;
		*cast(float*)(value+12) = d;
	}

	void setValue(cstring val) {
		valueType = ParamValueType.String;
		value = _allocator(val.length+1);
		memcpy(value, val.ptr, val.length);
		*cast(char*)(value+val.length) = 0;
	}

	void setValueIdent(cstring val) {
		valueType = ParamValueType.Ident;
		value = _allocator(val.length+1);
		memcpy(value, val.ptr, val.length);
		*cast(char*)(value+val.length) = 0;
	}

	void setValue(Object val) {
		valueType = ParamValueType.ObjectRef;
		value = cast(void*)val;
	}


	void getValue(float* val) {
		assert (ParamValueType.Float == valueType);
		*val = *cast(float*)value;
	}

	void getValue(float* a, float* b) {
		assert (ParamValueType.Float2 == valueType);
		*a = *cast(float*)(value+0);
		*b = *cast(float*)(value+4);
	}

	void getValue(float* a, float* b, float* c) {
		assert (ParamValueType.Float3 == valueType);
		*a = *cast(float*)(value+0);
		*b = *cast(float*)(value+4);
		*c = *cast(float*)(value+8);
	}

	void getValue(float* a, float* b, float* c, float* d) {
		assert (ParamValueType.Float4 == valueType);
		*a = *cast(float*)(value+0);
		*b = *cast(float*)(value+4);
		*c = *cast(float*)(value+8);
		*d = *cast(float*)(value+12);
	}

	void getValue(cstring* val) {
		assert (ParamValueType.String == valueType);
		*val = fromStringz(cast(char*)value);
	}

	void getValueIdent(cstring* val) {
		assert (ParamValueType.Ident == valueType);
		*val = fromStringz(cast(char*)value);
	}

	void getValue(Object* val) {
		assert (ParamValueType.ObjectRef == valueType);
		*val = cast(Object)value;
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
		res.copyValueFrom(this);
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
		return dir != ParamDirection.Out;
	}

	
	bool isOutput() {
		return dir != ParamDirection.In;
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


	bool opEquals(ref ParamList other) {
		if (length != other.length) {
			return false;
		}

		foreach (i, ref p; _params) {
			if (p != other._params.ptr[i]) {
				return false;
			}
		}

		return true;
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
			if (p.isOutput && p.name == name) {
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
	assert (outputParam.isOutput);
	
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
