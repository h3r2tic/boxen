/+
    Copyright (c) 2007 Eric Anderton

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
module enki.EnkiToken;

import tango.util.convert;

enum:uint{
	TOK_LITERAL,
	TOK_STRING,
	TOK_REGEX,
	TOK_HEX,
	TOK_NUMBER,
	TOK_IDENT,
	TOK_NEW,
	TOK_RULEASSIGN,
	TOK_RANGE,
	TOK_ERRORPOINT,
	TOK_LAST
}

struct EnkiToken{
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
    
    public bool opEquals(EnkiToken atom){
        if(this.type != atom.type) return false;
        if(this.type != TOK_LITERAL) return true;
        return this.value == atom.value;
    }
        
    public bool opEquals(uint value){
        return this.type == value;
    }
    
    public bool opEquals(char[] value){
        if(this.type != TOK_LITERAL) return false;
        return this.value == value;
    }
    
    public int opCmp(EnkiToken atom){
        throw new Exception("Cannot perform range comparison on token type.");
        return -1;
    }
    
    public int opCmp(uint){
        throw new Exception("Cannot perform range comparison on token type.");
        return -1;
    }
    public int opCmp(char){
        throw new Exception("Cannot perform range comparison on token type.");
        return -1;
    }
}