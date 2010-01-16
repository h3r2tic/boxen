module xf.Common;

public {
	import tango.stdc.string : memset, strcmp;
	import tango.stdc.stringz : fromStringz, toStringz;
	import tango.core.Thread : Thread;
	import intrinsic = std.intrinsic;
}

alias char[] cstring;
typedef char[] string;


bool startsWith(cstring s, cstring prefix, cstring* rest = null) {
	if (s.length >= prefix.length && s[0..prefix.length] == prefix) {
		if (rest !is null) {
			*rest = s[prefix.length .. $];
		}
		return true;
	} else {
		return false;
	}
}


bool endsWith(cstring s, cstring suffix, cstring* rest = null) {
	if (s.length >= suffix.length && s[$-suffix.length .. $] == suffix) {
		if (rest !is null) {
			*rest = s[0..$-suffix.length];
		}
		return true;
	} else {
		return false;
	}
}
