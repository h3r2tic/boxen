/+
    Copyright (c) 2006-2008 Eric Anderton

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
module enki.Param;

import enki.VariableRef;

import tango.io.Stdout;

class Param: VariableRef{
	alias char[] String;
	
	String value;
	
	public this(String type,String name,String value){
		super(type,name,Unknown);
		this.value = value;
        this.type = type;
		debug Stdout.format("==> Strong Param: {} {} {}",type,name,value).newline;
	}	
		
	public this(String type,String name){
		super(type,name,Unknown);
		debug Stdout.format("==> Strong Param: {} {}",type,name).newline;
	}
	
	public this(String name){
		super(name,Unknown);
		debug Stdout.format("==> Weak Param: {}",name).newline;
	}
}