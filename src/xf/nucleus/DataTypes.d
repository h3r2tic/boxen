module xf.nucleus.DataTypes;

private {
	import xf.Common;
	import xf.nucleus.Log : log = nucleusLog;
	import xf.mem.StackBuffer;

	import tango.text.Unicode;
	import tango.text.Util : trim, triml;

	private static import tango.text.convert.Format;
}



// Should be the last non-default param to type-processing functions
struct TypeParsingError {
	cstring msg;
	
	private char[64] buffer;	// Can't be much less than ~ 45 with current error msgs
}


enum ParseTypeOptions {
	Default = 0,
	OnlyKnownTypes = 0b1,
	Mask = OnlyKnownTypes
}


enum NormalizeTypeOptions {
	Default = 0,
	OnlyKnownTypes = ParseTypeOptions.OnlyKnownTypes,
	StaticToDynamic = 0b10,
}


ParseTypeOptions _normalizeOptsToParseOpts(NormalizeTypeOptions o) {
	return (cast(ParseTypeOptions)o) & ParseTypeOptions.Mask;
}


void registerType(T)(char[] name = null) {
	assert (!isDynamicArrayType!(T));
	assert (!isStaticArrayType!(T));
	assert (!isAssocArrayType!(T));
	g_registeredTypes[name is null ? T.stringof : name] = typeid(T);
	if (!(typeid(T) in g_typeNames)) {
		g_typeNames[typeid(T)] = name is null ? T.stringof : name;
	}
}


void registerCgType(T)(char[] name = null) {
	assert (!isDynamicArrayType!(T));
	assert (!isStaticArrayType!(T));
	assert (!isAssocArrayType!(T));
	g_registeredTypes[name is null ? T.stringof : name] = typeid(T);
	g_registeredTypesCg[name is null ? T.stringof : name] = typeid(T);
	if (!(typeid(T) in g_typeNamesCg)) {
		g_typeNamesCg[typeid(T)] = name is null ? T.stringof : name;
	}
}


bool isSimpleTypeKnown(char[] type) {
	return (type in g_registeredTypes) !is null;
}


TypeInfo getSimpleTypeInfo(char[] name) {
	return g_registeredTypes[name];
}


TypeInfo getTypeInfoByName(char[] name) {
	if (auto ti = name in g_registeredTypes) {
		return *ti;
	} else {
		return null;
	}
}


uint typeSize(ParsedType* parsed) {
	switch (parsed.kind) {
		case ParsedType.Kind.Simple:
			return getSimpleTypeInfo(parsed.name).tsize();
		case ParsedType.Kind.Array:
			return (void[]).sizeof;
		case ParsedType.Kind.StaticArray:
			return parsed.length * typeSize(parsed.subtype);
		case ParsedType.Kind.Pointer:
			return (void*).sizeof;
		default:
			assert (false, `wtf`);
	}
}


/**
 * Returns false on failure. In case of success, calls the sink with a temp-allocated
 * normalized type name, then returns true. errResult may be used for error or temporary
 * allocation storage, so don't assume it isn't used in case of success.
 */
bool normalizeTypeName(
		cstring type,
		void delegate(string) sink,
		TypeParsingError* errResult,
		NormalizeTypeOptions opts = NormalizeTypeOptions.Default,
) {
	assert (errResult !is null);
	
	ParseBuf buf;
	char[] res;
	
	void process(ParsedType* parsed, void delegate(cstring) partSink) {
		if (parsed) {
			process(parsed.subtype, partSink);

			switch (parsed.kind) {
				case ParsedType.Kind.Simple:
					if (parsed.name in g_registeredTypes) {
						partSink(g_typeNames[g_registeredTypes[parsed.name]]);
					} else {
						partSink(parsed.name);
					}
					break;
				case ParsedType.Kind.Array:
					assert (parsed.name is null);
					partSink("[]");
					break;
				case ParsedType.Kind.StaticArray:
					assert (parsed.name is null);
					if (NormalizeTypeOptions.StaticToDynamic & opts) {
						partSink("[]");
					} else {
						char[22] buf;
						partSink(tango.text.convert.Format.Format.sprint(
							buf,
							"[{}]",
							parsed.length
						));
					}
					break;
				case ParsedType.Kind.Pointer:
					assert (parsed.name is null);
					partSink("*");
					break;
				default: assert (false);
			}
		}
	}

	final parsedType = parseType(
		type,
		&buf,
		errResult,
		_normalizeOptsToParseOpts(opts)
	);
	
	if (!parsedType) {
		return false;
	}

	uword lenRequired = 0;
	process(parsedType, (cstring part) {
		lenRequired += part.length;
	});

	if (lenRequired <= errResult.buffer.length) {
		char[] buf2 = errResult.buffer[0..lenRequired];
		uword i = 0;
		process(parsedType, (cstring part) {
			buf2[i .. i + part.length] = part;
			i += part.length;
		});
		assert (buf2.length == i);
		sink(cast(string)buf2);
	} else {
		scope stack = new StackBuffer;
		char[] buf2 = stack.allocArray!(char)(lenRequired);
		uword i = 0;
		process(parsedType, (cstring part) {
			buf2[i .. i + part.length] = part;
			i += part.length;
		});
		assert (buf2.length == i);
		sink(cast(string)buf2);
	}

	return true;
	//Stdout.formatln("normalizeTypeName({}) -> {}", type, res);
}



private {
	TypeInfo[char[]]	g_registeredTypes;
	TypeInfo[char[]]	g_registeredTypesCg;
	char[][TypeInfo]	g_typeNames;
	char[][TypeInfo]	g_typeNamesCg;
	
	
	
	struct ParsedType {
		enum Kind {
			Simple,
			Array,
			StaticArray,
			Pointer
		}
		
		Kind		kind;
		char[]		name;
		int			length;
		ParsedType*	subtype;
	}
	
	alias ParsedType[16] ParseBuf;


	ParsedType* parseType(
			cstring str,
			ParseBuf* buf,
			TypeParsingError* errResult,
			ParseTypeOptions opts = ParseTypeOptions.Default,
	) {
		assert (errResult !is null);
		
		bool fail = false;
		
		void error(cstring fmt, ...) {
			errResult.msg = tango.text.convert.Format.Format.vprint(
					errResult.buffer,
					fmt,
					_arguments,
					_argptr
			);
			fail = true;
			log.trace("parseType.error: {}", errResult.msg);
		}

		assert (str.length > 0);
		if (isLetter(str[0]) || '_' == str[0]) {
			int to = 1;
			while (to < str.length && (isLetterOrDigit(str[to]) || '_' == str[to])) {
				++to;
			}
			char[] ident = str[0..to];
			
			if (	(opts & ParseTypeOptions.OnlyKnownTypes) != 0
				&&	!(isSimpleTypeKnown(ident)))
			{
				error(`unknown type: '{}'`, ident);
				return null;
			}
			
			str = str[to..$];
			str = trim(str);
			
			uint nextBufItem = 0;
			auto curType = &(*buf)[nextBufItem++];
			curType.kind = ParsedType.Kind.Simple;
			curType.name = ident;
			curType.length = -1;
			curType.subtype = null;
			
			
			bool eat() {
				str = str[1..$];
				return str.length > 0;
			}
			
			uint parseUInt() {
				if (str[0] < '0' || str[0] > '9') {
					error(`expected a digit, got: '{}'`, str[0]);
					return 0;
				}
				uint res = str[0] - '0';
				eat;
				while (str.length > 0 && ((str[0] >= '0' && str[0] <= '9')) || '_' == str[0]) {
					if (str[0] != '_') {
						res = res * 10 + str[0] - '0';
					}
					eat;
				}
				return res;
			}
			
			void parseArray() {
				if (!eat) {
					error(`expected a digit or ] while parsing an array`);
					return;
				}

				str = triml(str);
				
				if (']' == str[0]) {
					eat;
					auto prev = curType;
					curType = &(*buf)[nextBufItem++];
					curType.kind = ParsedType.Kind.Array;
					curType.subtype = prev;
				} else {
					uint length = parseUInt();
					if (fail) return;
					
					if (']' != str[0]) {
						error(`expected ] while parsing an array`);
						return;
					}
					auto prev = curType;
					curType = &(*buf)[nextBufItem++];
					curType.kind = ParsedType.Kind.StaticArray;
					curType.length = length;
					curType.subtype = prev;
					eat;
				}
			}
			
			void parsePtr() {
				eat;
				auto prev = curType;
				curType = &(*buf)[nextBufItem++];
				curType.kind = ParsedType.Kind.Pointer;
				curType.subtype = prev;
			}

			void parseRest() {
				while (str.length > 0) {
					switch (str[0]) {
						case '[': {
							parseArray();
							if (fail) return;
						} break;
						
						case '*': {
							parsePtr();
							if (fail) return;
						} break;
						
						default: {
							error(`unexpected token: '{}'`, str[0]);
							return;
						}
					}
				}
			}
			
			parseRest;
			if (fail) return null;
			
			return curType;
		} else {
			error(`wtf. type starting with a '{}'`, str[0]);
			return null;
		}
	}
}
