/+
    Copyright (c) 2008 Eric Anderton

    Permission is hereby granted, free of charge, to any person
    obtaining a copy of this software and associated documentation
    files (the "Software"), to deal in the Software without
    restriction, including without limitation the rights to use,
    copy, modify, merge, publish, distribute, sublicense, and/or
    sell copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following
    conditions:

    The above copyright notice and this permission notice shall be
    included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
    OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
    HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
    OTHER DEALINGS IN THE SOFTWARE.
+/  
module enkilib.d.TokenParser;

import enkilib.d.Parser;
import enkilib.d.ParserException;

debug import tango.io.Stdout;

struct TextToken(CharT,T,T LiteralTokenValue){
	alias T ValueType;
	T type;
	CharT[] filename;
	uint line;
	uint column;
	CharT[] value;
	static typeof(LiteralTokenValue) Literal;
}

class TokenParserT(CharT,TokenType) : ParserT!(CharT,TokenType){
	alias CharT[] String;
		
	String slice(uint start,uint end){
		String result = "";
		foreach(tok; data[start..end]){
			result ~= tok.value;
		}
		return result;
	}
		
	bool match(String value){
		if(!hasMore()) return false;
		auto tok = data[pos];
		debug Stdout.formatln("match(String) '{0}' with '{2}' ({1}) = {3}",value,tok.type,tok.value,tok.value == value);
		if(tok.type == TokenType.Literal && tok.value == value){
			setMatchValue(value);
			pos++;
			return true;
		}
		return false;
	}	
	
	bool match(int start,int end){
		throw new Exception("char range match not supported for token parsers");
		return false;
	}	
	
	bool match(dchar value){
		throw new Exception("char range match not supported for token parsers");
		return false;
	}
	
	bool match(TokenType.ValueType type){
		if(!hasMore()) return false;
		auto tok = data[pos];
		debug Stdout.formatln("match(tok) {0} with {1} ({2})",type,tok.type,tok.value);
		if(tok.type == type){
			setMatchValue(tok.value);
			pos++;
			return true;
		}
		return false;
	}
	
	void next(){
		setMatchValue(data[pos].value);
		pos++;
	}
		
	void error(String message){
		auto tok = data[pos];
		throw ParserException("{0}({1},{2}): {3} (got '{4}' instead)",tok.filename,tok.line,tok.column,message,tok.value);
	}
}
