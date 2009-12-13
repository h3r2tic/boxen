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
module enki.generator.DGenerator;

import enki.types;
import enki.generator.TextGenerator;
import enki.generator.BNFGenerator;
import enkilib.d.ParserException;

import tango.io.model.IBuffer;
import tango.text.Util;

debug private import tango.io.Stdout;

class DGenerator: TextGenerator{	
	public AttributeSet attrs;	
	uint identifierId;
	bool useAST;
    bool cullWhitespace;
	
	public static char[] getHelp(){
		return 
`D Parser Generator for Enki V2.0
Copyright (c) 2008 Eric Anderton

Generates a parser based on the input
EBNF that is suitable for use in the 
D Programming Langauge.

The support code for running the 
generated parser is available in the 
Enki SDK, under /enkilib/d/.
`;
	}
    
    private static char[] cull_WS = `
void cull_WS(){{
    while(hasMore()){{
        switch(data[pos]){{
        case ' ':
        case '\t':
        case '\n':
        case '\r':
            pos++;
        default:
            return;
        }
    }
}
`;
        
    private static char[] cull_WS_proto = `
abstract void cull_WS();
`;
    	
	public this(){
		attrs.set("all","help","");
		attrs.set("all","copyright","");
		attrs.set("d","header","import enkilib.d.CharParser;");
		attrs.set("d","baseclass","CharParserT!(char)");
		attrs.set("d","filename","Parser.d");
		attrs.set("d","classname","Parser");
		attrs.set("d","useast","false");
        attrs.set("d","whitespace","keep");
	}

	public char[] getFilename(){
		return attrs.get("d","filename");
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
				default:
					//do nothing
			}
		}
		return result;
	}
	
	void startIdGen(){
		identifierId = 0;
	}

	String getId(String kind){
		String id = kind ~ Integer.toString(identifierId);
		identifierId++;
		return id;
	}

	String getPassId(){
		return getId("pass");
	}

	String getFailId(){
		return getId("fail");
	}

	String getTermId(){
		return getId("term");
	}

	void emitId(String id){
		emitln("{0}:",id);
	}

	void emitGoto(String id){
		emitln("goto {0};",id);
	}

	String savePositionId(){
		String id = "position" ~ Integer.toString(identifierId);
		identifierId++;
		emitln("auto {0} = pos;",id);
		return id;
	}

	void assignSlice(Binding binding,String startPositionId){
		if(binding.isConcat){
			emitln("smartAppend(var_{0},slice({1},pos));",binding.name,startPositionId);
		}
		else{
			emitln("smartAssign(var_{0},slice({1},pos));",binding.name,startPositionId);
		}
	}

	void assignResults(Binding binding,String predicateName){
		if(binding.isConcat){
			emitln("smartAppend(var_{0},value_{1});",binding.name,predicateName);
		}
		else{
			emitln("smartAssign(var_{0},value_{1});",binding.name,predicateName);
		}
	}
    
	void assignVar(Binding binding,String varName){
		if(binding.isConcat){
			emitln("smartAppend(var_{0},var_{1});",binding.name,varName);
		}
		else{
			emitln("smartAssign(var_{0},var_{1});",binding.name,varName);
		}
	}    
    
	void assignResults(Binding binding){
		if(binding.isConcat){
			emitln("smartAppend(var_{0},__match);",binding.name);
		}
		else{
			emitln("smartAssign(var_{0},__match);",binding.name);
		}
	}
	
	void assign(Binding binding,String varId){
		if(binding.isConcat){
			emitln("smartAppend(var_{0},{1});",binding.name,varId);
		}
		else{
			emitln("smartAssign(var_{0},{1});",binding.name,varId);
		}
	}

	void unwind(String posId){
		emitln("pos = {0};",posId);
	}
    
    void parseWhitespace(){
        if(this.cullWhitespace){
            emit("cull_WS();");
        }
    }

	void visit(AttributeSet attrs){
		this.attrs.mesh(attrs);
	}

	void visit(RuleSet ruleSet){
		auto copyright = attrs.get("all","copyright");
		auto header    = attrs.get("d","header");
		auto baseclass = attrs.get("d","baseclass");
		auto classname = attrs.get("d","classname");
        
		this.useAST = (attrs.get("d","useast") == "true");
        this.cullWhitespace = (attrs.get("d","whitespace") == "cull");

		// d-header
		if(copyright.length > 0){
			emit("/+");
			emitln(copyright);
			emitln("+/");
		}
		emitln(header);
		emitln("debug import tango.io.Stdout;");
		
		
		// d-classname and d-baseclass
		newline;
		emitln("class {0}:{1}{{",classname,baseclass);

		indent;
			// help stub
			auto help = attrs.get("all","help");
			emitln("static char[] getHelp(){{");
			indent;
				emitln("return \"{0}\";",safeString(help));
			unindent;
			emitln("}");
            
            // special methods
            if(this.cullWhitespace){
                emit(this.cull_WS);
            }
		
			// class body
			foreach(rule;ruleSet.getRules()){
				visit(rule);
			}
		unindent;
		emitln("}");
	}	
	
	void visit(Rule obj){		
		// generate code for rule
		if(cast(RuleAlias) obj)           visit(cast(RuleAlias) obj);
		else if(cast(RulePrototype) obj)  visit(cast(RulePrototype) obj);
		else if(cast(RuleDefinition) obj) visit(cast(RuleDefinition) obj);
		else if(cast(Comment) obj)        visit(cast(Comment) obj);
	}

	void visit(RuleAlias obj){
		emitln("alias parse_{0} parse_{1};",obj.aliasRule,obj.name);
	}

	void visit(RulePrototype obj){
		//do nothing
	}

	void visit(RuleDefinition obj){
		auto bnf = new BNFGenerator(this);
		bnf.mangleClosingComments = true;

		// emit as comment w/complete BNF data
		newline;
		emitln("/*");
			//bnf.indent;
			bnf.visit(obj);
			//bnf.unindent;
		emitln("*/");
				
		startIdGen();
		auto passId = getPassId();
		auto failId = getFailId();
		with(obj){
            if(type != "void"){
                emitln("{0} value_{1};",type,name);
            }
            else{
                emitln("bool value_{0};",name);
            }
			emit("bool parse_{0}(",name);
			if(ruleParameters.length > 0){
				bool first = true;
				foreach(param; ruleParameters){
					if(!first) emit(",");
					emit("{0} var_{1}",param.type,param.name);
					first = false;
				}
			}
			emitln("){{");
			indent;
				emitln("debug Stdout(\"parse_{0}\").newline;",name);
				if(useAST){
					emitln("auto __astNode = createASTNode(\"{0}\");",name);
				}
				foreach(var; variableRefs.all){
					if(var.flavor != VariableRef.RuleParameter){
						visit(var);
					}
				}
				if(variableRefs.all.length > 0){
					newline;
				}
				
				visit(expr,passId,failId,PassFollow);
	
				emitln("// Rule");
				emitId(passId);
				indent;
					auto fnPred = cast(FunctionPredicate)pred;
					if(fnPred && fnPred.decl.type == "void"){
						visit(pred);
						emitln(";");
						emitln("debug Stdout(\"passed\").newline;");
					}
					else if(type != "void"){
						emit("value_{0} = ",name);
						visit(pred);
						emitln(";");
						emitln("debug Stdout.format(\"\\tparse_{0} passed: {{0}\",value_{0}).newline;",name);
					}else{	
						emitln("debug Stdout(\"passed\").newline;");
					}
					if(useAST){
						emitln("setASTResult(__astNode);");
					}
					emitln("return true;");
				unindent;
				emitId(failId);
				indent;
					if(type != "void"){
						emitln("value_{0} = ({1}).init;",name,type);
					}
					emitln("debug Stdout.format(\"\\tparse_{0} failed\").newline;",name);
					if(useAST){
						emitln("clearASTResult(__astNode);");
					}
					emitln("return false;");
				unindent;
			unindent;
			emitln("}");
		}
	}
	void visit(Comment obj){
		//do nothing
		newline;
		emitln("/*");
		emitln(substitute(obj.comment,"\x2A\x2F",`\x2A\x2F`));
		emitln("*/");
		newline;
	}

	void visit(VariableRef obj){
		if(obj.name){
			auto param = cast(Param)obj;
			if(param && param.value){
				String realType = param.type;
				if(param.type == "void"){
					realType = "String";
				}
				emitln("{0} var_{1} = \"{2}\";",realType,param.name,safeString(param.value));
			}
			else{
				String realType = obj.type;
				if(obj.type == "void"){
					realType = "String";
				}
				emitln("{0} var_{1};",realType,obj.name);
			}
		}
	}
	
	enum : bool{
		PassFollow = true,
		FailFollow = false
	}

	// visitor dispatch routine
	void visit(Expression obj,String passId,String failId,bool followOnPass){
		if(cast(AndGroup) obj)               visit(cast(AndGroup) obj,passId,failId,followOnPass);
		else if(cast(Optional) obj)          visit(cast(Optional) obj,passId,failId,followOnPass);
		else if(cast(CharRange) obj)         visit(cast(CharRange) obj,passId,failId,followOnPass);
		else if(cast(OrGroup) obj)           visit(cast(OrGroup) obj,passId,failId,followOnPass);
		else if(cast(CustomTerminal) obj)    visit(cast(CustomTerminal) obj,passId,failId,followOnPass);
		else if(cast(Production) obj)        visit(cast(Production) obj,passId,failId,followOnPass);
		else if(cast(Group) obj)             visit(cast(Group) obj,passId,failId,followOnPass);
		else if(cast(RegularExpression) obj) visit(cast(RegularExpression) obj,passId,failId,followOnPass);
		else if(cast(Iterator) obj)          visit(cast(Iterator) obj,passId,failId,followOnPass);
		else if(cast(Substitution) obj)      visit(cast(Substitution) obj,passId,failId,followOnPass);
		else if(cast(Literal) obj)           visit(cast(Literal) obj,passId,failId,followOnPass);
		else if(cast(Terminal) obj)          visit(cast(Terminal) obj,passId,failId,followOnPass);
		else if(cast(Negate) obj)            visit(cast(Negate) obj,passId,failId,followOnPass);
		else if(cast(Test) obj)              visit(cast(Test) obj,passId,failId,followOnPass);
		else if(cast(ErrorPoint) obj)	     visit(cast(ErrorPoint) obj,passId,failId,followOnPass);
		
	}

	void visit(AndGroup obj,String parentPassId,String parentFailId,bool followOnPass){
		String posId;
		String failId;
		
		// optimize
		if(obj.exprs.length == 1 && !obj.binding){
            if(!cast(OrGroup)(obj.exprs[0])){
                parseWhitespace();
            }        
			visit(obj.exprs[0],parentPassId,parentFailId,followOnPass);
			return;
		}

		with(obj){
			failId = getFailId();
			emitln("// AndGroup");
			indent;
				posId = savePositionId();
				failId = getFailId();
				foreach(i,expr; exprs){
					indent;
                    if(!cast(OrGroup)(expr)){
                        parseWhitespace();
                    }
					// last
					if(i == exprs.length-1){
                        if(binding){
                            auto passId = getPassId();
                            visit(expr,passId,failId,PassFollow);
                            emitId(passId);
                            assignSlice(binding,posId);
                            emitGoto(parentPassId);
                        }
                        else{
                            visit(expr,parentPassId,failId,FailFollow);
                        }
						unindent;
					}
					// all others
					else{
						auto termId = getTermId();
						visit(expr,termId,failId,PassFollow);
						unindent;
						emitId(termId);
					}
				}
				emitId(failId);
				unwind(posId);
				if(followOnPass){
					emitGoto(parentFailId);
				}
			unindent;
		}
	}

	void visit(Optional obj,String parentPassId,String parentFailId,bool followOnPass){
		with(obj){
			emitln("// Optional");
			indent;
				if(binding){
					auto posId  = savePositionId();
					auto passId = getPassId();
					auto failId = getFailId();

					indent;
						visit(expr,passId,failId,PassFollow);
					unindent;

					emitId(passId);
					indent;
						assignSlice(binding,posId);
					unindent;
					
					emitId(failId);
					if(!followOnPass){
						indent;
							emitGoto(parentPassId);
						unindent;
					}
				}
				else{
					visit(expr,parentPassId,parentPassId,followOnPass);
					if(!followOnPass){
						emitGoto(parentPassId);
					}
				}
			unindent;
		}
	}	
	
	uint emitHex(uint value,uint size = 0){
		if(size == 8 || value > 0xFFFF){
			emit("cast(dchar)0x{0:X8}",value);
			return 8;
		}
		else if(size == 4 || value > 0xFF){
			emit("cast(wchar)0x{0:X4}",value);
			return 4;
		}
		else{
			emit("cast(char)0x{0:X2}",value);
			return 2;
		}
	}

	void visit(CharRange obj,String parentPassId,String parentFailId,bool followOnPass){
		with(obj){
			emitln("// CharRange");
			if(followOnPass){
				emit("if(!match");
			}
			else{
				emit("if(match");
			}
			
			if(start == end){
				emit("(");
				emitHex(start);
				emitln(")){{");
			}
			else{
				emit("(");
				auto size = emitHex(start);
				emit(",");
				emitHex(end,size);
				emitln(")){{",start);
			}
			
			// bind and branch
			if(followOnPass){ // false branch
				indent;
					emitGoto(parentFailId);					
				unindent;
				emitln("}");
				if(binding){
					assignResults(binding); //TODO: fix me!
				}
			}
			else{ // true branch
				indent;
					if(binding){
						assignResults(binding); //TODO: fix me!
					}
					emitGoto(parentPassId);
				unindent;
				emitln("}");
			}
		}
	}

	void visit(OrGroup obj,String parentPassId,String parentFailId,bool followOnPass){
		String passId;
		String posId;
		
		if(obj.exprs.length == 1 && !obj.binding){
            if(!cast(AndGroup)(obj.exprs[0])){
                parseWhitespace();
            }        
			visit(obj.exprs[0],parentPassId,parentFailId,followOnPass);
			return;
		}
		
		with(obj){
			emitln("// OrGroup {0}",parentPassId);
			if(binding){
				posId = savePositionId();
				passId = getPassId();
			}
			foreach(i,expr; exprs){
				indent;
                if(!cast(AndGroup)(expr)){
                    parseWhitespace();
                }
				if(i == exprs.length-1){
					if(binding){
						visit(expr,passId,parentFailId,PassFollow);
					}
					else{
						visit(expr,parentPassId,parentFailId,followOnPass);						
					}
					unindent;
				}
				else{
					auto termId = getTermId();
					if(binding){
						visit(expr,passId,termId,FailFollow);
					}
					else{
						visit(expr,parentPassId,termId,FailFollow);					
					}					
					unindent;
					emitId(termId);
				}
			}
			if(binding){
				emitId(passId);
				indent;
					assignSlice(binding,posId);
					if(!followOnPass){
						emitGoto(parentPassId);
					}
				unindent;
			}
		}
	}

	void visit(CustomTerminal obj,String parentPassId,String parentFailId,bool followOnPass){
		with(obj){
			emitln("// CustomTerminal");	
			if(followOnPass){
				emitln("if(!match({0})){{",name);
			}
			else{
				emitln("if(match({0})){{",name);
			}
								
			// bind and branch
			if(followOnPass){ // false branch
				indent;
					emitGoto(parentFailId);					
				unindent;
				emitln("}");
				if(binding){
					assignResults(binding); //TODO: fix me!
				}
			}
			else{ // true branch
				indent;
					if(binding){
						assignResults(binding); //TODO: fix me!
					}
					emitGoto(parentPassId);
				unindent;
				emitln("}");
			}			
		}
	}

	void visit(Production obj,String parentPassId,String parentFailId,bool followOnPass){
		String posId;		
		with(obj){
			emitln("// Production");		
			if(type == "void" && binding){
				posId = savePositionId();				
			}
			
			if(followOnPass){
				emit("if(!parse_{0}(",name);
			}
			else{
				emit("if(parse_{0}(",name);
			}
						
			foreach(i,arg; args){
				if(i > 0) emit(",");
				visit(arg);
			}
			emitln(")){{");
			
			// closure for cleaner code
			void emitBinding(){
				if(binding){
					if(type != "void"){
                        auto aliased = cast(RuleAlias)target;
                        if(aliased){
                            //NOTE: go straight for the aliased value name to avoid forward decl issues
                            assignResults(binding,aliased.aliasRule);
                        }
                        else{
                            assignResults(binding,name);
                        }
					}
					else{
						assignSlice(binding,posId);
					}
					if(useAST){
						emitln("addASTChild(__astNode,\"{0}\",getASTResult());",binding.name);
					}
				}
				else if(useAST){
					emitln("addASTChild(__astNode,\"{0}\",getASTResult());",name);
				}
			}
								
			// bind and branch
			if(followOnPass){ // false branch
				indent;
					emitGoto(parentFailId);					
				unindent;
				emitln("}");
				emitBinding();
			}
			else{ // true branch
				indent;
					emitBinding();
					emitGoto(parentPassId);	
				unindent;	
				emitln("}");
			}				
		}
	}

	void visit(Group obj,String parentPassId,String parentFailId,bool followOnPass){
		if(!obj.binding){
			visit(obj.expr,parentPassId,parentFailId,followOnPass);
			return;
		}					
		with(obj){
			emitln("// Group (w/binding)");
			indent;
				String posId = savePositionId();
				String passId = getPassId();
				visit(expr,passId,parentFailId,PassFollow);
				emitId(passId);
				assignSlice(binding,posId);
				if(!followOnPass){
					emitGoto(parentPassId);
				}
			unindent;
		}
	}

	void visit(RegularExpression obj,String parentPassId,String parentFailId,bool followOnPass){
		with(obj){
			emitln("// RegularExpression");				
			if(followOnPass){
				emitln("if(!regex(`{0}`)){{",text);
			}
			else{
				emitln("if(regex(`{0}`)){{",text);
			}
								
			// bind and branch
			if(followOnPass){ // false branch
				indent;
					emitGoto(parentFailId);					
				unindent;
				emitln("}");
				if(binding){
					assignResults(binding); //TODO: fix me!
				}
			}
			else{ // true branch
				indent;
					if(binding){
						assignResults(binding); //TODO: fix me!
					}
					emitGoto(parentPassId);
				unindent;
				emitln("}");
			}
		}
	}

	void visit(Iterator obj,String parentPassId,String parentFailId,bool followOnPass){
		String loopStartId;
		String loopEndId;
		String exprId;
		String delimId;
		String counterId;
		String incrementId;
		bool hasCounter;
		uint maxRange;
		uint minRange;
		
		// special case for a single Optional prefix
		// NOTE: delimeter gets thrown out if defined
		if(obj.ranges.length == 1 && obj.ranges[0].hint == Range.OptionalSuffix){
			emitln("// Iterator (optional alias special case)");
			indent;		
				if(obj.term){
					String termId = getId("term");
					emitln("// (expression)");
					visit(obj.expr,termId,termId,PassFollow);
					emitln("// (terminator)");
					emitId(termId);
					visit(obj.term,parentPassId,parentFailId,followOnPass);
				}
				else{
					emitln("// (expression)");
					visit(obj.expr,parentPassId,parentPassId,followOnPass);
					emitGoto(parentPassId);
				}
			unindent;
			return;
		}
		
		with(obj){			
			// loop setup
			loopStartId = getId("start");
			loopEndId = getId("end");
			exprId = getId("expr");
			
			// range is assumed to be unbounded
			hasCounter = false;
						
			// range setup
			if(ranges.length > 0){				
				maxRange = 0;
				minRange = 0;
				foreach(range; ranges){
					if(range.max > maxRange){
						maxRange = range.max;
					}
					if(range.min > minRange){
						minRange = range.min;
					}
				}
				hasCounter = maxRange > 0 || minRange > 0;
			}
			
			// delimeter setup
			if(delim){
				hasCounter = true;
				delimId = getId("delim");
			}
			
			// counter setup
			if(hasCounter){
				counterId = getId("counter");
				incrementId = getId("increment");
			}

			/////////////////////////////////////////////
			emitln("// Iterator");
			if(hasCounter){
				emitln("size_t {0} = 0;",counterId);
			}
			emitId(loopStartId);			
			indent;		
				
				// terminating condition
				emitln("// (terminator)");
				if(term && term.isDeterminate){
					// end the loop with this expression
					indent;
						if(delim){
							visit(term,loopEndId,delimId,FailFollow);
						}
						else{
							visit(term,loopEndId,exprId,FailFollow);
						}
					unindent;
				}
				else if(maxRange > 0){
					// iterate up until the maximum declared range
					emitln("if({0} == {1}){{",counterId,maxRange);
					indent;
						emitGoto(loopEndId);
					unindent;
					emitln("}");
				}
				else{
					// iterate until eoi (greedy match)
					emitln("if(!hasMore()){{");
					indent;
						emitGoto(loopEndId);
					unindent;
					emitln("}");
				}
				
				// delimited expression (if applicable)
				if(delim){
					emitln("// (delimeter)");
					emitId(delimId);
					emitln("if({0} > 0){{",counterId);
					indent;
						if(term && term.isDeterminate){
							//NB: bounded recursion fails on no match
							visit(delim,exprId,parentFailId,PassFollow);
						}
						else{
							//NB: unbounded recursion ends on no match
							visit(delim,exprId,loopEndId,PassFollow);
						}
					unindent;
					emitln("}");
				}
				
				// iterated expression
				emitln("// (expression)");
				emitId(exprId);
				String exprPassId = loopStartId;
				String exprFailId = loopEndId; //NB: unbounded recursion ends on no match
							
				if(hasCounter){
					exprPassId = incrementId;
				}
				if(term && term.isDeterminate){
					exprFailId = parentFailId; //NB: bounded recursion fails on no match
				}
				indent;
					visit(expr,exprPassId,exprFailId,PassFollow);
				unindent;
				
				// increment counter (if applicable)
				if(hasCounter){
					emitId(incrementId);		
					emitln("// (increment expr count)");
					indent;
						emitln("{0} ++;",counterId);
					unindent;
				}		

				// keep looping!
				emitGoto(loopStartId);
			unindent;
			emitId(loopEndId);
			indent; 
				// test ranges (if applicable)
				if(minRange > 0 || maxRange > 0){
					emitln("// (range test)");
					indent;
						if(followOnPass){
							emit("if(!(");
						}
						else{
							emit("if((");
						}
						foreach(i,range; ranges){
							if(i>0) emit(" || ");
							if(range.min == range.max){
								emit("({0} == {1})",counterId,range.min);
							}
							else if(range.min > 0 && range.max > 0){
								emit("({0} >= {1} && {0} <= {2})",counterId,range.min,range.max);
							}
							else if(range.max > 0){
								emit("({0} <= {1})",counterId,range.max);
							}
							else{
								emit("({0} >= {1})",counterId,range.min);
							}
						}
						emitln(")){{");	
						indent;
							if(followOnPass){
								emitGoto(parentFailId);
							}
							else if(term && !term.isDeterminate){		
								visit(term,parentPassId,parentFailId,followOnPass);
							}
							else{
								emitGoto(parentPassId);
							}		
						unindent;
						emitln("}");
					unindent;
				}
				else if(term && !term.isDeterminate){
					visit(term,parentPassId,parentFailId,followOnPass);	
				}		
				else if(!followOnPass){
					emitGoto(parentPassId);	
				}
			unindent;
		}
	}
	
	void visit(Substitution obj,String parentPassId,String parentFailId,bool followOnPass){
		with(obj){
			emitln("// Substitution");
			if(followOnPass){
				emitln("if(!match(var_{0})){{",subBinding.name);
			}
			else{
				emitln("if(match(var_{0})){{",subBinding.name);
			}
								
			// bind and branch
			if(followOnPass){ // false branch
				indent;
					emitGoto(parentFailId);					
				unindent;
				emitln("}");
				if(binding){
					assignVar(binding,subBinding.name);
				}
			}
			else{ // true branch
				indent;
					if(binding){
						assignVar(binding,subBinding.name);
					}
					emitGoto(parentPassId);
				unindent;
				emitln("}");
			}
		}
	}

	void visit(Literal obj,String parentPassId,String parentFailId,bool followOnPass){
		String literalId;
		with(obj){
			emitln("// Literal");
			indent;
				if(binding){
					literalId = getId("literal");
					emit("auto {0} = ",literalId);
				}
				emit("{0}",literalName);
				if(args.length > 0){
					emit("(");
					foreach(i,arg; args){
						if(i > 0) emit(",");
						visit(arg);
					}
					emit(")");
				}
				emitln(";");
				if(binding){
					assign(binding,literalId);
				}
				if(!followOnPass){
					emitGoto(parentPassId);
				}
			unindent;
		}
	}

	void visit(Terminal obj,String parentPassId,String parentFailId,bool followOnPass){
		with(obj){
			emitln("// Terminal");
			if(followOnPass){
				emitln("if(!match(\"{0}\")){{",safeString(text));
			}
			else{
				emitln("if(match(\"{0}\")){{",safeString(text));
			}
								
			// bind and branch
			if(followOnPass){ // false branch
				indent;
					emitGoto(parentFailId);					
				unindent;
				emitln("}");
				if(binding){
					assignResults(binding);
				}
			}
			else{ // true branch
				indent;
					if(binding){
						assignResults(binding);
					}
					emitGoto(parentPassId);
				unindent;
				emitln("}");
			}	
		}
	}

	void visit(Negate obj,String parentPassId,String parentFailId,bool followOnPass){
		String termId = getId("term");
		String failId = getId("fail");
		with(obj){
			emitln("// Negate");
			indent;
				emitln("// (test expr)");
				auto posId = savePositionId();
				visit(expr,failId,termId,PassFollow);
				emitId(failId);
				unwind(posId);
				emitGoto(parentFailId);
				emitId(termId);
				emitln("parse_any();");
				if(binding){
					assignSlice(binding,posId);
				}
				if(!followOnPass){
					emitGoto(parentPassId);
				}
				
			unindent;
		}
	}

	void visit(Test obj,String parentPassId,String parentFailId,bool followOnPass){
		auto failId = getFailId();
		with(obj){
			emitln("// Test");
			auto posId = savePositionId();
			indent;
				visit(expr,failId,parentPassId,PassFollow);
			unindent;
			emitId(failId);
			indent;
				unwind(posId);
				if(!followOnPass){
					emitGoto(parentPassId);
				}
			unindent;
		}
	}

	void visit(ErrorPoint obj,String parentPassId,String parentFailId,bool followOnPass){
		auto failId = getFailId();
		String posId;
		with(obj){
			emitln("// ErrorPoint");
			indent;
				visit(expr,parentPassId,failId,FailFollow);
			unindent;
			emitId(failId);
			indent;
				emit("error(");
				visit(errMessage);
				emitln(");");
				if(followOnPass){
					emitGoto(parentFailId);
				}
			unindent;
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
		emit("var_{0}",obj.name);
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
			emit("var_{0}",decl.name);
		}
	}

	void visit(Param obj,String format){
		with(obj){
			emit(format,type,name);
		}
	}

	void visit(FunctionPredicate obj){
		with(obj){
			emit("{0}(",decl.name);
			foreach(i,param; params){
				if(i > 0) emit(",");
				visit(param);
			}
			emit(")");
		}
	}

	void visit(ClassPredicate obj){
		with(obj){
			emit("new {0}(",type);
			foreach(i,param; params){
				if(i > 0) emit(",");
				visit(param);
			}
			emit(")");
		}
	}

	void visit(DefaultPredicate obj){
		//do nothing
	}

	void visit(Param obj){
		emit("var_{0}",obj.name);
	}
}
