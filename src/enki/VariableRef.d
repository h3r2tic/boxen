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
module enki.VariableRef;
import enki.Rule;
import enki.RuleSet;
import enki.AttributeSet;
import enkilib.d.ParserException;

import tango.io.Stdout;

class VariableRef{	
	alias char[] String;	
	public String type;
	public String name;
	public uint flavor;
	public uint ordinal;   // used by Production and Literal
	public String context; // used by Production and Literal
	
	// listed in order of type-resolution precedence
	enum: uint{
		Unknown,                   // default for Param instances
		RuleParameter,             // used by RuleDecl
		FreeVariable,              // used by RuleDefinition
		PredicateArgument,         // used by RulePredicate subclasses
		BindingReference,          // used by Binding,Substitution and ErrorPoint
		ProductionArgument,        // used by Production
		LiteralArgument            // references a literal value of some kind
	}	
		
	public this(uint flavor){
		this.flavor = flavor;
	}
	
	public this(String name,uint flavor){
		this.name = name;
		this.flavor = flavor;
	}
	
	public this(String type,String name,uint flavor){
		this.name = name;
		this.type = type;
		this.flavor = flavor;
	}
}

//TODO: find some way to pass literal types forward to their context
struct VariableRefSet{
	alias char[] String;	
	VariableRef[] variableRefs;
	VariableRef[String] distinctRefs;
	
	void register(VariableRef variable,RuleSet ruleSet,AttributeSet attribs){
		if(variable.flavor == VariableRef.LiteralArgument) return; // ignored
		variableRefs ~= variable;
		if(variable.name in distinctRefs){
			if(distinctRefs[variable.name].flavor > variable.flavor){
				distinctRefs[variable.name] = variable;				
			}
		}
		else{
			distinctRefs[variable.name] = variable;
		}
	}
		
	void semanticPass(Rule thisRule,RuleSet ruleSet,AttributeSet attribs){
		String[String] variableTypes;
		
		bool isValidType(String type){
			return type && type != "";
		}
				
		debug{
			Stdout.format("Variable Refs for {}",thisRule.getName()).newline;
			foreach(variable; variableRefs){
				Stdout.format("({}) '{}' '{}' ctx:{} ord:{}",variable.flavor,variable.type,variable.name,variable.context,variable.ordinal).newline;
			}
		}
				
		//attempt to resolve types
		foreach(variable; variableRefs){
			auto name = variable.name;	
			if(!isValidType(variable.type)){
				// attempt to resolve forward reference to production parameter
				if(variable.flavor == VariableRef.ProductionArgument){
					auto context = ruleSet[variable.context];
					auto paramType = context.getParameterType(variable.ordinal,ruleSet,attribs);
					
					if(isValidType(paramType)){
						if(isValidType(variable.type) && paramType != variable.type){
							throw ParserException("Argument #{} of type '{}' does not agree with '{}' parameter type of '{}', in rule '{}'",
								variable.ordinal,variable.type,variable.context,paramType,thisRule.getName());
						}
						variable.type = paramType;
					}
				}
				// attempt to reconcile against the map	
				if(name in variableTypes){
					auto registeredType = variableTypes[name];
					// make sure variable type agrees with other declarations
					if(isValidType(variable.type)){
						if(variable.type != registeredType){
							//if(variable.flavor == VariableRef.BindingReference){
								Stdout.format("Warning: Variable '{}' resolves to at least two types: '{}' and '{}' in rule '{}'",name,variable.type,registeredType,thisRule.getName()).newline;
							//}
							//else{
							//	throw ParserException("Variable '{}' resolves to at least two types: '{}' and '{}' in rule '{}'",name,variable.type,type,thisRule.getName());
							//}
						}
					}
					else{
						variable.type = registeredType; // resolve variable type
					}
				}
			}
			variableTypes[name] = variable.type; // log the type in the type map
		}
				
		//use typemap to resolve unresolved variables
		foreach(variable; variableRefs){
			if(!isValidType(variable.type)){
				auto type = variableTypes[variable.name];
				if(!isValidType(type)){
					throw ParserException("Cannot resolve type of variable '{}' in rule '{}'",variable.name,thisRule.getName());
				}
				variable.type = type; // patch up variable types
			}
		}
	}
	
	public VariableRef[] all(){
		return distinctRefs.values;
	}
}