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
module enki.Expression;

import enki.ProductionArg;
import enki.Binding;
import enki.RuleSet;
import enki.AttributeSet;
import enki.Rule;
import enki.VariableRef;
public import Integer = tango.text.convert.Integer;

debug import tango.io.Stdout;

interface Grouping{
    //nothing
}

abstract class Expression{
	alias char[] String;
	
	public Binding binding;
	
	protected this(Binding binding=null){
		this.binding = binding;
	}

	public bool isDeterminate(){
		return true;
	}
	
	public String getExpressionType(Rule thisRule,RuleSet ruleSet,AttributeSet attribs){
		return "String"; //TODO: fail-over to "all-parsetype".
		//return "void";
	}
	
	public void semanticPass(Rule thisRule,RuleSet ruleSet,AttributeSet attribs){
		if(binding){
			if(!binding.type) binding.type = this.getExpressionType(thisRule,ruleSet,attribs);
			thisRule.register(binding,ruleSet,attribs);
		}
	}
}

class Group: Expression,Grouping{
	public Expression expr;
	
	public this(Expression expr,Binding binding=null){
		super(binding);
		this.expr = expr;
	}
	
	public void semanticPass(Rule thisRule,RuleSet ruleSet,AttributeSet attribs){
		expr.semanticPass(thisRule,ruleSet,attribs);
		super.semanticPass(thisRule,ruleSet,attribs);
	}
}

class OrGroup: Expression,Grouping{
	public Expression[] exprs;
	
	public this(Expression[] exprs...){
		this.exprs = exprs.dup;
	}
		
	public void semanticPass(Rule thisRule,RuleSet ruleSet,AttributeSet attribs){
		foreach(expr; exprs){
			expr.semanticPass(thisRule,ruleSet,attribs);
		}
		super.semanticPass(thisRule,ruleSet,attribs);
	}
}
class AndGroup: Expression,Grouping{
	public Expression[] exprs;
		
	public this(Expression[] exprs...){
		this.exprs = exprs.dup;
	}
	
	public void semanticPass(Rule thisRule,RuleSet ruleSet,AttributeSet attribs){
		foreach(expr; exprs){
			expr.semanticPass(thisRule,ruleSet,attribs);
		}
		super.semanticPass(thisRule,ruleSet,attribs);
	}
}

class Optional: Expression{
	public Expression expr;
	
	public this(Expression expr,Binding binding=null){
		super(binding);
		this.expr = expr;
	}

	public bool isDeterminate(){
		return false;
	}
	
	public void semanticPass(Rule thisRule,RuleSet ruleSet,AttributeSet attribs){
		expr.semanticPass(thisRule,ruleSet,attribs);
		super.semanticPass(thisRule,ruleSet,attribs);
	}
}

class CharRange: Expression{
	public uint start;
	public uint end;
	public bool noRange; // deprecated
	public String type;
	
	public this(String start,String end,Binding binding=null){
		if(start && start.length > 0){
			this.start = Integer.parse(start,16);
		}
		if(end && end.length > 0){
			this.end = Integer.parse(end,16);
		}
		this.binding = binding;	
	}
	
	public this(uint start,uint end,Binding binding=null){
		this.start = start;
		this.end = end;
		this.binding = binding;
	}
}

class CustomTerminal: Expression{
	public String name;
	
	public this(String name,Binding binding=null){
		super(binding);
		this.name = name;
	}
	
	public String getExpressionType(Rule thisRule,RuleSet ruleSet,AttributeSet attribs){
		return null;
	}	
}

class Production: Expression{	
	public String name;
	public ProductionArg[] args;
	public Rule target;
	public String type;
	public bool passComplete;
	
	public this(String name,Binding binding=null,ProductionArg[] args=null ...){
		super(binding);
		this.name = name;
		this.args = args.dup;
	}
	
	public void semanticPass(Rule thisRule,RuleSet ruleSet,AttributeSet attribs){
		target = ruleSet[name];
		
		if(!target){
			throw new Exception("Unknown rule '" ~ name ~ "'.");
		}
		
		// forward the parameter type to each arg's semantic pass, via querying the target rule
		foreach(ordinal,arg; args){	
			if(arg.flavor == VariableRef.PredicateArgument){
				arg.flavor = VariableRef.ProductionArgument;
			}
			arg.ordinal = ordinal;
			arg.context = name;
			thisRule.register(arg,ruleSet,attribs);
		}
		
		// take a stab at resolving the type
		if(!type){
			type = target.getType(ruleSet,attribs);
		}
		
		super.semanticPass(thisRule,ruleSet,attribs);
		passComplete = true;
	}
		
	public String getExpressionType(Rule thisRule,RuleSet ruleSet,AttributeSet attribs){
		if(!type){
			// try again in case it wasn't already resolved
			type = ruleSet[name].getType(ruleSet,attribs);
		}
		return type;
	}
}

class RegularExpression: Expression{
	public String text;
	
	public this(String text,Binding binding=null){
		super(binding);
		this.text = text;
	}

	public bool isDeterminate(){
		return false;
	}
}

class Range{
	public uint min;
	public uint max;
	public uint hint;
	
	enum{
		IntegerBounds,
		ZeroOrMoreSuffix,
		OneOrMoreSuffix,
		OptionalSuffix,
		CurlyBraceGroup,
		OptionalGroup
	}
	
	public static Range ZeroOrMore(){
		Range r = new Range();
		r.min = 0;
		r.max = 0;
		r.hint = ZeroOrMoreSuffix;
		return r;
	}
		
	public static Range OneOrMore(){
		Range r = new Range();
		r.min = 1;
		r.max = 0;
		r.hint = OneOrMoreSuffix;
		return r;
	}	
	
	public static Range Optional(){
		Range r = new Range();
		r.min = 0;
		r.max = 1;
		r.hint = OptionalSuffix;
		return r;
	}
		
	public static Range OneOrMoreAlias(){
		Range r = new Range();
		r.min = 1;
		r.max = 0;
		r.hint = CurlyBraceGroup;
		return r;
	}
		
	public static Range OptionalAlias(){
		Range r = new Range();
		r.min = 0;
		r.max = 1;
		r.hint = OptionalGroup;
		return r;
	}
	
	public static Range opCall(uint min,uint max){
		Range r = new Range();
		r.min = min;
		r.max = max;
		r.hint = IntegerBounds;
		return r;
	}
	
	public bool isUnbounded(){
		return this.max == 0;
	}
}

public class Iterator: Expression{
	public Expression expr;
	public Expression delim;
	public Expression term;
	public Range[] ranges;
	
	public bool allowZero; //deprecated
	
	public this(Expression expr,Expression delim,Expression terminator,Range[] ranges){
		this.expr = expr;
		this.delim = delim;
		this.term = terminator;
		this.ranges = ranges;
	}

	public bool isDeterminate(){
		foreach(range; ranges){
			if(range.min == 0) return false;
		}
		return true;
	}

	public void semanticPass(Rule thisRule,RuleSet ruleSet,AttributeSet attribs){
		expr.semanticPass(thisRule,ruleSet,attribs);
		if(delim) delim.semanticPass(thisRule,ruleSet,attribs);
		if(term) term.semanticPass(thisRule,ruleSet,attribs);
		super.semanticPass(thisRule,ruleSet,attribs);
	}
	
	public bool hasHint(uint rangeHint){
		foreach(range; ranges){
			if(range.hint == rangeHint) return true;
		}
		return false;
	}

	public static Iterator create(Expression expr,Expression delim,Expression terminator,Range[] ranges){
		auto oneOrMore = cast(OneOrMoreExpr)expr;
		auto optional = cast(Optional)expr;
		if(oneOrMore){
			// append the iterator info to the existing iterator
			oneOrMore.delim = delim;
			oneOrMore.term = terminator;
			oneOrMore.ranges ~= ranges;
			return oneOrMore;
		}
		else if(optional){
			// replace the optional with an iterator
			auto iter = new Iterator(optional.expr,delim,terminator,ranges);
			iter.ranges ~= Range.OptionalAlias();
			return iter;
		}
		else{
			// pass-thru and create
			return new Iterator(expr,delim,terminator,ranges);
		}		
	}
}

class OneOrMoreExpr: Iterator{
	public this(Expression expr,Binding binding=null){
		super(expr,null,null,null);
		this.ranges ~= Range.OneOrMoreAlias();
	}
}

class Substitution: Expression{	
	public VariableRef subBinding;
	
	public this(String bindingName,Binding binding=null){
		super(binding);
		this.subBinding = new Binding(bindingName);
		this.subBinding.flavor = VariableRef.BindingReference;
	}

	public void semanticPass(Rule thisRule,RuleSet ruleSet,AttributeSet attribs){
		thisRule.register(subBinding,ruleSet,attribs);
	}
	
	public String getExpressionType(Rule thisRule,RuleSet ruleSet,AttributeSet attribs){
		return subBinding.type;
	}
}


class Literal: Expression{
	
	public String literalName;
	public ProductionArg[] args;
	
	public this(String literalName,Binding binding=null,ProductionArg[] args=null...){
		super(binding);
		this.literalName = literalName;
		this.args = args.dup;
	}
	
	public this(String literalName,ProductionArg[] args...){
		super(null);
		this.literalName = literalName;
		this.args = args.dup;
	}
	
	public void semanticPass(Rule thisRule,RuleSet ruleSet,AttributeSet attribs){
		foreach(ordinal,arg; args){
			arg.ordinal = ordinal;
			arg.flavor = VariableRef.PredicateArgument;
			arg.context = thisRule.getName();
			thisRule.register(arg,ruleSet,attribs);
		}
		super.semanticPass(thisRule,ruleSet,attribs);
	}
	
	public String getExpressionType(Rule thisRule,RuleSet ruleSet,AttributeSet attribs){
		return null;
	}	
}

class Terminal: Expression{
	public String text;
	
	public this(String text,Binding binding=null){
		super(binding);
		this.text = text;
	}
}

class Negate: Expression{
	public Expression expr;
	
	public this(Expression expr){
		this.expr = expr;
	}
	
	public void semanticPass(Rule thisRule,RuleSet ruleSet,AttributeSet attribs){
		expr.semanticPass(thisRule,ruleSet,attribs);
		super.semanticPass(thisRule,ruleSet,attribs);
	}
}

class Test: Expression{
	public Expression expr;
	
	public this(Expression expr){
		this.expr = expr;
	}
}

public class ErrorPoint: Expression{	
	public ProductionArg errMessage;
	public Expression expr;
	
	public this(ProductionArg errMessage,Expression expr){
		this.errMessage = errMessage;
		this.expr = expr;
	}

	public bool isDeterminate(){
		return false;
	}
	
	public void semanticPass(Rule thisRule,RuleSet ruleSet,AttributeSet attribs){
		errMessage.flavor = VariableRef.BindingReference;
		thisRule.register(errMessage,ruleSet,attribs);
		expr.semanticPass(thisRule,ruleSet,attribs);
		super.semanticPass(thisRule,ruleSet,attribs);
	}
}
