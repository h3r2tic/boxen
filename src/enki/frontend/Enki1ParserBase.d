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
module enki.frontend.Enki1ParserBase;

import enki.frontend.Frontend;
import enki.frontend.Enki1Lexer;
import enki.EnkiToken;
import enki.types;

class Enki1ParserBase: FrontendBase!(EnkiToken,Enki1Lexer){	
	abstract bool parse_Syntax();
    	
	/*
		Concessions for Enki1
	*/
	
	public void appendAttribute(String namespace,String name,String value){
		auto newValue = attributes.get(namespace,name,value);
		if(value is null){
			newValue = value;
		}
		else{
			newValue ~= "\n" ~ value;
		}
		attributes.set(namespace,name,newValue);
	}
	
	public void prependAttribute(String namespace,String name,String value){
		auto newValue = attributes.get(namespace,name,value);
		if(value is null){
			newValue = value;
		}
		else{
			newValue = value ~ "\n" ~ newValue;
		}
		attributes.set(namespace,name,newValue);
	}
	
	public void addImport(String value){
		appendAttribute("d","header","import " ~ value ~ ";");
	}	
	
	public void setBaseClass(String value){
		appendAttribute("d","baseclass","value;");
	}
	
	public void setClassname(String value){
		appendAttribute("d","baseclass","value;");
	}
	
	public void includeDirective(String filename){
		//String[] args;
	//	args ~= filename;
		//runDirective("include",args);
	}
	
	public void setModulename(String moduleName){		
		prependAttribute("d","header","import " ~ moduleName ~ ";");
	}
	
	public void setBoilerplate(String code){
		prependAttribute("d","header",code);
	}
		
	public void setHeader(String moduleName){		
		prependAttribute("d","header",moduleName);
	}
    
	// extra parser method to help with parsing identifiers that must match a literal value
	public bool parse_Keyword(String value){
		if(!hasMore()) return false;
		auto tok = data[pos];
		debug Stdout.formatln("match(String) '{0}' with '{2}' ({1}) = {3}",value,tok.type,tok.value,tok.value == value);
		if(tok.type == TOK_IDENT && tok.value == value){
			setMatchValue(value);
			pos++;
			return true;
		}
		return false;
	}    
}