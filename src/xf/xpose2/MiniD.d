module xf.xpose2.MiniD;

public {
	import minid.api;
	import minid.ex;
	import minid.bind;
	import tango.core.Traits;
	
	import tango.io.Stdout;
}



void checkInitialized(MDThread* t)
{
	getRegistry(t);
	pushString(t, "minid.bind.initialized");

	if(!opin(t, -1, -2))
	{
		newTable(t);       fielda(t, -3, "minid.bind.WrappedClasses");
		newTable(t);       fielda(t, -3, "minid.bind.WrappedInstances");
		pushBool(t, true); fielda(t, -3);
		pop(t);
	}
	else
		pop(t, 2);
}



void function(MDThread* t)[] xposeMiniD_classInit;

void xposeMiniD_initAll(MDThread* t) {
	foreach (func; xposeMiniD_classInit) {
		func(t);
	}
}


pragma (ctfe) char[] xposeMiniD(char[] target = "") {
	return `private alias typeof(this) _mdThisType; mixin xposeMiniD_worker!("`~target~`", true); `~import(`MiniDCodegen.di`);
}


pragma (ctfe) char[] xposeMiniDNoSubclass(char[] target = "") {
	return `private alias typeof(this) _mdThisType; mixin xposeMiniD_worker!("`~target~`", false); `~import(`MiniDCodegen.di`);
}


pragma(ctfe) private char[] capitalizeFirst(char[] str) {
	assert (str.length > 0);
	if (str[0] >= 'a' && str[0] <= 'z') {
		return cast(char)(str[0] + 'A' - 'a') ~ str[1..$];
	} else {
		return str;
	}
}


pragma(ctfe) private char[] renameStaticFieldSetter(char[] name) {
	return "set" ~ capitalizeFirst(name);
}


template xposeMiniD_worker(char[] target_, bool allowSubclassing) {
	static if (0 == target_.length) {
		static if (is(typeof(*_mdThisType.init) == struct)) {
			pragma (ctfe) const char[] _md_target = typeof(*_mdThisType.init).stringof;
		} else {
			pragma (ctfe) const char[] _md_target = _mdThisType.stringof;
		}
	} else {
		pragma (ctfe) const char[] _md_target = target_;
	}
	mixin("alias " ~ _md_target ~ " _md_Target;");
	
	static if ((is(_md_Target == class) || is(_md_Target == interface)) && (is(_mdThisType == class) || is(_mdThisType == interface))) {
		alias BaseTypeTupleOf!(_mdThisType)[0] SuperWrapClassType;
	}
	
	
	static if (0 == target_.length) {
		enum {
			_md_reallyAllowSubclassing = false
		}
		//mixin MiniDWrapperCommon!(false);
	} else {
		static if (is(_md_Target == struct) || !allowSubclassing) {
			enum {
				_md_reallyAllowSubclassing = false
			}
			//mixin MiniDWrapperCommon!(false);
		} else {
			//class MiniDWrapper : _md_Target {
				MDThread* _haveMDOverload_(char[] methodName) {
					if (_mdvm_ is null) {
						return null;
					}
					
					auto t = currentThread(_mdvm_);

					getRegistryVar(t, "minid.bind.WrappedInstances");
					pushNativeObj(t, this);
					idx(t, -2);
					deref(t, -1);

					if(isNull(t, -1)) {
						pop(t, 3);
						return null;
					} else {
						superOf(t, -1);
						field(t, -1, methodName);

						if (funcIsNative(t, -1)) {
							pop(t, 5);
							return null;
						} else {
							pop(t, 2);
							insertAndPop(t, -3);
							return t;
						}
					}
				}

				//mixin MiniDWrapperCommon!(true);
				enum {
					_md_reallyAllowSubclassing = true
				}
			//}
		}
	}
	
	//mixin(_md_wrapperCodegen!(_md_reallyAllowSubclassing)());
	
	static if (is(_md_Target == struct)) {
		alias checkStructSelf checkStructClassSelf;
	} else {
		alias checkClassSelf checkStructClassSelf;
	}
}
