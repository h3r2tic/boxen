module xf.nucleus.Code;

private {
	import xf.Common;
	import tango.util.Convert;
}



enum : uint {
	TOK_LITERAL,
	TOK_STRING,
	TOK_VERBATIM_STRING,
	TOK_NUMBER,
	TOK_IDENT,
	TOK_LCURLY,
	TOK_RCURLY
}



struct KDefToken {
	char[] filename;
	uint line;
	uint column;
    uint type;
	char[] value;
    
    public char[] toString(){
        return value;
    }
        
    public char toChar(){
        return value[0];
    }
    
    public int toInt(){
        if(type == TOK_NUMBER){
            return to!(int)(value);
        }
        return type;
    }
    
    public uint toUint(){
        if(type == TOK_NUMBER){
            return to!(uint)(value);
        }
        return type;
    }
    
    public bool opEquals(KDefToken atom){
        if (this.type != atom.type) return false;
        return this.value == atom.value;
    }
        
    public bool opEquals(uint value){
        return this.type == value;
    }
    
    public bool opEquals(char[] value){
        return this.value == value;
    }
    
    public int opCmp(KDefToken atom){
        throw new Exception("Cannot perform range comparison on token type.");
    }
    
    public int opCmp(uint){
        throw new Exception("Cannot perform range comparison on token type.");
    }
    public int opCmp(char){
        throw new Exception("Cannot perform range comparison on token type.");
    }
    
    char[] verbatim() {
    	switch (type) {
    		case TOK_STRING:
				return '"' ~ value ~ '"';
    		case TOK_VERBATIM_STRING:
				return '`' ~ value ~ '`';
			default:
				return value;
    	}
    }



	static char[] concat(KDefToken[] tokens){
		char[] value = null;
		foreach (tok; tokens){
			value ~= tok.value;
		}
		return value;
	}
}



class Code {
	KDefToken[]	tokens;
	cstring		language;
	
	
	this (cstring language, KDefToken[] tokens) {
		this.tokens = tokens;
		this.language = language;
	}
	
	
	cstring toString() {
		if (0 == tokens.length) {
			return null;
		} else {
			int lin = tokens[0].line;
			int col = 0;
			
			cstring value = null;
			foreach (tok; tokens) {
				while (tok.line > lin) {
					++lin;
					value ~= '\n';
					col = 0;
				}
				cstring val = tok.verbatim;
				col += val.length;
				while (tok.column > col) {
					++col;
					value ~= ' ';
				}
				value ~= val;
			}
			return value;
		}
	}
}
