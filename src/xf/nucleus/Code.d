module xf.nucleus.Code;

private {
	import xf.Common;
	import xf.mem.ScratchAllocator;
	import xf.mem.ScratchRope;
}



struct Code {
	private {
		ScratchFixedRope _code;
	}

	void*	_module;	// KDefModule, after semantic analysis
	uint	_firstByte;
	uint	_lengthBytes;
	

	void append(cstring str, DgScratchAllocator mem) {
		_code.append(str, mem);
	}

	void writeOut(void delegate(char[]) sink) {
		return _code.writeOut(sink);
	}

	bool opEquals(Code other) {
		return _code == other._code;
	}
}
