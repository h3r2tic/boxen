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
module enki.Rule;

import enki.Expression;
import enki.RuleSet;
import enki.AttributeSet;
import enki.Param;
import enki.RulePredicate;
import enki.VariableRef;
import enkilib.d.ParserException;

debug import tango.io.Stdout;

abstract class Rule{
	alias char[] String;
	
	public int insertOrder;
	
	public String getType(RuleSet ruleSet,AttributeSet attribs);
	public String getName();

	public void semanticPass(RuleSet ruleSet,AttributeSet attribs){
		//do nothing
	}

	public String getParameterType(uint ordinal,RuleSet ruleSet,AttributeSet attribs){
		//do nothing
		return null;
	}

	public void register(VariableRef variable,RuleSet ruleSet,AttributeSet attribs){
		//do nothing
	}
}

class RuleAlias: Rule{	
	public String name;
	public String aliasRule;

	public this(String name,String aliasRule){
		this.name = name;
		this.aliasRule = aliasRule;
	}

	public String getType(RuleSet ruleSet,AttributeSet attribs){
		auto otherRule = ruleSet[aliasRule];
		return otherRule.getType(ruleSet,attribs);
	}

	public String getName(){
		return name;
	}

	public void semanticPass(RuleSet ruleSet,AttributeSet attribs){
		auto otherRule = ruleSet[aliasRule];

		if(!otherRule){
			throw ParserException("Cannot find target rule {0} for alias {1}.",aliasRule,name);
		}

		otherRule.semanticPass(ruleSet,attribs);
	}

	public String getParameterType(uint ordinal,RuleSet ruleSet,AttributeSet attribs){
		auto otherRule = ruleSet[aliasRule];
		return otherRule.getParameterType(ordinal,ruleSet,attribs);
	}
}

// maps a rule name to a type, for a pre-defined rule
class RulePrototype: Rule{
	public String name;
	public String type;

	public this(String name,String type){
		this.name = name;
		this.type = type;
	}

	public String getType(RuleSet ruleSet,AttributeSet attribs){
		return type;
	}

	public String getName(){
		return name;
	}
}

class RuleDefinition: Rule{	
	String name;
	String type;
	Param[] ruleParameters;
	RulePredicate pred;
	Param[] vars;
	Expression expr;

	VariableRefSet variableRefs;
	bool semanticDone;

	public this(String name,Param[] ruleParameters,RulePredicate pred,Param[] vars,Expression expr){
		this.name = name;
		this.pred = pred;
		this.vars = vars;
		this.expr = expr;
		this.ruleParameters = ruleParameters;

		if(!pred){
			this.pred = new DefaultPredicate();
		}
	}

	public String getType(RuleSet ruleSet,AttributeSet attribs){
		if(!type){
			this.semanticPass(ruleSet,attribs);
			type = pred.getType(this,ruleSet,attribs);
		}
		return type;
	}

	public String getName(){
		return name;
	}

	public void semanticPass(RuleSet ruleSet,AttributeSet attribs){
		try{			
			if(semanticDone) return;
			semanticDone = true;
			
			debug Stdout.format("--semanticPass for {}--",this.name).newline;

			foreach(ordinal,param; ruleParameters){
				param.flavor = VariableRef.RuleParameter;
				param.ordinal = ordinal;
				register(param,ruleSet,attribs);
			}

			foreach(var; vars){
				var.flavor = VariableRef.FreeVariable;
				register(var,ruleSet,attribs);
			}

			assert(expr);
			assert(pred);

			expr.semanticPass(this,ruleSet,attribs);
			pred.semanticPass(this,ruleSet,attribs);
			type = pred.getType(this,ruleSet,attribs);

			variableRefs.semanticPass(this,ruleSet,attribs);
			
			debug{
				auto funcPred = cast(FunctionPredicate)pred;
				if(funcPred){
					Stdout.format("Performing FunctionPredicate check").newline;
					foreach(param; funcPred.params){
						Stdout.format("=> {} {}",param.type,param.name).newline;
					}
				}
			}
			
			debug Stdout.format("--completed semanticPass for {}--",this.name).newline;
		}
		catch(Exception e){
			throw ParserException("during semantic pass of Rule '{0}'\n\t{1}",name,e.toString());
		}
	}

	public String getParameterType(uint ordinal,RuleSet ruleSet,AttributeSet attribs){
		if(ordinal >= ruleParameters.length){
			throw ParserException("Rule {0} only accepts {1} arguments.",name,ruleParameters.length);
		}
		return ruleParameters[ordinal].type;
	}

	public void register(VariableRef variable,RuleSet ruleSet,AttributeSet attribs){
		debug Stdout.format("{3} Register: {0}:{1} {2}",variable.type,variable.name,variable.flavor,this.name).newline;
		variableRefs.register(variable,ruleSet,attribs);
	}
}
import tango.io.Stdout;

class Comment: Rule{	
	public String name;
	public String comment;

	public this(String name,String comment){
		this.comment = comment;
	}

	public String getType(RuleSet ruleSet,AttributeSet attribs){
		return null;
	}

	public String getName(){
		return name;
	}
}

/*
class InlineRule(CharT) : RuleT!(CharT){
	
	String name;
	Expression expr;

	VariableRefSet variableRefs;
	bool semanticDone;

	public this(String name,Expression expr){
		this.name = name;
		this.expr = expr;
	}

	public String getType(RuleSet ruleSet,AttributeSet attribs){
		return "void";
	}

	public String getName(){
		return name;
	}

	public void semanticPass(RuleSet ruleSet,AttributeSet attribs){
		try{
			if(semanticDone) return;
			semanticDone = true;
			expr.semanticPass(this,ruleSet,attribs);
		}
		catch(Exception e){
			throw ParserException("during semantic pass of Rule '{0}'\n\t{1}",name,e.toString());
		}
	}

	public String getParameterType(uint ordinal,RuleSet ruleSet,AttributeSet attribs){
		return null;
	}

	public void register(VariableRef variable,RuleSet ruleSet,AttributeSet attribs){
		//do nothing
	}
}
*/
abstract class Directive: Rule{
}
