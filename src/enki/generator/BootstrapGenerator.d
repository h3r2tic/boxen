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
module enki.generator.BootstrapGenerator;

import enki.types;
import enki.generator.TextGenerator;

//import tango.io.model.IBuffer;
import tango.text.Util;

class BootstrapGenerator: TextGenerator{
	AttributeSet attrs;
		
	public static char[] getHelp(){
		return 
`Bootstrap Generator for Enki V2.0
Copyright (c) 2008 Eric Anderton

Generates a bootstrap module in D, 
based on the input EBNF script.

A bootstrap script is a 100% in-code 
rendition of the input set.  It's 
primary purpose is to function as a 
stand-in for the parser pass, in such a 
way that one can 'bootstrap' development 
of a tool like Enki. In fact, Enki was 
developed with such a boostrap module.

This generator is used primarily for 
verification and validation of Enki 
itself, and is not used for general 
development.
`;
	}
    
    public this(){
        super();
    }
	
	public this(TextGenerator other){
		super(other);
	}
	
	public char[] getFilename(){
		return attrs.get("bootstrap","filename");
	}	
		
	protected void visitList(T,S)(T[] list,S delim){
		foreach(i,item; list){
			if(i > 0) emit(delim);
			this.visit(item);
		}
	}
	
	protected void visitList(T,S1,S2)(T[] list,S1 prefix,S2 delim){
		foreach(i,item; list){
			if(i > 0) emit(delim);
			emit(prefix);
			this.visit(item);
		}
	}
		
	protected String safeString(String value){
		String result = value;
		result = substitute(result,"\\",`\\`);
		result = substitute(result,"\n",`\n`);
		result = substitute(result,"\r",`\r`);
		result = substitute(result,"\t",`\t`);
		result = substitute(result,"\"",`\"`);
		result = substitute(result,"\x2A\x2F",`\x2A\x2F`); // slash-star closing
		result = substitute(result,"\x2A\x2B",`\x2A\x2B`); // slash-plus closing
		return result;
	}
	
	void visit(AttributeSet attrs){
		// emit prolog
		emitln("module {0};",attrs.get("bootstrap","modulename"));
		emitln("private import enki.bootstrap.bootstrap;");
		emitln("class {0}: Bootstrap{{",attrs.get("bootstrap","classname"));
		indent;
		emitln("void runBootstrap(){{");
		indent;	
			
		auto attrFormat = `setAttribute("{0}","{1}","{2}");`;
		String[String] xref;
		
		foreach(String namespace,AttributeMap innerAttrs; attrs.attributes){
			if(namespace == "all") continue;
			foreach(String name,String value; innerAttrs){
				xref[name] = name;
				value = substitute(value,"\"",`\"`);
				emitln(attrFormat,namespace,name,value);
			}
		}		
		
		foreach(String name,String value; attrs.attributes["all"]){
			if(name in xref) continue;
			value = substitute(value,"\"",`\"`);
			emitln(attrFormat,"all",name,value);
		}		
		
		this.attrs = attrs;
	}
	
	void visit(RuleSet ruleSet){
		foreach(rule;ruleSet.getRules()){
			newline;
			visit(rule);
		}
		
		// emit epilog
		unindent;
		emitln("}");
		unindent;
		emitln("}");
	}
	
	void visit(Rule obj){
		if(cast(RuleAlias) obj)           visit(cast(RuleAlias) obj);
		else if(cast(RulePrototype) obj)  visit(cast(RulePrototype) obj);
		else if(cast(RuleDefinition) obj) visit(cast(RuleDefinition) obj);
		else if(cast(Comment) obj)        visit(cast(Comment) obj);
	}
	
	void visit(RuleAlias obj){
		with(obj){
			emitln(`addAlias("{0}","{1}");`,name,aliasRule);
		}
	}
	
	void visit(RulePrototype obj){
		with(obj){
			emitln(`addPrototype("{0}","{1}");`,name,type);
		}
	}
	
	void visit(RuleDefinition obj){
		with(obj){
			emitln(`addRule("{0}",`,name);
			indent;
				emit("/*params*/");
				if(ruleParameters.length > 0){
					emit("paramList(");
					foreach(param; ruleParameters){
						visit(param);
					}
					emitln("),");
				}
				else{
					emitln("null,");
				}
				
				emit("/*predicate*/");
				visit(pred);
				
				emit("/*vars*/");
				if(vars.length > 0){
					emit("paramList(");
					foreach(variable; vars){
						visit(variable);
					}
					emitln("),");
				}
				else{
					emitln("null,");
				}
							
				emit("/*expr*/");
				visit(expr);
				
				newline;
			unindent;
			emitln(");");
		}	
	}
	
	void visit(Comment obj){
		with(obj){
			newline;
			emit(`addComment("{0}");`,substitute(comment,"\x2A\x2F",`\x2A\x2F`));
			newline;
		}		
	}
	// visitor dispatch routine
	void visit(Expression obj){
		if(cast(AndGroup) obj)               visit(cast(AndGroup) obj);
		else if(cast(Optional) obj)          visit(cast(Optional) obj);
		else if(cast(CharRange) obj)         visit(cast(CharRange) obj);
		else if(cast(OrGroup) obj)           visit(cast(OrGroup) obj);
		else if(cast(CustomTerminal) obj)    visit(cast(CustomTerminal) obj);
		else if(cast(Production) obj)        visit(cast(Production) obj);
		else if(cast(Group) obj)             visit(cast(Group) obj);
		else if(cast(RegularExpression) obj) visit(cast(RegularExpression) obj);
		else if(cast(Iterator) obj)          visit(cast(Iterator) obj);
		else if(cast(Substitution) obj)      visit(cast(Substitution) obj);
		else if(cast(Literal) obj)           visit(cast(Literal) obj);
		else if(cast(Terminal) obj)          visit(cast(Terminal) obj);
		else if(cast(Negate) obj)            visit(cast(Negate) obj);
		else if(cast(Test) obj)              visit(cast(Test) obj);
		else if(cast(ErrorPoint) obj)	     visit(cast(ErrorPoint) obj);
	}

	void visit(AndGroup obj){
		// optimize
		if(obj.exprs.length == 1 && !obj.binding){
			visit(obj.exprs[0]);
			return;
		}
		
		with(obj){
			emitln("new AndGroup(");
			indent;
				visitList(exprs,",\n");
				if(binding){
					emitln(",");
					visit(binding);
				}
				else{
					newline;
				}
			unindent;
			emit(")");
		}	
	}
	
	void visit(Optional obj){
		with(obj){
			emitln("new Optional(");
			indent;
				visit(expr);
				if(binding){
					emitln(",");
					visit(binding);
				}
				else{
					newline;
				}				
			unindent;
			emit(")");
		}
	}	
	
	uint emitHex(uint value,uint size = 0){
		if(size == 8 || value > 0xFFFF){
			emit("0x{0:X8}",value);
			return 8;
		}
		else if(size == 4 || value > 0xFF){
			emit("0x{0:X4}",value);
			return 4;
		}
		else{
			emit("0x{0:X2}",value);
			return 2;
		}
	}
	
	void visit(CharRange obj){
		with(obj){
			if(noRange){
				emit("new CharRange(");
				emitHex(start);
			}
			else{
				emit("new CharRange(");
				auto size = emitHex(start);
				emit(",");
				emitHex(end,size);
			}
			if(binding){
				emit(",");
				visit(binding);
			}
			emit(")");
		}			
	}
	
	void visit(OrGroup obj){
		// optimize
		if(obj.exprs.length == 1 && !obj.binding){
			visit(obj.exprs[0]);
			return;
		}		
		with(obj){
			emitln("new OrGroup(");
			indent;
				visitList(exprs,",\n");
				if(binding){
					emitln(",");
					visit(binding);
				}
				else{
					newline;
				}
			unindent;
			emit(")");
		}	
	}
	
	void visit(CustomTerminal obj){
		with(obj){
			emit(`new CustomTerminal("{0}"`,name);
			if(binding){
				emit(",");
				visit(binding);
			}
			emit(")");
		}
	}
	
	void visit(Production obj){
		with(obj){
			emit(`new Production("{0}"`,name);
			if(binding){
				emit(",");
				visit(binding);
			}
			else if(args.length > 0){
				emit(",null");
			}
			if(args.length > 0){
				emitln(",");
				indent;
					visitList(args,",\n");
				unindent;
				newline;
			}
			emit(")");
		}		
	}
	
	void visit(Group obj){
		with(obj){
			emitln("new Group(");
			indent;
				visit(expr);
				if(binding){
					emitln(",");
					visit(binding);
				}
				newline;
			unindent;
			emit(")");		
		}			
	}
	
	void visit(RegularExpression obj){
		with(obj){
			emit("new RegularExpression(`{0}`",substitute(text,"`","\\`"));
			if(binding){
				emit(",");
				visit(binding);
			}
			emit(")");
		}
	}
	
	void visit(Iterator obj){
		with(obj){
			emitln("new Iterator(");
			indent;
				emit("/*expr*/");				
				visit(expr);
				emitln(",");
				
				emit("/*delimeter*/");
				if(delim){
					visit(delim);
					emitln(",");
				}
				else{
					emitln("null,");
				}
				
				emit("/*terminator*/");
				if(term){
					visit(term);
					emitln(",");
				}
				else{
					emitln("null,");
				}
				
				if(ranges && ranges.length > 0){
					emit("/*ranges*/rangeList(");
					foreach(i,range; ranges){
						if(i > 0){
							emit(",");
						}
						switch(range.hint){
						case Range.IntegerBounds:    emit("Range.integerRange({0},{1})",range.min,range.max); break;
						case Range.ZeroOrMoreSuffix: emit("Range.ZeroOrMore()"); break;
						case Range.OneOrMoreSuffix:  emit("Range.OneOrMore()"); break;
						case Range.OptionalSuffix:   emit("Range.Optional()"); break;
						case Range.CurlyBraceGroup:  emit("Range.OneOrMoreAlias()"); break;
						case Range.OptionalGroup:    emit("Range.OptionalAlias()"); break;
						}
					}
					emit(")");
				}
				newline;
			unindent;
			emit(")");
		}		
	}
	
	void visit(Substitution obj){
		with(obj){
			emit(`new Substitution("{0}"`,subBinding.name);
			if(binding){
				emit(",");
				visit(binding);
			}
			emit(")");
		}
	}
	
	void visit(Literal obj){			
		with(obj){
			emit(`new Literal("{0}"`,literalName);
			if(binding){
				emit(",");
				visit(binding);
			}
			if(args.length > 0){
				emitln(",");
				indent;
					visitList(args,",\n");
				unindent;
				newline;
			}
			emit(")");
		}
	}
	
	void visit(Terminal obj){
		with(obj){
			emit(`new Terminal("{0}"`,safeString(text));
			if(binding){
				emit(",");
				visit(binding);
			}
			emit(")");
		}		
	}
	
	void visit(Negate obj){
		with(obj){
			emit("new Negate(");
			indent;
				visit(expr);
				newline;
			unindent;
			emit(")");
		}
	}
	
	void visit(Test obj){
		with(obj){
			emit("new Test(");
			indent;
				visit(expr);
				newline;
			unindent;
			emit(")");
		}
	}
	
	void visit(ErrorPoint obj){
		with(obj){
			emit("new ErrorPoint(");
			visit(errMessage);
			emitln(",");
			indent;
				visit(expr);
				newline;
			unindent;
			emit(")");
		}
	}
	
	void visit(ProductionArg obj){
		if(cast(StringProductionArg) obj)  visit(cast(StringProductionArg) obj);
		else visit(cast(BindingProductionArg) obj);
	}	
	
	void visit(StringProductionArg obj){
		emit(`new StringProductionArg("{0}")`,safeString(obj.value));
	}
	
	void visit(BindingProductionArg obj){
		emit(`new BindingProductionArg("{0}")`,obj.name);
	}	
	
	void visit(RulePredicate obj){
		if(cast(BindingPredicate) obj)  visit(cast(BindingPredicate) obj);
		else if(cast(FunctionPredicate) obj)  visit(cast(FunctionPredicate) obj);
		else if(cast(ClassPredicate) obj)  visit(cast(ClassPredicate) obj);
		else if(cast(DefaultPredicate) obj)  visit(cast(DefaultPredicate) obj);
		else throw new Exception("unknown predicate type");
	}
		
	void visit(BindingPredicate obj){
		with(obj){
			emit("new BindingPredicate(");
			visit(decl);
			emitln("),");
		}
	}
	
	void visit(FunctionPredicate obj){
		with(obj){
			emit("new FunctionPredicate(");
			visit(decl);
			if(params.length > 0){
				emitln(",");
				indent;
					visitList(params,",\n");
				unindent;
				newline;
			}
			emitln("),");
		}		
	}
	
	void visit(ClassPredicate obj){
		with(obj){			
			emit(`new ClassPredicate("{0}"`,type);
			if(params.length > 0){
				emitln(",");
				indent;
					visitList(params,",\n");
				unindent;
				newline;
			}
			emitln("),");			
		}		
	}
	
	void visit(DefaultPredicate obj){
		//do nothing
	}
	
	void visit(Binding obj){
		with(obj){
			if(isConcat){
				emit(`CatBinding("{0}")`,name);
			}
			else{
				emit(`new Binding("{0}")`,name);
			}
		}
	}
		
	void visit(Param obj){
		with(obj){
			if(type && type != "void"){
				emit(`new Param("{0}","{1}"`,type,name);
			}
			else{
				emit(`new Param("{0}"`,name);
			}
			if(value){
				emit(`,"{0}")`,safeString(value));
			}
			else{
				emit(")");
			}
		}
	}
}

