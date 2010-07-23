/**
 * To be included in pretty much all xf modules.
 */
module xf.Common;

public {
	import tango.stdc.stdio : sprintf, printf;
	import tango.stdc.stdlib : alloca;
	import tango.stdc.string : memset, strcmp, memcpy, memcmp, memmove;
	import tango.stdc.stringz : fromStringz, toStringz;
	import tango.core.Thread : Thread;
	import tango.core.Traits;
	import tango.core.Tuple;
	import intrinsic = std.intrinsic;
}

alias char[] cstring;
typedef char[] string;

alias size_t	uword;
alias ptrdiff_t	word;

static if (8 == uword.sizeof) {
	alias uint	uhword;
	alias int	hword;
} else {
	static assert (4 == uword.sizeof);
	alias ushort	uhword;
	alias short		hword;
}

static assert (uhword.sizeof * 2 == uword.sizeof);
static assert (hword.sizeof * 2 == word.sizeof);

alias byte		i8;
alias short		i16;
alias int		i32;
alias long		i64;

static assert (
	i8.sizeof == 1
&&	i16.sizeof == 2
&&	i32.sizeof == 4
&&	i64.sizeof == 8
);

alias ubyte		u8;
alias ushort	u16;
alias uint		u32;
alias ulong		u64;

static assert (
	u8.sizeof == 1
&&	u16.sizeof == 2
&&	u32.sizeof == 4
&&	u64.sizeof == 8
);

alias float		f32;
alias double	f64;

static assert (
	f32.sizeof == 4
&&	f64.sizeof == 8
);


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


char toUpperASCII(char c) {
	if (c >= 'a' && c <= 'z') {
		return c + ('A' - 'a');
	} else {
		return c;
	}
}


char toLowerASCII(char c) {
	if (c >= 'A' && c <= 'Z') {
		return c + ('a' - 'A');
	} else {
		return c;
	}
}

template Generator(T) {
	alias void delegate(void delegate(T)) Generator;
}

alias void* delegate(uword) DgAllocator;


bool equal(T)(T a, T b) {
	static if (isReferenceType!(T)) {
		if (a is null) {
			return b is null;
		} else {
			if (b is null) {
				return false;
			} else {
				return a.opEquals(b);
			}
		}
	} else {
		return a == b;
	}
}


void swap(T)(ref T a, ref T b) {
	T x = a;
	a = b;
	b = x;
}


class AssureException : Exception {
	this (cstring msg) {
		super (msg);
	}
}

void assure(bool cond, cstring msg = "assure() failed") {
	if (!cond) {
		throw new AssureException(msg);
	}
}

pragma (ctfe) cstring ct_allocaArray(cstring type, cstring name, cstring len) {
	return `auto `~name~` = (cast(`~type~`*)alloca(`~type~`.sizeof * `~len~`))[0..`~len~`];`;
}
