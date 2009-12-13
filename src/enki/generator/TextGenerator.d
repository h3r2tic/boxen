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
module enki.generator.TextGenerator;

import enki.AttributeSet;
import enki.RuleSet;
import enki.frontend.Frontend;

//import tango.io.Print;
import tango.io.stream.Format;
import tango.io.device.File;
import tango.io.Buffer;
import tango.io.Stdout;

import tango.text.convert.Layout;
import tango.text.Util;

//TODO: customize using a custom layout instead of the startLine hackery
abstract class TextGenerator: FormatOutput!(char){	
	alias char[] String;	
	String tabs;
	bool startLine;
    
    public char[] getHelp(){
        return "";
    }

	public this(){
		super(new Layout!(char),new GrowBuffer());
		this.tabs = "";
		startLine = true;
	}

	public this(TextGenerator other){
		super(other.layout,other.stream);
		this.tabs = other.tabs;
		startLine = true;
	}
	
	public abstract char[] getFilename();
	public abstract void visit(AttributeSet attributes);
	public abstract void visit(RuleSet rules);

	public void indent(){
		tabs ~= "\t";
	}

	public void unindent(){
		tabs = tabs[0..$-1];
	}

	public void newline(){
		startLine = true;
		super.newline();
	}

	public void emit(V...)(char[] outputFormat,V args){
		if(outputFormat is null || outputFormat.length == 0) return;
		if(startLine){
			this.print(tabs);
			startLine = false;
		}
		auto newFormat = substitute(outputFormat,"\n","\n"~tabs);
		this.format(newFormat,args);
	}

	public void tester(char[] outputFormat){
		this.formatln(outputFormat);
	}

	public void emitln(V...)(char[] outputFormat,V args){
		if(outputFormat is null || outputFormat.length == 0){
			print("\n"~tabs);
			return;
		}
		if(startLine){
			this.print(tabs);
			startLine = false;
		}
		auto newFormat = substitute(outputFormat,"\n","\n"~tabs);
		this.formatln(newFormat,args);
		startLine = true;
	}
		
	public void toCode(Frontend frontend,bool test=false){
		visit(frontend.getAttributes());
		visit(frontend.getRules());

		if(test){
			//this.conduit.drain(Stdout);
			Stdout.copy(this.conduit);
		}
		else{
			auto filename = this.getFilename();
			debug Stdout.format("Writing to file: '{0}'",filename).newline;
			auto fc = new File(filename,File.ReadWriteCreate);
			//TODO: check fc for validity
			//this.getBuffer().drain(fc);
			fc.copy(this.conduit);
			fc.close;
		}	
	}	
}

unittest{
    class TestGenerator : TextGenerator{
        public this(IBuffer buf){
            super(buf);
        }
        public char[] getFilename(){ return null; }
        public void visit(AttributeSet attributes){}
        public void visit(RuleSet rules){}
    }
    auto buffer = new GrowBuffer();
    auto test = new TestGenerator(buffer);

    test.emitln("hello world");
    test.indent();
    test.emitln("foo");
    test.unindent();
    test.emitln("bar");

    test.flush();
    Stdout(buffer.getContent());
}
