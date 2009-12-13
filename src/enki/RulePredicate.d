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
module enki.RulePredicate;

import enki.Rule;
import enki.AttributeSet;
import enki.RuleSet;
import enki.Param;
import enki.VariableRef;

import tango.io.Stdout;

abstract class RulePredicate{
	alias char[] String;		
	public String getType(Rule thisRule,RuleSet ruleSet,AttributeSet attribs);
	public void semanticPass(Rule thisRule,RuleSet ruleSet,AttributeSet attribs);
}

class BindingPredicate: RulePredicate{	
	public Param decl;
	
	public this(Param decl){
		this.decl = decl;
	}
	
	public String getType(Rule thisRule,RuleSet ruleSet,AttributeSet attribs){
		return decl.type;
	}	
	
	public void semanticPass(Rule thisRule,RuleSet ruleSet,AttributeSet attribs){
		decl.flavor = VariableRef.PredicateArgument;
		thisRule.register(decl,ruleSet,attribs);
	}
}

class FunctionPredicate: RulePredicate{		
	public Param[] params;
	public Param decl;
	
	public this(Param decl,Param[] params...){
		this.decl = decl;
		this.params = params.dup;
	}
	
	public void semanticPass(Rule thisRule,RuleSet ruleSet,AttributeSet attribs){
		foreach(param; params){
			param.flavor = VariableRef.PredicateArgument;
			thisRule.register(param,ruleSet,attribs);
		}
	}	
	
	public String getType(Rule thisRule,RuleSet ruleSet,AttributeSet attribs){
		return decl.type;
	}
}

class ClassPredicate: RulePredicate{		
	public Param[] params;
	public String type;
	
	public this(String type,Param[] params...){
		this.type = type;
		this.params = params.dup;
	}
		
	public void semanticPass(Rule thisRule,RuleSet ruleSet,AttributeSet attribs){
		foreach(param; params){
			param.flavor = VariableRef.PredicateArgument;
			thisRule.register(param,ruleSet,attribs);
		}
	}		
	
	public String getType(Rule thisRule,RuleSet ruleSet,AttributeSet attribs){
		return type;
	}
}

class DefaultPredicate: RulePredicate{		
	public this(){
	}
	
	public void semanticPass(Rule thisRule,RuleSet ruleSet,AttributeSet attribs){
		//do nothing
	}
	
	public String getType(Rule thisRule,RuleSet ruleSet,AttributeSet attribs){
		return "void";
	}
}