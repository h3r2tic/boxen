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
module enki.frontend.EnkiLexerBase;

import enki.frontend.Frontend;
import enki.EnkiToken;
import enkilib.d.Parser;
import enkilib.d.PositionalCharParser;
import tango.util.Convert;

/**
    Base lexer class for Enki 1 and Enki 2 frontends
**/
abstract class EnkiLexerBase : PositionalCharParser{
    alias char[] String;
    
	static String NEWLINE = "\n";
	static String CARRAIGE_RETURN = "\r";
	static String TAB = "\t";
	static String DOUBLE_QUOTE = "\"";
	static String SINGLE_QUOTE = "\'";
	static String SLASH = "\\";
	
	String filename;
	
	public void initialize(String data,String filename){
		super.initialize(data,filename);
	}
	
	EnkiToken CreateToken(String text,uint TOK){
		Position pos = getPosition(0);
		EnkiToken tok;
		tok.type = TOK;
		tok.line = pos.line;
		tok.filename = filename;
		tok.column = pos.col;
		tok.value = text;
		return tok;
	}
	
	EnkiToken CreateTokenT(uint TOK)(String text){
		return CreateToken(text,TOK);
	}
	alias CreateTokenT!(TOK_REGEX) RegexToken;
	alias CreateTokenT!(TOK_STRING) StringToken;
	alias CreateTokenT!(TOK_HEX) HexToken;
	alias CreateTokenT!(TOK_NUMBER) NumberToken;
	alias CreateTokenT!(TOK_IDENT) IdentifierToken;
	alias CreateTokenT!(TOK_LITERAL) LiteralToken;
	
	bool parse_Tokens(){
        //do nothing
        return false;
    }
	
	bool parse(){
		return this.parse_Tokens();
	}
}
