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
module enki.generator.BNFGenerator;

import enki.types;
import enki.generator.TextGenerator;

//import tango.io.model.IBuffer;
import tango.text.Util;

debug import tango.io.Stdout;

class BNFGenerator: TextGenerator{	
	AttributeSet attrs;
	bool mangleClosingComments = false;
	
	public static char[] getHelp(){
		return 
`EBNF Generator for Enki V2.0
Copyright (c) 2008 Eric Anderton

Generates an Enki2 EBNF script that is 
equivalent to the input BNF script.
Is used primarily for verification and
validation of Enki itself, but can also
be used with the alternative frontends
to translate to the Enki2 EBNF syntax.
`;
	}
    
    public this(){
        super();
    }
	
	public this(TextGenerator other){
		super(other);
	}
	
	public char[] getFilename(){
		return attrs.get("bnf","filename");
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
		String result = value.dup;
		size_t i = 0;
		
		void replace(String str){
			result = result[0..i] ~ str ~ result[i+1..$];
			i += str.length-1; // skew counter by insert length - 1
		}
		
		for(i=0; i<result.length; i++){
			switch(result[i]){
				case '\n': replace(`\n`); break;
				case '\r': replace(`\r`); break;
				case '\t': replace(`\t`); break;
				case '\"': replace(`\"`); break;
				case '\'': replace(`\'`); break;
				case '\\': replace(`\\`); break;
				case '+':
				case '*':
					if(mangleClosingComments){
						if(i+1 < result.length && result[i+1] == '/'){
							i++;
							replace("\\/"); // prevent quotes from prematurely closing comments						
						}
					}
					break;
				default:
					//do nothing
			}
		}
		return result;
	}
	
	void visit(AttributeSet attrs){
		auto attrFormat = ".{0}-{1} = \"{2}\";";
		String[String] xref;
		
		foreach(String namespace,AttributeMap innerAttrs; attrs.attributes){
			if(namespace == "all") continue;
			foreach(String name,String value; innerAttrs){
				xref[name] = name;
				value = substitute(value,"\"",`\"`);
				emitln(attrFormat,namespace,name,value);
			}
		}
		
		if("all" in attrs.attributes){
			foreach(String name,String value; attrs.attributes["all"]){
				if(name in xref) continue;
				value = substitute(value,"\"",`\"`);
				emitln(attrFormat,"all",name,value);
			}
		}
		
		this.attrs = attrs;
	}
	
	void visit(RuleSet ruleSet){
		foreach(rule;ruleSet.getRules()){
			visit(rule);
		}
	}
	
	void visit(Rule obj){
		if(cast(RuleAlias) obj)           visit(cast(RuleAlias) obj);
		else if(cast(RulePrototype) obj)  visit(cast(RulePrototype) obj);
		else if(cast(RuleDefinition) obj) visit(cast(RuleDefinition) obj);
		else if(cast(Comment) obj)        visit(cast(Comment) obj);
	}
	
	void visit(RuleAlias obj){
		with(obj){
			emitln("{0} ::= {1};",name,aliasRule);
			newline;
		}
	}
	
	void visit(RulePrototype obj){
		with(obj){
			// rule out implicit functions
			if(name == "nop" || name == "eoi" || name == "any") return;
			emitln("{0} = {1};",name,type);
			newline;
		}
	}
	
	void visit(RuleDefinition obj){
		with(obj){
			emit("{0}",name);
			if(ruleParameters.length > 0){
				emit("(");
				visitList(ruleParameters,",");
				emit(")");
			}
			newline;
			indent;
			visit(pred);			
			if(vars.length > 0){
				visitList(vars,"$","\n");
				newline;
			}			
			emit("::= ");
			visit(expr);
			emitln(";");
			unindent;
			newline;
		}		
	}	
	
	void visit(Comment obj){
		with(obj){
			newline;
			emitln("/*");
			emitln(substitute(comment,"\x2A\x2F",`\x2A\x2F`));
			emitln("*/");
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
		with(obj){
			if(binding){
				emit("(");
			}
			//debug Stdout.formatln("AndList: {0}",exprs.length);
			visitList(exprs," ");		
			if(binding){
				emit(")");
				visit(binding);
			}
		}	
	}
	
	void visit(Optional obj){
		with(obj){
			emit("[");
			visit(expr);
			emit("]");
							
			if(binding){
				visit(binding);
			}
		}
	}
	
	uint emitHex(uint value,uint size = 0){
		if(size == 8 || value > 0xFFFF){
			emit("#{0:X8}",value);
			return 8;
		}
		else if(size == 4 || value > 0xFF){
			emit("#{0:X4}",value);
			return 4;
		}
		else{
			emit("#{0:X2}",value);
			return 2;
		}
	}
	
	void visit(CharRange obj){
		with(obj){
			if(start == end){
				emitHex(start);
			}
			else{
				auto size = emitHex(start);
				emit("-");
				emitHex(end,size);
			}
			if(binding){
				visit(binding);
			}
		}			
	}
	
	void visit(OrGroup obj){
		with(obj){
			if(binding){
				emit("(");
			}
			visitList(exprs," | ");
			if(binding){
				emit(")");
				visit(binding);
			}				
		}
	}
	
	void visit(CustomTerminal obj){
		with(obj){
			emit("&{0}",name);
			if(binding){
				visit(binding);
			}
		}
	}
	
	void visit(Production obj){
		with(obj){
			emit(name);			
			if(args.length > 0){
				emit("!(");
				visitList(args,",");
				emit(")");
			}
			if(binding) visit(binding);
		}		
	}
	
	void visit(Group obj){
		with(obj){
			emit("(");
			visit(expr);
			emit(")");
		
			if(binding){
				visit(binding);
			}
		}			
	}
	
	void visit(RegularExpression obj){
		with(obj){
			emit("`{0}`",substitute(text,"`","\\`"));
			if(binding){
				visit(binding);
			}	
		}
	}
	
	void visit(Iterator obj){
        void parenEmit(Expression expr){
            if(cast(AndGroup)expr){
                emit("(");
                visit(cast(AndGroup)expr);
                emit(")");
            }
            else if(cast(OrGroup)expr){
                emit("(");
                visit(cast(OrGroup)expr);
                emit(")");
            }
            else {
                visit(expr);
            }
        }
		with(obj){
			// emit expr aliasing
			if(hasHint(Range.OptionalGroup)){
				emit("[");
				visit(expr);
				emit("]");
			}
			else if(hasHint(Range.CurlyBraceGroup)){
				emit("{{");
				visit(expr);
				emit("}");
			}
			else{
				parenEmit(expr);
			}
			
			// emit suffixes
			if(hasHint(Range.ZeroOrMoreSuffix)){
				emit("*");
			}
			else if(hasHint(Range.OneOrMoreSuffix)){
				emit("+");
			}
			else if(hasHint(Range.OptionalSuffix)){
				emit("?");
			}
			
			// emit integer ranges
			if(hasHint(Range.IntegerBounds)){
				emit("<");
				uint i=0;
				foreach(range; ranges){
					if(range.hint == Range.IntegerBounds){
						if(i > 0){
							emit(",");
						}
						if(range.min == range.max){
							emit("{0}",range.min);
						}
						else if(range.min == 0){
							emit("..{0}",range.max);
						}
						else if(range.max == 0){
							emit("{0}..",range.min);
						}
						else{
							emit("{0}..{1}",range.min,range.max);
						}
						i++;				
					}
				}
				emit(">");
			}
			
			if(delim){
				emit(" % ");
    			// handle a parse-tree anomaly
                parenEmit(delim);
			}
			
			if(term){
				emit(" ");
    			// handle a parse-tree anomaly
                parenEmit(term);
			}
		}		
	}
	
	void visit(Substitution obj){
		with(obj){
			emit(".{0}",subBinding.name);
			if(binding){
				visit(binding);
			}		
		}
	}
	
	void visit(Literal obj){
		with(obj){
			emit("@{0}",literalName);
			if(args.length > 0){
				emit("!(");
				visitList(args,",");
				emit(")");
			}
			if(binding){
				visit(binding);
			}
		}		
	}
	
	void visit(Terminal obj){
		with(obj){
			emit("\"{0}\"",safeString(text));
			if(binding){
				 visit(binding);
			}
		}
	}
	
	void visit(Negate obj){
		with(obj){
			emit("!");
			visit(expr);
		}
	}
	
	void visit(Test obj){
		with(obj){
			emit("/");
			visit(expr);
		}
	}
	
	void visit(ErrorPoint obj){
		with(obj){
			emit("?!(");
			visit(errMessage);
			emit(") ");
			visit(expr);
		}
	}
	
	void visit(ProductionArg obj){
		if(cast(StringProductionArg) obj)  visit(cast(StringProductionArg) obj);
		else visit(cast(BindingProductionArg) obj);
	}	
	
	void visit(StringProductionArg obj){
		emit("\"{0}\"",safeString(obj.value));
	}
	
	void visit(BindingProductionArg obj){
		emit("{0}",obj.name);
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
			emit("= ");
			visit(decl);
			newline;
		}
	}
	
	void visit(FunctionPredicate obj){
		with(obj){
			emit("= {0} {1}(",decl.type,decl.name);
			visitList(params,",");
			emitln(")");
		}		
	}
	
	void visit(ClassPredicate obj){
		with(obj){
			emit("= ");
			emit("new {0}(",type);
			visitList(params,",");
			emitln(")");
		}		
	}
	
	void visit(DefaultPredicate obj){
		//do nothing
	}
	
	void visit(Binding obj){
		with(obj){
			format(":{0}{1}",isConcat ? "~":"", name);
		}
	}
		
	void visit(Param obj){
		with(obj){
			if(type && type != "void"){
				emit(type);
				emit(" ");
			}
			emit(name);
			if(value){
				emit("=\"{0}\"",safeString(value));
			}
		}
	}
}

