module xf.hybrid.AutoOverride;

pragma (ctfe)
void	FuncArgType_(Ret)		(Ret function())		{}

pragma (ctfe)
T0	FuncArgType_(Ret, T0)		(Ret function(T0))		{ return T0.init; }

pragma (ctfe)
T0	FuncArgRefType_(Ret, T0)	(Ret function(ref T0))	{ return T0.init; }

template FuncArgType(T) {
	alias typeof(FuncArgType_(T.init)) FuncArgType;
}
template FuncArgRefType(T) {
	alias typeof(FuncArgRefType_(T.init)) FuncArgRefType;
}

//version  =DebugAutoOverride;

template autoOverride(char[] _fname, char[] _paramName = "") {
	private import xf.hybrid.AutoOverride : FuncArgType, FuncArgRefType;
	private alias typeof(this) ThisType;

	struct _AutoOverride {
		static if (_paramName.length > 0) {
			version (DebugAutoOverride) pragma (msg, `ok, using a custom param name`);
			//private const char[] _param = _paramName;
			mixin ("alias " ~ _paramName ~ " argType;");
		} else {
			version (DebugAutoOverride) pragma (msg, `no custom param name. trying to guess`);
			static if (
				mixin("is(FuncArgType!(typeof(&"~ _fname ~")) ParamType)")
				|| mixin("is(FuncArgRefType!(typeof(&"~ _fname ~")) ParamType)")
			) {
				static if (!is(ParamType == void)) {
					version (DebugAutoOverride) pragma (msg, `guessing the param to be ` ~ ParamType.stringof);
					private static ParamType _paramValInst;
					private const char[] _paramVal = `_paramValInst`;
				} else {
					version (DebugAutoOverride) pragma (msg, `guessing the param to be void`);
					private const char[] _paramVal = ``;
				}
				
				version (DebugAutoOverride) pragma (msg, "func param val: '" ~ _paramVal ~ "'");
				
				static if (mixin("is(ThisType : typeof("~_fname~"("~_paramVal~")))")) {
					version (DebugAutoOverride) pragma (msg, `func returns typeof(this)`);
					//private const char[] _param = ParamType.stringof;
					alias ParamType argType;
				} else {
					mixin("private alias typeof("~_fname~"("~_paramVal~")) FuncRetVal;");
					version (DebugAutoOverride) pragma (msg, `func doesnt return typeof(this), but ` ~ FuncRetVal.stringof);
					
					private static FuncRetVal _funcRetVal;
					static if (is(typeof(mixin(_fname~"(_funcRetVal)")))) {
						version (DebugAutoOverride) pragma (msg, "func appears to have a setter too");
						static if (mixin("is(ThisType : typeof("~_fname~"(_funcRetVal)))")) {
							version (DebugAutoOverride) pragma (msg, "great! the setter returns typeof(this)");
							//private const char[] _param = FuncRetVal.stringof;
							alias FuncRetVal argType;
						} else {
							version (DebugAutoOverride) pragma (msg, "bummer, the setter doesn't return typeof(this)");
						}
					} else {
						version (DebugAutoOverride) pragma (msg, "func doesn't seem to have a setter");
					}
				}
			}
		}
		
		static if (is(argType)) {
			static if (is(argType == void)) {
				const bool argRef = false;
			} else {
				version (DebugAutoOverride) pragma (msg, "the func has a " ~ argType.stringof ~ " param");
				
				static if (mixin("is(typeof("~_fname~"(argType.init)))")) {
					version (DebugAutoOverride) pragma (msg, "the param is passed by value");
					const bool argRef = false;
				} else {
					private static argType _paramValInst2;
					static if (mixin("is(typeof("~_fname~"(_paramValInst2)))")) {
						version (DebugAutoOverride) pragma (msg, "the param is passed by reference");
						const bool argRef = true;
					} else {
						static assert (false, _fname);
					}
				}
			}
		} else {
			version (DebugAutoOverride) pragma (msg, "damn, something went wrong. could not deduce the param type");
		}
		
		const char[]	_AutoOverride_fname = _fname;
	}
	
	_AutoOverride _autoOverride;
}


pragma (ctfe) char[] resolveAutoOverrideCodegen(char[] thisType, T ...)() {
	char[] res = "";
	foreach (Field; T) {
		static if (is(typeof(Field._AutoOverride_fname) == char[])) {
			const char[] fname = Field._AutoOverride_fname;

			/+static if (is(void == Field.argType)) {
				static if (mixin("is("~fname~"() : "~thisType~")")) {
					res ~= "pragma(msg, `* skipping override generation for "~fname~"`)";
					res ~= "static if (false) {";
				} else {
					res ~= "static if (true) {";
				}
			} else {
				mixin("alias typeof(this.init."~fname~"(("~Field.argType.stringof~").init)) zomg;");
				static if (mixin("is(typeof("~fname~"(("~Field.argType.stringof~").init)) : "~thisType~")")) {
					res ~= "pragma(msg, `* skipping override generation for "~fname~"`)";
					res ~= "static if (false) {";
				} else {
					res ~= "static if (true) {";
				}
			}+/
			
			version (DebugAutoOverride) pragma (msg, "generating an override for " ~ fname ~ " in " ~ thisType);
			
			static if (is(void == Field.argType)) {
				version (DebugAutoOverride) pragma (msg, "parameter-less func");
				res ~= "override " ~ thisType ~ " " ~ fname ~ "(){";
				res ~= "if (auto res=super." ~ fname ~ "()){if(auto res2=cast(typeof(this))res){return res2;}";
	//			res ~= "return this; }";
			} else {
				static if (Field.argRef) {
					version (DebugAutoOverride) pragma (msg, "ref-param func");
					res ~= "override " ~ thisType ~ " " ~ fname ~ "(ref "~Field.argType.stringof~" _arg){";
					res ~= "if (auto res=super." ~ fname ~ "(_arg)){if(auto res2=cast(typeof(this))res){return res2;}";
//				res ~= "return this; }";
				} else {
					version (DebugAutoOverride) pragma (msg, "value-param func");
					res ~= "override " ~ thisType ~ " " ~ fname ~ "("~Field.argType.stringof~" _arg){";
					res ~= "if (auto res=super." ~ fname ~ "(_arg)){if(auto res2=cast(typeof(this))res){return res2;}";
					//res ~= "return this; }";

				}
			}

			res ~= "else{assert(false, `autoOverride for function '"~fname~"': The result is not typeof(this)`);}}else return null;}";

			res ~= "static if (!is(typeof(this)._SuperType)) private alias typeof(super) _SuperType;";
			res ~= `alias _SuperType.`~fname~` `~fname~`;`;
			
			//res ~= "}";
		}
		res ~= "\n";
	}
	return res;
}


template resolveAutoOverride(ThisType, T) {
	static if (!is(T == Object)) {
		version (DebugAutoOverride) pragma (msg, "resolveAutoOverride " ~ T.stringof);
		static if (is(typeof(T.autoOverrideFlush_data) FlushData)) {
			version (DebugAutoOverride) pragma (msg, FlushData.TypeOfThis.stringof ~ " vs " ~ T.stringof);
			static if (is(FlushData.TypeOfThis == T)) {
				version (DebugAutoOverride) pragma(msg, `resolveAutoOverrideCodegen for ` ~ T.stringof);
				const char[] part = resolveAutoOverrideCodegen!(ThisType.stringof, FlushData.TypeTupleOf)();
			} else {
				const char[] part = "";
			}
		} else {
			const char[] part = "";
		}

		static if (is(T S == super)) {
			const char[] res = part ~ resolveAutoOverride!(ThisType, S[0]).res;
		} else {
			const char[] res = part;
		}
	} else {
		const char[] res = "";
	}
}


template resolveAutoOverride() {
	mixin(resolveAutoOverride!(typeof(this), typeof(this)).res);
	version (DebugAutoOverride) pragma (msg, "");
}


template autoOverrideFlush() {
	struct _AutoOverrideFlush(ThisType) {
		alias typeof(ThisType.tupleof)	TypeTupleOf;
		alias ThisType						TypeOfThis;
	}
	static _AutoOverrideFlush!(typeof(this)) autoOverrideFlush_data;
}
