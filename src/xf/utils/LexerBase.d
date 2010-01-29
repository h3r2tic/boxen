module xf.utils.LexerBase;

private {
	import xf.Common;
	import xf.utils.RollingBuffer;
	import xf.utils.Error;
	import xf.utils.Log;
	import tango.io.model.IConduit;
	import Int = tango.text.convert.Integer;
	import Float = tango.text.convert.Float;
	static import tango.text.convert.Format;
}


struct LexerConfig {
	cstring[] lineComments = [
		"//",
		"#"
	];
	
	cstring[] blockComments = [
		"/*", "*/"
	];

	cstring[] nestingComments = [
		"/+", "+/"
	];
	
	int minBufferSize = 64;
}


class LexerException : Exception {
	this(cstring str) {
		super (str);
	}
}


struct LexerBase {
	static LexerBase opCall(
		InputStream stream,
		string peekBuffer,
		LexerConfig cfg = LexerConfig.init
	) {
		LexerBase res = void;
		res.stream = stream;
		res.peekBuffer = RollingBuffer(peekBuffer);
		res.cfg = cfg;
		res._eof = false;
		assert (cfg.minBufferSize >= 32);
		assert (peekBuffer.length >= cfg.minBufferSize);
		return res;
	}
	
	
	void skipWhite() {
	start:
		char c = peek;
		if (eof) return;
		if (' ' == c || '\t' == c || '\n' == c || '\r' == c) {
			consume;
			goto start;
		}
		foreach (com; cfg.lineComments) {
			if (com[0] == c && peek(0, com.length) == com) {
				consume;
				skipLine;
				goto start;
			}
		}
		for (int i = 0; i < cfg.blockComments.length; i += 2) {
			cstring open = cfg.blockComments[i];
			cstring close = cfg.blockComments[i+1];
			
			if (open[0] == c && peek(0, open.length) == open) {
				consume(open.length);
				skipUntil(close);
				consume(close.length);
				goto start;
			}
		}
		for (int i = 0; i < cfg.nestingComments.length; i += 2) {
			cstring open = cfg.nestingComments[i];
			cstring close = cfg.nestingComments[i+1];
			
			if (open[0] == c && peek(0, open.length) == open) {
				consume(open.length);
				skipNestingComment(open, close);
				goto start;
			}
		}
	}
	
	
	void skipLine() {
	start:
		char c = peek;
		if (!eof && c != '\n' && c != '\r') {
			consume;
			goto start;
		}
		
	start2:
		if (eof) return;
		c = peek;
		if ('\n' == c || '\r' == c) {
			consume;
			goto start2;
		}
	}
	
	
	void skipUntil(cstring str) {
		assert (str.length > 1);
		
	start:
		char c = peek;
		if (eof) return;
		if (c == str[0]) {
			consume;
			if (peek(0, str.length-1) == str[1..$]) {
				consume(str.length-1);
				return;
			} else {
				if (eof) return;
			}
		}
		goto start;
	}
	
	
	void skipNestingComment(cstring open, cstring close) {
		assert (open.length > 1);
		assert (close.length > 1);
		
		int level = 1;

	start:
		char c = peek;
		if (eof) return;
		if (c == open[0]) {
			consume;
			if (peek(0, open.length-1) == open[1..$]) {
				consume(open.length-1);
				++level;
			} else {
				if (eof) return;
			}
		} else if (c == close[0]) {
			consume;
			if (peek(0, close.length-1) == close[1..$]) {
				consume(close.length-1);
				if (--level <= 0) return;
			} else {
				if (eof) return;
			}
		}
		goto start;
	}
	
	
	bool consumeString(void delegate(char) sink) {
		char style = peek;
		if (style != '\'' && style != '"' && style != '`') {
			utilsError("Unsupported string style: '{}'", style);
		}
		
		consume;
		if (eof) return false;
		
	start:
		char ch = peek;
		consume;
		if (eof) return false;
		
		if ('\\' == ch && style != '`') {
			switch (ch = peek) {
				case '\\': {
					sink('\\');
				} break;

				case '\'': {
					sink('\'');
				} break;

				case '"': {
					sink('"');
				} break;

				case 'n': {
					sink('\n');
				} break;
				
				default: utilsError("Unsupported escape sequence: \\{}", ch);
			}
			
			consume;
			if (eof) return false;
		} else if (ch == style) {
			return true;
		} else {
			sink(ch);
		}
		goto start;
	}
	

	private bool validIntChar(char c, bool first) {
		return (c >= '0' && c <= '9') || c == '-' || (!first && (c == '_' || c == '+'));
	}

	private bool validFloatChar(char c, bool first) {
		return (c >= '0' && c <= '9') || c == '.' || c == '-' || (!first && (c == '_' || c == 'e' || c == '+'));
	}
	
	private bool validIdentChar(char c, bool first) {
		return
			(c >= 'a' && c <= 'z')
		||	(c >= 'A' && c <= 'Z')
		||	c == '_'
		||	(first && c >= '0' && c <= '9');
	}

	
	bool consumeInt(int* val_) {
		int end = 0;
		while (!eof && validIntChar(peek(end), 0 == end)) {
			++end;
		}
		
		if (0 == end) {
			return false;
		}
		
		cstring intStr = peek(0, end);
		int val = 0;
		int sign = 1;
		foreach (c; intStr) {
			if ('-' == c) {
				sign = -1;
			} else if ('_' == c || '+' == c) {
				// nothing
			} else if (c >= '0' && c <= '9') {
				val *= 10;
				val += c - '0';
			} else {
				assert (false);
			}
		}
		
		*val_ = val * sign;
		
		consume(end);
		return true;
	}
	

	bool consumeFloat(float* val) {
		int end = 0;
		while (!eof && validFloatChar(peek(end), 0 == end)) {
			++end;
		}
		
		if (0 == end) {
			return false;
		}
		
		*val = cast(float)Float.parse(peek(0, end));
		consume(end);
		return true;
	}
	

	bool consumeFloatArray(float[] val) {
		foreach (ref f; val) {
			skipWhite();
			if (eof) return false;
			if (!consumeFloat(&f)) return false;
		}
		return true;
	}

	
	bool consumeIdent(cstring* val) {
		int end = 0;
		while (!eof && validIdentChar(peek(end), 0 == end)) {
			++end;
		}
		
		if (0 == end) {
			return false;
		}
		
		*val = peek(0, end);
		consume(end);
		return true;
	}
	
	
	bool readHexU32(u32* val_) {
		u32 val = 0;
		char[] hex = cast(char[])peek(0, 8);
		if (eof) {
			return false;
		}
		consume(8);
		
		for (int i = 0; i < 8; ++i) {
			val <<= 4;

			char h = hex[i];
			if (h >= '0' && h <= '9') {
				val += h - '0';
			} else if (h >= 'a' && h <= 'f') {
				val += h - 'a' + 10;
			} else if (h >= 'A' && h <= 'F') {
				val += h - 'A' + 10;
			} else {
				utilsError("Invalid hex char found: '{}'", h);
			}				
		}
		
		*val_ = val;
		return true;
	}
	
	
	bool readHexData(u32[] data) {
		foreach (ref d; data) {
			if (!(readHexU32(&d))) {
				return false;
			}
		}
		
		return true;
	}

	
	char peek(int idx = 0) {
		assureRead(idx+1);
		if (eof) return char.init;
		return cast(char)peekBuffer[idx];
	}
	
	
	cstring peek(int idx, int len) {
		assureRead(idx+len);
		if (eof) return null;
		return cast(char[])peekBuffer[idx..idx+len];
	}

	
	void consume(int num = 1) {
		peekBuffer.consume(num);
	}
	
	
	bool eof() {
		return _eof;
	}
	
	
	void error(cstring fmt, ...) {
		char[256] buffer;
		char[] msg = tango.text.convert.Format.Format.vprint(buffer, fmt, _arguments, _argptr);
		throw new LexerException(msg.dup);
	}
	
	
	private {
		void assureRead(int num) {
			assert (num <= cfg.minBufferSize);
			int needToRead = num - peekBuffer.length;
			
			while (needToRead > 0) {
				final tryToRead = cfg.minBufferSize / 2;
				final bytesRead =
					stream.read(peekBuffer.append(tryToRead));

				if (stream.Eof == bytesRead) {
					_eof = true;
					return;
				} else {
					assert (bytesRead <= tryToRead);
					int truncBy = tryToRead - bytesRead;
					if (truncBy > 0) {
						peekBuffer.truncateBy(truncBy);
					}
					needToRead -= bytesRead;
				}
			}
			
			assert (needToRead <= 0);
		}
		
		InputStream		stream;
		RollingBuffer	peekBuffer;
		LexerConfig		cfg;
		bool			_eof;
	}
}
