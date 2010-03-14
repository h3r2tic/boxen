private static uword _md_constructor(MDThread* t, uword numParams) {
	checkInstParam(t, 0, _md_target);
	
	static if (is(xposeFields)) foreach (fieldI, field; xposeFields) {{
		static if (is(typeof(field.attribs.md))) {
			const attribs = field.attribs.md;
		} else {
			alias void attribs;
		}
		
		const char[] name = field.name;
		const char[] targetName = _md_target~'.'~name;

		static if (!is(attribs.skip) && (field.isCtor || is(attribs.ctor))) {
			if (numParams == field.paramTypes.length) {
				field.paramTypes ctorArgs;
				foreach (i, arg; ctorArgs) {
					if (canCastTo!(typeof(arg))(t, i + 1)) {
						ctorArgs[i] = superGet!(typeof(arg))(t, i + 1);
					} else {
						mixin("goto failCtorFromField" ~ fieldI.stringof ~ ";");
					}
				}

				static if (_md_reallyAllowSubclassing) {
					auto obj = new _mdThisType(getVM(t), ctorArgs);
				} else {
					static if (!field.isCtor) {		// static func marked as a ctor
						static assert (field.isFunction && field.isStatic);
						static if (is(_md_Target == struct)) {
							mixin("auto obj = new StructWrapper!(_md_Target)("~_md_target~'.'~name~"(ctorArgs));");
						} else {
							mixin("auto obj = "~_md_target~'.'~name~"(ctorArgs);");
						}
					} else {
						static if (is(_md_Target == struct)) {
							auto obj = new StructWrapper!(_md_Target)(_md_Target(ctorArgs));
						} else {
							auto obj = new _md_Target(ctorArgs);
						}
					}
				}
				
				pushNativeObj(t, obj);
				setExtraVal(t, 0, 0);
				static if (!is(_md_Target == struct)) {
					setWrappedInstance(t, obj, 0);
				}
				return 0;
			}
			
			mixin("failCtorFromField" ~ fieldI.stringof ~ ":{}");
		}
	}}
	
	static if (is(typeof(new _mdThisType(getVM(t))))) {
		if (0 == numParams) {
			static if (_md_reallyAllowSubclassing) {
				auto obj = new _mdThisType(getVM(t));
			} else {
				static if (is(_md_Target == struct)) {
					auto obj = new StructWrapper!(_md_Target)(_md_Target());
				} else {
					auto obj = new _md_Target();
				}
			}
			
			pushNativeObj(t, obj);
			setExtraVal(t, 0, 0);
			static if (!is(_md_Target == struct)) {
				setWrappedInstance(t, obj, 0);
			}
			return 0;
		}
	}		
	
	auto buf = StrBuffer(t);
	buf.addChar('(');
	if (numParams > 0) {
		pushTypeString(t, 1);
		buf.addTop();

		for (uword i = 2; i <= numParams; i++) {
			buf.addString(", ");
			pushTypeString(t, i);
			buf.addTop();
		}
	}

	buf.addChar(')');
	buf.finish();
	throwException(t, "Parameter list {} passed to constructor does not match any wrapped constructors", getString(t, -1));
	return 0;
}


static if (_md_reallyAllowSubclassing) {
	pragma(ctfe) private static char[] _md_ctorShimCodegen() {
		char[] res = "";
		static if (is(xposeFields)) foreach (field; xposeFields) {{
			static if (is(typeof(field.attribs.md))) {
				const attribs = field.attribs.md;
			} else {
				alias void attribs;
			}
			
			const char[] name = field.name;
			const char[] targetName = _md_target~'.'~name;

			static if (!is(attribs.skip) && field.isCtor) {
				static if (0 == field.paramTypes.length) {
					res ~=
					"this(MDVM* vm) {
						_mdvm_ = vm;
						static if(is(typeof(&"~_md_target~"._ctor))) {
							super();
						}
					}";
				} else {
					static if (is(field.attribs.overload)) {
						const char[] overloadTypeName = field.attribs.overload.typeName;
						res ~=
						"this(MDVM* vm, ParameterTupleOf!("~overloadTypeName~") args) {
							_mdvm_ = vm;
							static if(is(typeof(&"~_md_target~"._ctor))) {
								super(args);
							}
						}";
					} else {
						res ~=
						"this(MDVM* vm, ParameterTupleOf!("~_md_target~"._ctor) args) {
							_mdvm_ = vm;
							static if(is(typeof(&"~_md_target~"._ctor))) {
								super(args);
							}
						}";
					}
				}
			}
		}}
		
		return res;
	}
	mixin(_md_ctorShimCodegen());


	pragma(ctfe) private static char[] _md_funcOverridesCodegen() {
		char[] res = "";
		
		static if (is(xposeFields)) foreach (field; xposeFields) {{
			static if (is(typeof(field.attribs.md))) {
				const attribs = field.attribs.md;
			} else {
				alias void attribs;
			}
			
			const char[] name = field.name;
			const char[] targetName = _md_target~'.'~name;

			static if (!is(attribs.skip) && field.isFunction) {
				static if (is(field.attribs.overload)) {
					const char[] overloadTypeName = field.attribs.overload.typeName;
				} else {
					const char[] overloadTypeName = targetName;
					/+res ~=
					"private ReturnTypeOf!("~targetName~") "~name~"__super(ParameterTupleOf!("~targetName~") args) {
						return super."~name~"(args);
					}
					override ReturnTypeOf!("~targetName~") "~name~"(ParameterTupleOf!("~targetName~") args) {";+/
				}

				res ~=
				"private ReturnTypeOf!("~overloadTypeName~") "~name~"__super(ParameterTupleOf!("~overloadTypeName~") args) {
					return super."~name~"(args);
				}
				override ReturnTypeOf!("~overloadTypeName~") "~name~"(ParameterTupleOf!("~overloadTypeName~") args) {";

				static if (is(attribs.rename)) {
					const char[] mdname = attribs.rename.value;
				} else {
					const char[] mdname = name;
				}
				
				res ~=
				"if (auto t = _haveMDOverload_(\""~mdname~"\")) {
					// instance is on top
					auto reg = stackSize(t) - 1;
					pushNull(t);
					foreach (arg; args) {
						superPush(t, arg);
					}
					
					alias ReturnTypeOf!("~overloadTypeName~") ReturnType;
					static if (is(ReturnType == void)) {
						methodCall(t, reg, \""~mdname~"\", 0);
					} else {
						methodCall(t, reg, \""~mdname~"\", 1);
						auto ret = superGet!(ReturnType)(t, -1);
						pop(t);
						return ret;
					}
				} else {
					return super."~name~"(args);
				}
			}";
			}
		}}
		
		return res;
	}

	private MDVM* _mdvm_;
	
	mixin(_md_funcOverridesCodegen());
}


pragma(ctfe) private static char[] _md_opFieldCodegen(char[] exclusionStr)(char[] action) {
	char[] res = "";
	
	static if (is(xposeFields)) foreach (field; xposeFields) {{
		static if (is(typeof(field.attribs.md))) {
			const attribs = field.attribs.md;
		} else {
			alias void attribs;
		}
		
		static if (!is(attribs.skip)) {
			static if (field.isData) {
				mixin("const bool exclude = is(attribs."~exclusionStr~");");
				static if (!exclude) {
					const char[] name = field.name;
					const char[] targetName = _md_target~'.'~name;
					res ~= "case \""~field.name~"\":"~ctReplace(action, ["$name$", name])~";break;";
				}
			}
		}
	}}
	
	return res;
}


static uword _md_opField(MDThread* t, uword numParams) {
	auto _this = checkStructClassSelf!(_md_Target, _md_target)(t);
	auto fieldName = checkStringParam(t, 1);
	mixin("
	switch (fieldName) {
		" ~
		_md_opFieldCodegen!("writeOnly")("superPush(t, _this.$name$)") ~ "
		default:
			static if (is(typeof(SuperWrapClassType._md_opField(t, numParams)))) {
				return SuperWrapClassType._md_opField(t, numParams);
			}
			throwException(t, \"No field \" ~ fieldName ~ \" in \" ~ _md_target);
	}");
	return 1;
}


static uword _md_opFieldAssign(MDThread* t, uword numParams) {
	auto _this = checkStructClassSelf!(_md_Target, _md_target)(t);
	auto fieldName = checkStringParam(t, 1);
	mixin("
	switch (fieldName) {
		" ~
		_md_opFieldCodegen!("readOnly")("_this.$name$ = superGet!(typeof(_this.$name$))(t, 2)") ~ "
		default:
			static if (is(typeof(SuperWrapClassType._md_opFieldAssign(t, numParams)))) {
				return SuperWrapClassType._md_opFieldAssign(t, numParams);
			}
			throwException(t, \"No field \" ~ fieldName ~ \" in \" ~ _md_target);
	}");
	return 0;
}


static void _md_classInitFuncs(MDThread* t) {
	static if (is(xposeFields)) foreach (field; xposeFields) {{
		static if (is(typeof(field.attribs.md))) {
			const attribs = field.attribs.md;
		} else {
			alias void attribs;
		}
		
		static if (!is(attribs.skip)) {
			static if (is(attribs.rename)) {
				const char[] name = attribs.rename.value;
			} else {
				const char[] name = field.name;
			}

			static if (field.isData) {
				static if (mixin("!is(typeof( "~_md_target~".init."~name~".offsetof))")) {		// is it static?
					static if (!is(attribs.writeOnly)) {
						mixin("newFunction(t, &_minid_"~name~", \""~name~"\");");
						fielda(t, -2, name);
					}
					
					static if (!is(attribs.readOnly)) {
						const char[] frename = renameStaticFieldSetter(name);
						mixin("newFunction(t, &_minid_"~frename~", \""~frename~"\");");
						fielda(t, -2, frename);
					}
				}
			} else static if (field.isFunction) {
				mixin("newFunction(t, &_minid_"~name~", \""~name~"\");");
				fielda(t, -2, name);
			}
		}
	}}
	
	static if (is(typeof(SuperWrapClassType._md_classInitFuncs(t)))) {
		SuperWrapClassType._md_classInitFuncs(t);
	}
}


static bool _md_classInit_done = false;
static void _md_classInit(MDThread* t) {
	if (_md_classInit_done) {
		return;
	} else {
		_md_classInit_done = true;
	}
	
	int initialStackSize = stackSize(t);
	
	Stdout.formatln("_md_classInit for {}", _md_target);
	
	checkInitialized(t);

	// Check if this type has already been wrapped
	getWrappedClass(t, typeid(_md_Target));

	if (!isNull(t, -1)) {
		throwException(t, "Native type " ~ _md_target ~ " cannot be wrapped more than once");
	}

	pop(t);

	static if (is(_md_Target == class) || (is(_md_Target == interface) && BaseTypeTupleOf!(_md_Target).length > 0)) {
		alias BaseTypeTupleOf!(_md_Target) BaseTypeTuple;
		static if (is(BaseTypeTuple[0] == Object)) {
			static if (BaseTypeTuple.length > 1) {
				alias BaseTypeTuple[1] BaseClass;
			} else {
				alias void BaseClass;
			}
		} else {
			alias BaseTypeTuple[0] BaseClass;
		}
	} else {
		alias void BaseClass;
	}

	static if (!is(BaseClass == void)) {
		static if (is(typeof(BaseClass._md_classInit(t)))) {
			BaseClass._md_classInit(t);
		}

		static if (is(BaseClass == class)) {
			auto base = getWrappedClass(t, BaseClass.classinfo);
		} else static if (is(BaseClass == interface)) {
			auto base = getWrappedClass(t, typeid(BaseClass));
		} else static assert (false, "wtf: " ~ BaseClass.stringof);
	} else {
		auto base = pushNull(t);
	}

	char[] _classname_ = _md_target;
	newClass(t, base, _classname_);
	
	_md_classInitFuncs(t);

	// Set the allocator
	newFunction(t, &_md_classAllocator, _md_target ~ ".allocator");
	setAllocator(t, -2);

	newFunction(t, &_md_opField, _md_target ~ ".opField");
	fielda(t, -2, "opField");

	newFunction(t, &_md_opFieldAssign, _md_target ~ ".opField");
	fielda(t, -2, "opFieldAssign");

	newFunction(t, &_md_constructor, _md_target ~ ".constructor");
	fielda(t, -2, "constructor");

	// Set the class
	setWrappedClass(t, typeid(_md_Target));
	static if (!is(_md_Target == struct)) {
		setWrappedClass(t, _md_Target.classinfo);
	}
	newGlobal(t, _classname_);
	
	int toCleanup = stackSize(t) - initialStackSize;
	pop(t, toCleanup);
}

private static uword _md_classAllocator(MDThread* t, uword numParams) {
	newInstance(t, 0, 1);

	dup(t);
	pushNull(t);
	rotateAll(t, 3);
	methodCall(t, 2, "constructor", 0);
	return 1;
}

pragma(ctfe) static char[] _md_wrapperCodegen(bool allowSubclassing)() {
	char[] res = "";
	static if (is(xposeFields)) foreach (field; xposeFields) {{
		static if (is(typeof(field.attribs.md))) {
			const attribs = field.attribs.md;
		} else {
			alias void attribs;
		}
		
		const char[] name = field.name;
		const char[] targetName = _md_target~'.'~name;

		static if (!is(attribs.skip)) {
			static if (is(attribs.rename)) {
				const char[] rename = attribs.rename.value;
			} else {
				const char[] rename = name;
			}
			
			static if (field.isData) {
				static if (mixin("!is(typeof( "~_md_target~".init."~name~".offsetof))")) {		// is it static?
					static if (!is(attribs.writeOnly)) {
						res ~= "
						static uword _minid_"~rename~"(MDThread* t, uword numParams) {
							superPush(
								t,
								"~targetName~"
							);
							return 1;
						}";
					}
					
					static if (!is(attribs.readOnly)) {
						res ~= "
						static uword _minid_"~renameStaticFieldSetter(rename)~"(MDThread* t, uword numParams) {
							"~targetName~" = superGet!(typeof("~targetName~"))(t, 1);
							return 0;
						}";
					}
				}
			} else static if (field.isFunction) {
				static if (field.isStatic) {
					static if (is(field.attribs.overload)) {
						const char[] ovt = field.attribs.overload.typeName;
						const char[] paramTypes = "ParameterTupleOf!("~ovt~")";
						const char[] returnType = "ReturnTypeOf!("~ovt~")";
					} else {
						const char[] paramTypes = "ParameterTupleOf!("~targetName~")";
						const char[] returnType =  "ReturnTypeOf!("~targetName~")";
					}

					const char[] theCall = _md_target~'.'~name~"(args)";
				} else {
					static if (allowSubclassing) {
						const char[] callTarget = name ~ "__super";
					} else {
						const char[] callTarget = name;
					}

					static if (is(field.attribs.overload)) {
						const char[] ovt = field.attribs.overload.typeName;
						const char[] paramTypes = "ParameterTupleOf!("~ovt~")";
						const char[] theCall = "(cast(ReturnTypeOf!("~ovt~") delegate("~paramTypes~"))&_this."~callTarget~")(args)";
						const char[] returnType = "ReturnTypeOf!("~ovt~")";
					} else {
						const char[] paramTypes = "ParameterTupleOf!("~targetName~")";
						const char[] returnType =  "ReturnTypeOf!("~targetName~")";
						const char[] theCall = "_this."~callTarget~"(args)";
					}
				}
				
				res ~= "
					static uword _minid_"~rename~"(MDThread* t, uword numParams) {";
						static if (!field.isStatic) {
							static if (allowSubclassing) {
								res ~=
								"static assert (is(_mdThisType == class));
								static assert (is("~_md_target~" == class));
								auto _this = cast(_mdThisType)cast(void*)checkStructClassSelf!("~_md_target~", \""~_md_target~"\")(t);";
							} else {
								res ~= "auto _this = checkStructClassSelf!("~_md_target~", \""~_md_target~"\")(t);";
							}
						}
						
						res ~= paramTypes~" args;
						foreach (i, _dummy; args) {
							const int argNum = i + 1;
							if (i < numParams) {
								args[i] = superGet!(typeof(args[i]))(t, argNum);
							}
						}
						
						static if (is("~returnType~" == void)) {
							"~theCall~";
							return 0;
						}
						else {
							superPush(
								t,
								"~theCall~"
							);
							return 1;
						}
				";
				res ~= "
					}";
			} else {
			}
		}
	}}
	return res;
}

mixin(_md_wrapperCodegen!(_md_reallyAllowSubclassing)());

static this() {
	xposeMiniD_classInit ~= &_md_classInit;
}
