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
module enki.bootstrap.bootstrap;

/**
	Bootstrap module for Enki.
*/

public import enki.types;
public import enki.EnkiToken;
public import enki.frontend.Frontend;
public import Integer = tango.text.convert.Integer;

public import enki.generator.BNFGenerator;
public import enki.generator.DGenerator;
public import enki.generator.BootstrapGenerator;

private import enki.bootstrap.Lexer;
private import enki.bootstrap.Parser;

private import tango.io.Buffer;

class NullLexer{
    public void initialize(char[] data,char[] filename){
        //do nothing
    }

    public EnkiToken[] value_Syntax; //does nothing
	public bool parse_Syntax(){
		//do nothing
		return true;
	}   
}

abstract class Bootstrap: FrontendBase!(EnkiToken,NullLexer){		
	public this(){
		//do nothing
	}
	
	public void setAttribute(String namespace,String name,String value){
		attributes.set(namespace,name,value);
	}

	public void addRule(Rule rule){
		ruleSet.addRule(rule);
	}

	public void addRule(String name,Param[] ruleParams,RulePredicate pred,Param[] vars,Expression expr){
		addRule(new RuleDefinition(name,ruleParams,pred,vars,expr));
	}

	public void addRule(String name,Param[] ruleParams,RulePredicate pred,Expression expr){
		addRule(new RuleDefinition(name,ruleParams,pred,null,expr));
	}

	public void addRule(String name,RulePredicate pred,Param[] vars,Expression expr){
		addRule(new RuleDefinition(name,null,pred,vars,expr));
	}

	public void addRule(String name,RulePredicate pred,Expression expr){
		addRule(new RuleDefinition(name,null,pred,null,expr));
	}

	public void addRule(String name,Param[] vars,Expression expr){
		addRule(new RuleDefinition(name,null,null,vars,expr));
	}

	public void addRule(String name,Expression expr){
		addRule(new RuleDefinition(name,null,null,null,expr));
	}

	public Param[] paramList(Param[] params...){
		return params.dup;
	}
	
	public Range[] rangeList(Range[] ranges...){
		return ranges.dup;
	}
	
	Binding CatBinding(String name){
		return new Binding(name,true);
	}
	
    EnkiToken[] value__Syntax; //does nothing
	public bool parse_Syntax(){
		//do nothing
		return true;
	}

	abstract void runBootstrap();

	public void run(){
		runBootstrap();
		semanticPass();
		
		auto dpl = new DGenerator();
		auto bnf = new BNFGenerator();
		//auto boot = new BootstrapGeneratorT!(CharT)(new GrowBuffer());	
		
		dpl.toCode(this);
		bnf.toCode(this);
		//boot.toCode(this);
	}
}

import tango.io.Stdout;

alias char CharT;

void main(){
	Stdout("Running bootstrap").newline;

	Stdout("Generating Enki Lexer").newline;
	(new Lexer()).run();

	Stdout("Generating Enki Parser").newline;
	(new Parser()).run();

	Stdout("Done.").newline;
}
