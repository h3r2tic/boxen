module xf.nucleus.kdef.KDefLexerBase;

import xf.nucleus.kdef.KDefToken;
import enkilib.d.Parser;
import enkilib.d.PositionalCharParser;
import tango.util.Convert;


abstract class KDefLexerBase : PositionalCharParser {
    alias char[] String;
    
	static String NEWLINE = "\n";
	static String CARRAIGE_RETURN = "\r";
	static String TAB = "\t";
	static String DOUBLE_QUOTE = "\"";
	static String SINGLE_QUOTE = "\'";
	static String SLASH = "\\";
	
	String filename;
	
	public void initialize(String data,String filename){
		this.filename = filename;
		super.initialize(data,filename);
	}
	
	KDefToken CreateToken(String text,uint TOK){
		Position pos = getPosition();		
		KDefToken tok;
		assert (TOK <= cast(uint)tok.type.max);
		tok.type = cast(typeof(tok.type))TOK;
		tok.line = cast(typeof(tok.line))pos.line;
		tok.filename = filename;
		tok.column = cast(typeof(tok.column))pos.col;
		tok.value = text;
		return tok;
	}
	
	KDefToken CreateTokenT(uint TOK)(String text){
		return CreateToken(text,TOK);
	}
	alias CreateTokenT!(TOK_STRING) StringToken;
	alias CreateTokenT!(TOK_VERBATIM_STRING) VerbatimStringToken;
	alias CreateTokenT!(TOK_NUMBER) NumberToken;
	alias CreateTokenT!(TOK_IDENT) IdentifierToken;
	alias CreateTokenT!(TOK_LITERAL) LiteralToken;
	alias CreateTokenT!(TOK_LCURLY) LeftCurly;
	alias CreateTokenT!(TOK_RCURLY) RightCurly;
	
	bool parse_Tokens(){
        //do nothing
        return false;
    }
	
	bool parse(){
		return this.parse_Tokens();
	}
}
