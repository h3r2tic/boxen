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
module enkilib.d.Parser;
import enkilib.d.ParserException;
import enkilib.d.Convert;

debug import tango.io.Stdout;

/**
	Base parser type.
    
    Atom is a type that represents the most atomic element available in the parsed data set.  All
    primitive types automatically support the needed operations in order for the parser to function
    correctly.  Classes and structs need to support the following operations in order to be compliant:
    
    opEquals(Atom)
    opEquals(Atom[])
    opEquals(uint) //iff Atom != uint
    opEquals(char[]) //iff Atom[] != char[]
    opCmp(Atom)
    opCmp(uint) //iff Atom != uint
    opCmp(char) //iff Atom != char
*/
abstract class Parser(AtomType){
    public alias AtomType Atom;
	public size_t pos;
	public Atom[] data;

	public size_t startPos_this;
	public size_t endPos_this;
	
	void initialize(Atom[] data){
		this.data = data;
	}	
	
    bool value_nop;
	bool parse_nop(){
		value_nop = true;
		return true;
	}
	
    bool value_eoi;
	bool parse_eoi(){
		bool result = !hasMore();
        value_eoi = result;
		return result;
	}
	
    Atom value_any;
	bool parse_any(){
		if(!hasMore()) return false;
        value_any = data[pos];
		pos++;
		return true;
	}
    
    bool value_err;
	bool parse_err(char[] msg=null){
        error(msg);
		return false;
	}
    	
	void err(char[] message){
		error(message);
	}
		
	void dbg(char[] message){
		debug Stdout(message);
	}
	
	bool hasMore(){
		return pos < data.length;
	}
    		
	Atom[] slice(size_t start,size_t end){
		return data[start..end];
	}
    
    Atom[] __match;
    
	bool match(Atom[] value){
		if(value.length > data.length-pos) return false;
        size_t end = pos + value.length;
		if(data[pos..end] == value){
			__match = value;
			pos = end;
			return true;
		}
		return false;
	}
	    
	bool match(Atom start,Atom end){
		if(pos == data.length) return false;
        size_t endpos = pos + 1;
		if(data[pos] >= start && data[pos] <= end){
			__match = data[pos..endpos];
			pos = endpos;
			return true;
		}
		return false;
	}
		
	bool match(Atom value){
		if(!hasMore()) return false;
        size_t end = pos + 1;
		if(data[pos] == value){
			__match = data[pos..end];
			pos = end;
			return true;
		}
		return false;
	}
    
    static if(!is(Atom==char)){
    	bool match(char start,char end){
    		if(pos == data.length) return false;
            size_t endpos = pos + 1;
    		if(data[pos] >= start && data[pos] <= end){
    			__match = data[pos..endpos];
    			pos = endpos;
    			return true;
    		}
    		return false;
    	}    
    	bool match(char[] value){
    		if(pos == data.length) return false;
            size_t end = pos + 1;
    		if(data[pos] == value){
    			__match = data[pos..end];
    			pos = end;
    			return true;
    		}
    		return false;
        }
    	bool match(char value){
    		if(pos == data.length) return false;
            size_t end = pos + 1;
    		if(data[pos] == value){
    			__match = data[pos..end];
    			pos = end;
    			return true;
    		}
    		return false;
        }        
    }
    
    static if(!is(Atom==uint)){
    	bool match(uint start,uint end){
    		if(pos == data.length) return false;
            size_t endpos = pos + 1;
    		if(data[pos] >= start && data[pos] <= end){
    			__match = data[pos..endpos];
    			pos = endpos;
    			return true;
    		}
    		return false;
    	}
        /*
    	bool match(uint[] value){
    		if(pos == data.length) return false;
            size_t end = pos + 1;
    		if(data[pos] == value){
    			__match = data[pos..end];
    			pos = end;
    			return true;
    		}
    		return false;
        }
        */
    	bool match(uint value){
    		if(pos == data.length) return false;
            size_t end = pos + 1;
    		if(data[pos] == value){
    			__match = data[pos..end];
    			pos = end;
    			return true;
    		}
    		return false;
        }        
    }    
    
	void error(char[] message){
		//throw ParserException("({0}): {1}",pos+1,message);	
		throw ParserException("({0}): {1} (got '{2}' instead)",pos+1,message,data[pos]);
	}
        			
	private template isArray(T)
	{
	    static if( is( T U : U[] ) )
	        const isArray = true;
	    else
	        const isArray = false;
	}
    
    private template nameof(T){
        const char[] nameof = T.mangleof;
    }
    
    template convertError(U,V,char[] file,char[] line){
        const char[] convertError = file ~ "(" ~ line ~ "): " ~ getConvertError!(V,U);
    }
    
    /*
        Provides support for dynamic conversions for enki-style bindings to array
        and non-array types.
    */
    private void smartImpl(U,V,char[] op,char[] file,char[] line)(inout U u,V v){
        //pragma(msg,"assign: " ~ U.stringof ~ " " ~ op ~ " " ~ V.stringof);
        static if(canConvertTo!(V,U)){
            static if(isArray!(U)){
                mixin("u " ~ op ~ " to!(U)(v);");
            }
            else{
                // cannot append to non-array type
                mixin("u = to!(U)(v);");
            }
        }
        else static if(isArray!(U)){
            alias typeof(U[0]) UT;
            static if(canConvertTo!(V,UT)){
                mixin("u " ~ op ~ " [to!(UT)(v)];");
            }
            else static if(isArray!(V)){
                alias typeof(V[0]) VT;
                static if(canConvertTo!(VT,U)){
                    //widening conversion into an array
                    static if(op == "="){
                        u = U.init;
                    }
                    foreach(VT value; v){
                        u ~= to!(U)(value);
                    }
                }
                else static if(canConvertTo!(VT,UT)){
                    static if(op == "="){
                        u = U.init;
                    }
                    foreach(VT value; v){
                        mixin("u " ~ op ~ " to!(UT)(value);");
                    }
                }
                else{
                    pragma(msg,convertError!(U,V,file,"1"));
                }
            }
            else{
                pragma(msg,convertError!(U,V,file,"2"));
            }
        }
        else static if(isArray!(V)){
            alias typeof(V[0]) VT;
            static if(!canConvertTo!(VT,U)){
                pragma(msg,convertError!(U,V,file,"3"));
            } else {
                mixin("u " ~ op ~ " to!(U)(v[0]);");
            }
        }
        else{
            pragma(msg,convertError!(U,V,file,"4"));
        }
    }
    
	public void smartAssign(U,V)(inout U u,V v){
        smartImpl!(U,V,"=","somefile.bnf","666")(u,v);
	}
                
	public void smartAppend(U,V)(inout U u,V v){
        smartImpl!(U,V,"~=","somefile.bnf","666")(u,v);
	}
}
