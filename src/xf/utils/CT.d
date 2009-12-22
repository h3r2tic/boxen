module xf.utils.CT;



pragma (ctfe) int rfind(char[] str, char[] foo) {
	assert (foo.length == 1);
	foreach_reverse(i, c; str) {
		if (c == foo[0]) return i;
	}
	return -1;
}


pragma(ctfe) char[] shortName(char[] classname) {
	int dot = rfind(classname, `.`);
	return -1 == dot ? classname : classname[dot+1..$];
}


pragma(ctfe) char[] shortNameOf(T)() {
	return shortName(typeid(T).toString);
}


pragma(ctfe) char[] capitalize(char[] name) {
	assert (name.length > 0);
	
	if (name[0] >= 'a' && name[0] <= 'z') {
		return cast(char)(name[0] + 'A' - 'a') ~ name[1..$];
	}
	else return name;
}


pragma(ctfe) static char[] intToStringCT(uint i) {
	if (i < 10) return ""~"0123456789"[i];
	return intToStringCT(i/10) ~ ("0123456789"[i%10]);
}
// ----


// Thanks, downs!
pragma(ctfe) char[] ctReplace(char[] source, char[][] pairs) {
	assert((pairs.length%2) == 0, "Parameters to ctReplace must come in pairs. ");
	if (!pairs.length) return source;
	else {
		char[] what = pairs[0], wth = pairs[1];
		int i = 0;
		while (i <= source.length - what.length) {
			if (source[i .. i+what.length] == what) {
				source = source[0 .. i] ~ wth ~ source[i+what.length .. $];
				i += wth.length;
			} else {
				i++;
			}
		}
		return ctReplace(source, pairs[2 .. $]);;
	}
}



pragma(ctfe) char[] intToStringCT(int i) {
	char[] res = "";
	do
	{
		res ~= "0123456789"[i%10];
		i /= 10;
	} while (i > 0);
	
	for (int j = 0; j < res.length/2; ++j) {
		char c = res[j];
		res[j] = res[res.length-j-1];
		res[res.length-j-1] = c;
	}
	return res;
}

pragma(ctfe) char[] rangeCodegen(int i) {
	char[] res = `alias RangeTuple!(`;
	if (i > 0) {
		res ~= "0";
		for (int j = 1; j < i; ++j) {
			res ~= "," ~ intToStringCT(j);
		}
	}
	return res ~ ") Range;";
}

template RangeTuple(T ...) {
	alias T RangeTuple;
}

template Range(int i) {
	mixin(rangeCodegen(i));
}



// ---- struct/class field name iteration ----

pragma(ctfe) char[][] allNamesInAlias(alias target)() {
	char[][] names = [];
	const int len = target.tupleof.length;
	int prefix = target.stringof.length + 3;		// "(Type)."
	foreach (i; Range!(len)) {
		names ~= target.tupleof[i].stringof[prefix..$];
	}
	return names;
}


pragma(ctfe) bool matchesClassCT(char c, char[] cls) {
	if (char.init == c) return false;
	assert (cls.length > 0);

	if ("." == cls) return true;
	if (1 == cls.length && c == cls[0]) return true;

	if ('[' == cls[0]) {
		assert (']' == cls[$-1]);
		cls = cls[1..$-1];
		bool res = true;
		int from = 0;
		if ('^' == cls[0]) {
			res = false;
			from = 1;
		}
		for (int i = from; i < cls.length; ++i) {
			if ('\\' == cls[i]) {
				if (cls[i+1] == c) return res;
				else ++i;
			} else if (i+1 < cls.length && '-' == cls[i+1]) {
				assert (i+2 < cls.length);
				if (c >= cls[i] && c <= cls[i+2]) return res;
				else i += 2;
			} else if (cls[i] == c) return res;
		}
		return !res;
	}
	assert (1 == cls.length);
	return cls[0] == c;
}

pragma(ctfe) private int cutBRExprCT(char[] str, out char[] cls) {
	for (int i = 0; i < str.length; ++i) {
		if ('\\' == str[i]) ++i;
		else if (']' == str[i]) {
			cls = str[0..i+1];
			return i;
		}
	}
	assert (false);
	return int.max;
}


/**
	A very greedy pattern matching function.
	
	.				matches any character
	[abc]		matches a, b and c
	[a-z]			matches a through z
	[abcA-Z]	matches a, b, c, and A through Z, etc.
	[^stuff]		matches the inverse of [stuff]
	?				matches the preceding element zero or one time
	*				matches the preceding element zero or more times
	
	It's not a regex engine, it's much less powerful in order to be lightweight.
	The greediness means that "f.*r" will not match "foobar", but "f.*" will.
*/
pragma(ctfe) bool matchesPatternCT(char[] str, char[] pattern) {
	char[]	cls;
	bool		prevMatched = true;
	bool		fail = true;
	int		stri = -1;
	
	strIter: while (pattern.length > 0) {
		switch (pattern[0]) {
			case '*': {
				if (!prevMatched) --stri;
				while (prevMatched && matchesClassCT(stri+1 < str.length ? str[stri+1] : char.init, cls)) {
					++stri;
				}
				pattern = pattern[1..$];
				prevMatched = true;
			} break;
			
			case '?': {
				if (!prevMatched) --stri;
				pattern = pattern[1..$];
				prevMatched = true;
			} break;
			
			default: {
				// see if the previous class matched, return false if it didn't
				if (!prevMatched) {
					return false;
				} else {
					++stri;
				}
				
				// find the class
				if ('[' == pattern[0]) {
					pattern = pattern[cutBRExprCT(pattern, cls)+1..$];
				} else {
					cls = pattern[0..1];
					pattern = pattern[1..$];
				}
				prevMatched = matchesClassCT(stri < str.length ? str[stri] : char.init, cls);
			}
		}
	}
	
	return prevMatched && stri+1 >= str.length;
}


/**
	Matches the str to a pattern expression formed by patterns supported by matchesPatternCT
	and operators '+' and '-'
*/
pragma(ctfe) bool matchesComplexPatternCT(char[] str, char[] pattern) {
	bool res = false;
	char prevFunc = '+';
	int i = 0;
	for (; i < pattern.length; ++i) {
		if ('-' == pattern[i] || '+' == pattern[i]) {
			bool match = matchesPatternCT(str, pattern[0..i]);
			if ('+' == prevFunc) {
				res |= match;
			} else {
				res &= !match;
			}
			prevFunc = pattern[i];
			pattern = pattern[i+1..$];
			i = -1;
		}
	}

	if (i > 0) {
		bool match = matchesPatternCT(str, pattern[0..i]);
		if ('+' == prevFunc) {
			res |= match;
		} else {
			res &= !match;
		}
	}
	
	return res;
}


pragma(ctfe) char[][] matchedNamesCT(alias target)(char[] pattern) {
	char[][] res;
	foreach (name; allNamesInAlias!(target)) {
		if (matchesComplexPatternCT(name, pattern)) {
			res ~= name;
		}
	}
	return res;
}


pragma(ctfe) bool isSpaceCT(char c) {
	return ' ' == c || '\t' == c;
}

pragma(ctfe) char[] striplCT(char[] s) {
	uint i;
	for (i = 0; i < s.length; i++) {
		if (!isSpaceCT(s[i])) {
			break;
		}
	}
	return s[i .. s.length];
}

pragma(ctfe) char[] striprCT(char[] s) {
	uint i;
	for (i = s.length; i > 0; i--) {
		if (!isSpaceCT(s[i - 1])) {
			break;
		}
	}
	return s[0 .. i];
}


pragma(ctfe) char[] stripCT(char[] s) {
    return striprCT(striplCT(s));
}


pragma(ctfe) bool isLetterCT(char c) {
	return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}


pragma(ctfe) bool isDigitCT(char c) {
	return c >= '0' && c <= '9';
}


pragma(ctfe) int locateCT(char[] str, char c) {
	foreach (i, c2; str) {
		if (c == c2) return i;
	}
	return str.length;
}

pragma(ctfe) char[][] splitLinesCT(char[] str) {
	char[][] res;
	while (str.length) {
		int from = -1, to = -1;
		for (from = 0; from < str.length; ++from) {
			if (str[from] == '\n' || str[from] == '\r' || str[from] == '|') {
				str = str[from+1..$];
				from = -1;
				break;
			}
			if (str[from] == ' ' || str[from] == '\t') continue;
			break;
		}
		
		if (-1 == from) continue;

		for (to = from; to < str.length; ++to) {
			if (str[to] == '\n' || str[to] == '\r' || str[to] == '|') {
				break;
			}
		}
		
		char[] part = str[from..to];
		str = str[to..$];
		if (to == from) continue;
		while (part.length > 0 && (part[$-1] == ' ' || part[$-1] == '\t')) part = part[0..$-1];
		
		if (0 == part.length) continue;
		res ~= part;
	}
	
	return res;
}
