module xf.nucleus.kdef.KDefToken;

private {
	import tango.util.Convert;
	import xf.mem.ScratchAllocator;
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
	char[]	filename;
	char[]	value;
	ushort	line;
	ubyte	column;
    ubyte	type;
    
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


	static char[] concat(KDefToken[] tokens, DgScratchAllocator alloc) {
		size_t len = 0;
		foreach (tok; tokens){
			len += tok.value.length;
		}
		char[] value = alloc.allocArrayNoInit!(char)(len);
		len = 0;
		foreach (tok; tokens){
			char[] tokVal = tok.value;
			value[len..len+tokVal.length] = tokVal;
			len += tokVal.length;
		}
		return value;
	}
}


void writeOutTokens(KDefToken[] tokens, void delegate(char[]) sink) {
	if (0 != tokens.length) {
		int lin = tokens[0].line;
		int col = 0;
		
		foreach (tok; tokens) {
			char[] val = tok.verbatim;
			col += val.length;
			while (tok.column > col) {
				++col;
				sink(" ");
			}
			sink(val);

			while (tok.line > lin) {
				++lin;
				sink("\n");
				col = 0;
			}
		}
	}
}
