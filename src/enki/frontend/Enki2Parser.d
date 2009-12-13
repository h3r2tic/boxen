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
module enki.frontend.Enki2Parser;
private import enki.frontend.Frontend;
private import enki.frontend.Enki2ParserBase;
private import enki.EnkiToken;
private import enki.Binding;
private import enki.Expression;
private import enki.Param;
private import enki.ProductionArg;
private import enki.Rule;
private import enki.RulePredicate;

debug import tango.io.Stdout;

class Enki2Parser:Enki2ParserBase{
	static char[] getHelp(){
		return "";
	}

	/*
	Syntax
		::= (Prototype | Alias | Rule | Directive | Attribute)* eoi;

	*/
	bool value_Syntax;
	bool parse_Syntax(){
		debug Stdout("parse_Syntax").newline;
		// Iterator
		start2:
			// (terminator)
				// Production
				if(parse_eoi()){
					goto end3;
				}
			// (expression)
			expr4:
				// OrGroup start2
					// Production
					if(parse_Prototype()){
						goto start2;
					}
				term5:
					// Production
					if(parse_Alias()){
						goto start2;
					}
				term6:
					// Production
					if(parse_Rule()){
						goto start2;
					}
				term7:
					// Production
					if(parse_Directive()){
						goto start2;
					}
				term8:
					// Production
					if(!parse_Attribute()){
						goto fail1;
					}
			goto start2;
		end3:
		// Rule
		pass0:
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_Syntax failed").newline;
			return false;
	}

	/*
	Prototype
		= void addPrototype(String name,String returnType)
		::= Identifier:name "=" Identifier:returnType ";";

	*/
	bool value_Prototype;
	bool parse_Prototype(){
		debug Stdout("parse_Prototype").newline;
		String var_name;
		String var_returnType;

		// AndGroup
			auto position3 = pos;
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAssign(var_name,value_Identifier);
			term5:
				// Terminal
				if(!match("=")){
					goto fail4;
				}
			term6:
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAssign(var_returnType,value_Identifier);
			term7:
				// Terminal
				if(match(";")){
					goto pass0;
				}
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			addPrototype(var_name,var_returnType);
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_Prototype failed").newline;
			return false;
	}

	/*
	Alias
		= void addAlias(String aliasName,String ruleName)
		::= Identifier:aliasName &TOK_RULEASSIGN Identifier:ruleName ";";

	*/
	bool value_Alias;
	bool parse_Alias(){
		debug Stdout("parse_Alias").newline;
		String var_ruleName;
		String var_aliasName;

		// AndGroup
			auto position3 = pos;
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAssign(var_aliasName,value_Identifier);
			term5:
				// CustomTerminal
				if(!match(TOK_RULEASSIGN)){
					goto fail4;
				}
			term6:
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAssign(var_ruleName,value_Identifier);
			term7:
				// Terminal
				if(match(";")){
					goto pass0;
				}
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			addAlias(var_aliasName,var_ruleName);
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_Alias failed").newline;
			return false;
	}

	/*
	Rule
		= void addRule(String name,Param[] decl,RulePredicate pred,Param[] vars,Expression expr)
		$String err1="Missing \';\'"
		$String err2="Expected \'::=\'"
		::= Identifier:name [RuleDecl:decl] [RulePredicate:pred] ?!(err2) RuleVar:~vars* &TOK_RULEASSIGN Expression:~expr ?!(err1) ";";

	*/
	bool value_Rule;
	bool parse_Rule(){
		debug Stdout("parse_Rule").newline;
		String var_err2 = "Expected \'::=\'";
		String var_name;
		Expression var_expr;
		RulePredicate var_pred;
		Param[] var_vars;
		Param[] var_decl;
		String var_err1 = "Missing \';\'";

		// AndGroup
			auto position3 = pos;
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAssign(var_name,value_Identifier);
			term5:
				// Optional
					// Production
					if(!parse_RuleDecl()){
						goto term6;
					}
					smartAssign(var_decl,value_RuleDecl);
			term6:
				// Optional
					// Production
					if(!parse_RulePredicate()){
						goto term7;
					}
					smartAssign(var_pred,value_RulePredicate);
			term7:
				// ErrorPoint
					// Iterator
					start10:
						// (terminator)
							// CustomTerminal
							if(match(TOK_RULEASSIGN)){
								goto end11;
							}
						// (expression)
						expr12:
							// Production
							if(!parse_RuleVar()){
								goto fail9;
							}
							smartAppend(var_vars,value_RuleVar);
						goto start10;
					end11:
						goto term8;
				fail9:
					error(var_err2);
					goto fail4;
			term8:
				// Production
				if(!parse_Expression()){
					goto fail4;
				}
				smartAppend(var_expr,value_OrGroup);
			term13:
				// ErrorPoint
					// Terminal
					if(match(";")){
						goto pass0;
					}
				fail14:
					error(var_err1);
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			addRule(var_name,var_decl,var_pred,var_vars,var_expr);
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_Rule failed").newline;
			return false;
	}

	/*
	RuleDecl
		= Param[] params
		::= ParamsExpr:params;

	*/
	Param[] value_RuleDecl;
	bool parse_RuleDecl(){
		debug Stdout("parse_RuleDecl").newline;
		Param[] var_params;

		// Production
		if(!parse_ParamsExpr()){
			goto fail1;
		}
		smartAssign(var_params,value_ParamsExpr);
		// Rule
		pass0:
			value_RuleDecl = var_params;
			debug Stdout.format("\tparse_RuleDecl passed: {0}",value_RuleDecl).newline;
			return true;
		fail1:
			value_RuleDecl = (Param[]).init;
			debug Stdout.format("\tparse_RuleDecl failed").newline;
			return false;
	}

	/*
	RulePredicate
		= RulePredicate pred
		::= "=" (ClassPredicate:pred | FunctionPredicate:pred | BindingPredicate:pred | @err!("Expected Rule Predicate."));

	*/
	RulePredicate value_RulePredicate;
	bool parse_RulePredicate(){
		debug Stdout("parse_RulePredicate").newline;
		RulePredicate var_pred;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("=")){
					goto fail4;
				}
			term5:
				// OrGroup pass0
					// Production
					if(parse_ClassPredicate()){
						smartAssign(var_pred,value_ClassPredicate);
						goto pass0;
					}
				term6:
					// Production
					if(parse_FunctionPredicate()){
						smartAssign(var_pred,value_FunctionPredicate);
						goto pass0;
					}
				term7:
					// Production
					if(parse_BindingPredicate()){
						smartAssign(var_pred,value_BindingPredicate);
						goto pass0;
					}
				term8:
					// Literal
						err("Expected Rule Predicate.");
						goto pass0;
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_RulePredicate = var_pred;
			debug Stdout.format("\tparse_RulePredicate passed: {0}",value_RulePredicate).newline;
			return true;
		fail1:
			value_RulePredicate = (RulePredicate).init;
			debug Stdout.format("\tparse_RulePredicate failed").newline;
			return false;
	}

	/*
	ClassPredicate
		= new ClassPredicate(String name,Param[] params)
		::= &TOK_NEW Identifier:name ParamsExpr:params;

	*/
	ClassPredicate value_ClassPredicate;
	bool parse_ClassPredicate(){
		debug Stdout("parse_ClassPredicate").newline;
		String var_name;
		Param[] var_params;

		// AndGroup
			auto position3 = pos;
				// CustomTerminal
				if(!match(TOK_NEW)){
					goto fail4;
				}
			term5:
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAssign(var_name,value_Identifier);
			term6:
				// Production
				if(parse_ParamsExpr()){
					smartAssign(var_params,value_ParamsExpr);
					goto pass0;
				}
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_ClassPredicate = new ClassPredicate(var_name,var_params);
			debug Stdout.format("\tparse_ClassPredicate passed: {0}",value_ClassPredicate).newline;
			return true;
		fail1:
			value_ClassPredicate = (ClassPredicate).init;
			debug Stdout.format("\tparse_ClassPredicate failed").newline;
			return false;
	}

	/*
	FunctionPredicate
		= new FunctionPredicate(Param decl,Param[] params)
		::= ExplicitParam:decl ParamsExpr:params;

	*/
	FunctionPredicate value_FunctionPredicate;
	bool parse_FunctionPredicate(){
		debug Stdout("parse_FunctionPredicate").newline;
		Param[] var_params;
		Param var_decl;

		// AndGroup
			auto position3 = pos;
				// Production
				if(!parse_ExplicitParam()){
					goto fail4;
				}
				smartAssign(var_decl,value_ExplicitParam);
			term5:
				// Production
				if(parse_ParamsExpr()){
					smartAssign(var_params,value_ParamsExpr);
					goto pass0;
				}
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_FunctionPredicate = new FunctionPredicate(var_decl,var_params);
			debug Stdout.format("\tparse_FunctionPredicate passed: {0}",value_FunctionPredicate).newline;
			return true;
		fail1:
			value_FunctionPredicate = (FunctionPredicate).init;
			debug Stdout.format("\tparse_FunctionPredicate failed").newline;
			return false;
	}

	/*
	BindingPredicate
		= new BindingPredicate(Param param)
		::= Param:param;

	*/
	BindingPredicate value_BindingPredicate;
	bool parse_BindingPredicate(){
		debug Stdout("parse_BindingPredicate").newline;
		Param var_param;

		// Production
		if(!parse_Param()){
			goto fail1;
		}
		smartAssign(var_param,value_Param);
		// Rule
		pass0:
			value_BindingPredicate = new BindingPredicate(var_param);
			debug Stdout.format("\tparse_BindingPredicate passed: {0}",value_BindingPredicate).newline;
			return true;
		fail1:
			value_BindingPredicate = (BindingPredicate).init;
			debug Stdout.format("\tparse_BindingPredicate failed").newline;
			return false;
	}

	/*
	RuleVar
		= Param var
		::= "$" Param:var;

	*/
	Param value_RuleVar;
	bool parse_RuleVar(){
		debug Stdout("parse_RuleVar").newline;
		Param var_var;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("$")){
					goto fail4;
				}
			term5:
				// Production
				if(parse_Param()){
					smartAssign(var_var,value_Param);
					goto pass0;
				}
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_RuleVar = var_var;
			debug Stdout.format("\tparse_RuleVar passed: {0}",value_RuleVar).newline;
			return true;
		fail1:
			value_RuleVar = (Param).init;
			debug Stdout.format("\tparse_RuleVar failed").newline;
			return false;
	}

	/*
	ParamsExpr
		= Param[] params
		::= "(" Param:~params* % "," ")";

	*/
	Param[] value_ParamsExpr;
	bool parse_ParamsExpr(){
		debug Stdout("parse_ParamsExpr").newline;
		Param[] var_params;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("(")){
					goto fail4;
				}
			term5:
				// Iterator
				size_t counter10 = 0;
				start6:
					// (terminator)
						// Terminal
						if(match(")")){
							goto end7;
						}
					// (delimeter)
					delim9:
					if(counter10 > 0){
						// Terminal
						if(!match(",")){
							goto fail4;
						}
					}
					// (expression)
					expr8:
						// Production
						if(!parse_Param()){
							goto fail4;
						}
						smartAppend(var_params,value_Param);
					increment11:
					// (increment expr count)
						counter10 ++;
					goto start6;
				end7:
					goto pass0;
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_ParamsExpr = var_params;
			debug Stdout.format("\tparse_ParamsExpr passed: {0}",value_ParamsExpr).newline;
			return true;
		fail1:
			value_ParamsExpr = (Param[]).init;
			debug Stdout.format("\tparse_ParamsExpr failed").newline;
			return false;
	}

	/*
	Param
		= Param param
		::= ExplicitParam:param | WeakParam:param;

	*/
	Param value_Param;
	bool parse_Param(){
		debug Stdout("parse_Param").newline;
		Param var_param;

		// OrGroup pass0
			// Production
			if(parse_ExplicitParam()){
				smartAssign(var_param,value_ExplicitParam);
				goto pass0;
			}
		term2:
			// Production
			if(!parse_WeakParam()){
				goto fail1;
			}
			smartAssign(var_param,value_WeakParam);
		// Rule
		pass0:
			value_Param = var_param;
			debug Stdout.format("\tparse_Param passed: {0}",value_Param).newline;
			return true;
		fail1:
			value_Param = (Param).init;
			debug Stdout.format("\tparse_Param failed").newline;
			return false;
	}

	/*
	WeakParam
		= new Param(String type,String name,String value)
		::= Identifier:name ["=" &TOK_STRING:value];

	*/
	Param value_WeakParam;
	bool parse_WeakParam(){
		debug Stdout("parse_WeakParam").newline;
		String var_value;
		String var_name;
		String var_type;

		// AndGroup
			auto position3 = pos;
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAssign(var_name,value_Identifier);
			term5:
				// Optional
					// AndGroup
						auto position7 = pos;
							// Terminal
							if(!match("=")){
								goto fail8;
							}
						term9:
							// CustomTerminal
							if(match(TOK_STRING)){
								smartAssign(var_value,__match);
								goto pass0;
							}
						fail8:
						pos = position7;
					goto pass0;
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_WeakParam = new Param(var_type,var_name,var_value);
			debug Stdout.format("\tparse_WeakParam passed: {0}",value_WeakParam).newline;
			return true;
		fail1:
			value_WeakParam = (Param).init;
			debug Stdout.format("\tparse_WeakParam failed").newline;
			return false;
	}

	/*
	ExplicitParam
		= new Param(String type,String name,String value)
		::= ParamType:type Identifier:name ["=" &TOK_STRING:value];

	*/
	Param value_ExplicitParam;
	bool parse_ExplicitParam(){
		debug Stdout("parse_ExplicitParam").newline;
		String var_value;
		String var_name;
		String var_type;

		// AndGroup
			auto position3 = pos;
				// Production
				auto position6 = pos;
				if(!parse_ParamType()){
					goto fail4;
				}
				smartAssign(var_type,slice(position6,pos));
			term5:
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAssign(var_name,value_Identifier);
			term7:
				// Optional
					// AndGroup
						auto position9 = pos;
							// Terminal
							if(!match("=")){
								goto fail10;
							}
						term11:
							// CustomTerminal
							if(match(TOK_STRING)){
								smartAssign(var_value,__match);
								goto pass0;
							}
						fail10:
						pos = position9;
					goto pass0;
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_ExplicitParam = new Param(var_type,var_name,var_value);
			debug Stdout.format("\tparse_ExplicitParam passed: {0}",value_ExplicitParam).newline;
			return true;
		fail1:
			value_ExplicitParam = (Param).init;
			debug Stdout.format("\tparse_ExplicitParam failed").newline;
			return false;
	}

	/*
	ParamType
		::= Identifier ["[" [ParamType] "]"];

	*/
	bool value_ParamType;
	bool parse_ParamType(){
		debug Stdout("parse_ParamType").newline;
		// AndGroup
			auto position3 = pos;
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
			term5:
				// Optional
					// AndGroup
						auto position7 = pos;
							// Terminal
							if(!match("[")){
								goto fail8;
							}
						term9:
							// Optional
								// Production
								if(!parse_ParamType()){
									goto term10;
								}
						term10:
							// Terminal
							if(match("]")){
								goto pass0;
							}
						fail8:
						pos = position7;
					goto pass0;
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_ParamType failed").newline;
			return false;
	}
	alias parse_OrGroup parse_Expression;

	/*
	OrGroup
		= new OrGroup(Expression[] exprs)
		::= {AndGroup:~exprs} % "|";

	*/
	OrGroup value_OrGroup;
	bool parse_OrGroup(){
		debug Stdout("parse_OrGroup").newline;
		Expression[] var_exprs;

		// Iterator
		size_t counter6 = 0;
		start2:
			// (terminator)
			if(!hasMore()){
				goto end3;
			}
			// (delimeter)
			delim5:
			if(counter6 > 0){
				// Terminal
				if(!match("|")){
					goto end3;
				}
			}
			// (expression)
			expr4:
				// Production
				if(!parse_AndGroup()){
					goto end3;
				}
				smartAppend(var_exprs,value_AndGroup);
			increment7:
			// (increment expr count)
				counter6 ++;
			goto start2;
		end3:
			// (range test)
				if(!((counter6 >= 1))){
					goto fail1;
				}
		// Rule
		pass0:
			value_OrGroup = new OrGroup(var_exprs);
			debug Stdout.format("\tparse_OrGroup passed: {0}",value_OrGroup).newline;
			return true;
		fail1:
			value_OrGroup = (OrGroup).init;
			debug Stdout.format("\tparse_OrGroup failed").newline;
			return false;
	}

	/*
	AndGroup
		= new AndGroup(Expression[] exprs)
		::= {SubExpression:~exprs};

	*/
	AndGroup value_AndGroup;
	bool parse_AndGroup(){
		debug Stdout("parse_AndGroup").newline;
		Expression[] var_exprs;

		// Iterator
		size_t counter5 = 0;
		start2:
			// (terminator)
			if(!hasMore()){
				goto end3;
			}
			// (expression)
			expr4:
				// Production
				if(!parse_SubExpression()){
					goto end3;
				}
				smartAppend(var_exprs,value_SubExpression);
			increment6:
			// (increment expr count)
				counter5 ++;
			goto start2;
		end3:
			// (range test)
				if(!((counter5 >= 1))){
					goto fail1;
				}
		// Rule
		pass0:
			value_AndGroup = new AndGroup(var_exprs);
			debug Stdout.format("\tparse_AndGroup passed: {0}",value_AndGroup).newline;
			return true;
		fail1:
			value_AndGroup = (AndGroup).init;
			debug Stdout.format("\tparse_AndGroup failed").newline;
			return false;
	}

	/*
	SubExpression
		= Expression expr
		::= (Production:expr | Substitution:expr | Terminal:expr | CharacterRange:expr | Regexp:expr | GroupExpr:expr | OneOrMoreExpr:expr | OptionalExpr:expr | NegateExpr:expr | TestExpr:expr | LiteralExpr:expr | CustomTerminal:expr | ErrorPoint:expr) [IteratorExpr!(expr):expr];

	*/
	Expression value_SubExpression;
	bool parse_SubExpression(){
		debug Stdout("parse_SubExpression").newline;
		Expression var_expr;

		// AndGroup
			auto position3 = pos;
				// OrGroup term5
					// Production
					if(parse_Production()){
						smartAssign(var_expr,value_Production);
						goto term5;
					}
				term6:
					// Production
					if(parse_Substitution()){
						smartAssign(var_expr,value_Substitution);
						goto term5;
					}
				term7:
					// Production
					if(parse_Terminal()){
						smartAssign(var_expr,value_Terminal);
						goto term5;
					}
				term8:
					// Production
					if(parse_CharacterRange()){
						smartAssign(var_expr,value_CharacterRange);
						goto term5;
					}
				term9:
					// Production
					if(parse_Regexp()){
						smartAssign(var_expr,value_Regexp);
						goto term5;
					}
				term10:
					// Production
					if(parse_GroupExpr()){
						smartAssign(var_expr,value_GroupExpr);
						goto term5;
					}
				term11:
					// Production
					if(parse_OneOrMoreExpr()){
						smartAssign(var_expr,value_OneOrMoreExpr);
						goto term5;
					}
				term12:
					// Production
					if(parse_OptionalExpr()){
						smartAssign(var_expr,value_OptionalExpr);
						goto term5;
					}
				term13:
					// Production
					if(parse_NegateExpr()){
						smartAssign(var_expr,value_NegateExpr);
						goto term5;
					}
				term14:
					// Production
					if(parse_TestExpr()){
						smartAssign(var_expr,value_TestExpr);
						goto term5;
					}
				term15:
					// Production
					if(parse_LiteralExpr()){
						smartAssign(var_expr,value_LiteralExpr);
						goto term5;
					}
				term16:
					// Production
					if(parse_CustomTerminal()){
						smartAssign(var_expr,value_CustomTerminal);
						goto term5;
					}
				term17:
					// Production
					if(!parse_ErrorPoint()){
						goto fail4;
					}
					smartAssign(var_expr,value_ErrorPoint);
			term5:
				// Optional
					// Production
					if(parse_IteratorExpr(var_expr)){
						smartAssign(var_expr,value_IteratorExpr);
						goto pass0;
					}
					goto pass0;
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_SubExpression = var_expr;
			debug Stdout.format("\tparse_SubExpression passed: {0}",value_SubExpression).newline;
			return true;
		fail1:
			value_SubExpression = (Expression).init;
			debug Stdout.format("\tparse_SubExpression failed").newline;
			return false;
	}

	/*
	Production
		= new Production(String name,Binding binding,ProductionArg[] args)
		::= Identifier:name ["!" "(" ProductionArg:~args* % "," ")"] [Binding:binding];

	*/
	Production value_Production;
	bool parse_Production(){
		debug Stdout("parse_Production").newline;
		String var_name;
		Binding var_binding;
		ProductionArg[] var_args;

		// AndGroup
			auto position3 = pos;
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAssign(var_name,value_Identifier);
			term5:
				// Optional
					// AndGroup
						auto position8 = pos;
							// Terminal
							if(!match("!")){
								goto fail9;
							}
						term10:
							// Terminal
							if(!match("(")){
								goto fail9;
							}
						term11:
							// Iterator
							size_t counter16 = 0;
							start12:
								// (terminator)
									// Terminal
									if(match(")")){
										goto end13;
									}
								// (delimeter)
								delim15:
								if(counter16 > 0){
									// Terminal
									if(!match(",")){
										goto fail9;
									}
								}
								// (expression)
								expr14:
									// Production
									if(!parse_ProductionArg()){
										goto fail9;
									}
									smartAppend(var_args,value_ProductionArg);
								increment17:
								// (increment expr count)
									counter16 ++;
								goto start12;
							end13:
								goto term6;
						fail9:
						pos = position8;
						goto term6;
			term6:
				// Optional
					// Production
					if(parse_Binding()){
						smartAssign(var_binding,value_Binding);
						goto pass0;
					}
					goto pass0;
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_Production = new Production(var_name,var_binding,var_args);
			debug Stdout.format("\tparse_Production passed: {0}",value_Production).newline;
			return true;
		fail1:
			value_Production = (Production).init;
			debug Stdout.format("\tparse_Production failed").newline;
			return false;
	}

	/*
	ProductionArg
		= ProductionArg arg
		::= StringProductionArg:arg | BindingProductionArg:arg;

	*/
	ProductionArg value_ProductionArg;
	bool parse_ProductionArg(){
		debug Stdout("parse_ProductionArg").newline;
		ProductionArg var_arg;

		// OrGroup pass0
			// Production
			if(parse_StringProductionArg()){
				smartAssign(var_arg,value_StringProductionArg);
				goto pass0;
			}
		term2:
			// Production
			if(!parse_BindingProductionArg()){
				goto fail1;
			}
			smartAssign(var_arg,value_BindingProductionArg);
		// Rule
		pass0:
			value_ProductionArg = var_arg;
			debug Stdout.format("\tparse_ProductionArg passed: {0}",value_ProductionArg).newline;
			return true;
		fail1:
			value_ProductionArg = (ProductionArg).init;
			debug Stdout.format("\tparse_ProductionArg failed").newline;
			return false;
	}

	/*
	StringProductionArg
		= new StringProductionArg(String value)
		::= &TOK_STRING:value;

	*/
	StringProductionArg value_StringProductionArg;
	bool parse_StringProductionArg(){
		debug Stdout("parse_StringProductionArg").newline;
		String var_value;

		// CustomTerminal
		if(!match(TOK_STRING)){
			goto fail1;
		}
		smartAssign(var_value,__match);
		// Rule
		pass0:
			value_StringProductionArg = new StringProductionArg(var_value);
			debug Stdout.format("\tparse_StringProductionArg passed: {0}",value_StringProductionArg).newline;
			return true;
		fail1:
			value_StringProductionArg = (StringProductionArg).init;
			debug Stdout.format("\tparse_StringProductionArg failed").newline;
			return false;
	}

	/*
	BindingProductionArg
		= new BindingProductionArg(String value)
		::= Identifier:value;

	*/
	BindingProductionArg value_BindingProductionArg;
	bool parse_BindingProductionArg(){
		debug Stdout("parse_BindingProductionArg").newline;
		String var_value;

		// Production
		if(!parse_Identifier()){
			goto fail1;
		}
		smartAssign(var_value,value_Identifier);
		// Rule
		pass0:
			value_BindingProductionArg = new BindingProductionArg(var_value);
			debug Stdout.format("\tparse_BindingProductionArg passed: {0}",value_BindingProductionArg).newline;
			return true;
		fail1:
			value_BindingProductionArg = (BindingProductionArg).init;
			debug Stdout.format("\tparse_BindingProductionArg failed").newline;
			return false;
	}

	/*
	Substitution
		= new Substitution(String name,Binding binding)
		::= "." Identifier:~name [Binding:binding];

	*/
	Substitution value_Substitution;
	bool parse_Substitution(){
		debug Stdout("parse_Substitution").newline;
		String var_name;
		Binding var_binding;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match(".")){
					goto fail4;
				}
			term5:
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAppend(var_name,value_Identifier);
			term6:
				// Optional
					// Production
					if(parse_Binding()){
						smartAssign(var_binding,value_Binding);
						goto pass0;
					}
					goto pass0;
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_Substitution = new Substitution(var_name,var_binding);
			debug Stdout.format("\tparse_Substitution passed: {0}",value_Substitution).newline;
			return true;
		fail1:
			value_Substitution = (Substitution).init;
			debug Stdout.format("\tparse_Substitution failed").newline;
			return false;
	}

	/*
	GroupExpr
		= new Group(Expression expr,Binding binding)
		::= "(" Expression:expr ")" [Binding:binding];

	*/
	Group value_GroupExpr;
	bool parse_GroupExpr(){
		debug Stdout("parse_GroupExpr").newline;
		Expression var_expr;
		Binding var_binding;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("(")){
					goto fail4;
				}
			term5:
				// Production
				if(!parse_Expression()){
					goto fail4;
				}
				smartAssign(var_expr,value_OrGroup);
			term6:
				// Terminal
				if(!match(")")){
					goto fail4;
				}
			term7:
				// Optional
					// Production
					if(parse_Binding()){
						smartAssign(var_binding,value_Binding);
						goto pass0;
					}
					goto pass0;
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_GroupExpr = new Group(var_expr,var_binding);
			debug Stdout.format("\tparse_GroupExpr passed: {0}",value_GroupExpr).newline;
			return true;
		fail1:
			value_GroupExpr = (Group).init;
			debug Stdout.format("\tparse_GroupExpr failed").newline;
			return false;
	}

	/*
	OneOrMoreExpr
		= new OneOrMoreExpr(Expression expr,Binding binding)
		::= "{" Expression:expr "}" [Binding:binding];

	*/
	OneOrMoreExpr value_OneOrMoreExpr;
	bool parse_OneOrMoreExpr(){
		debug Stdout("parse_OneOrMoreExpr").newline;
		Expression var_expr;
		Binding var_binding;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("{")){
					goto fail4;
				}
			term5:
				// Production
				if(!parse_Expression()){
					goto fail4;
				}
				smartAssign(var_expr,value_OrGroup);
			term6:
				// Terminal
				if(!match("}")){
					goto fail4;
				}
			term7:
				// Optional
					// Production
					if(parse_Binding()){
						smartAssign(var_binding,value_Binding);
						goto pass0;
					}
					goto pass0;
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_OneOrMoreExpr = new OneOrMoreExpr(var_expr,var_binding);
			debug Stdout.format("\tparse_OneOrMoreExpr passed: {0}",value_OneOrMoreExpr).newline;
			return true;
		fail1:
			value_OneOrMoreExpr = (OneOrMoreExpr).init;
			debug Stdout.format("\tparse_OneOrMoreExpr failed").newline;
			return false;
	}

	/*
	IteratorExpr(Expression expr)
		= Expression Iterator.create(Expression expr,Expression delim,Expression term,Range[] ranges)
		::= (RangeSetExpr:ranges ["%" SubExpression:delim] | "%" SubExpression:delim) [SubExpression:term];

	*/
	Expression value_IteratorExpr;
	bool parse_IteratorExpr(Expression var_expr){
		debug Stdout("parse_IteratorExpr").newline;
		Expression var_delim;
		Range[] var_ranges;
		Expression var_term;

		// AndGroup
			auto position3 = pos;
				// OrGroup term5
					// AndGroup
						auto position8 = pos;
							// Production
							if(!parse_RangeSetExpr()){
								goto fail9;
							}
							smartAssign(var_ranges,value_RangeSetExpr);
						term10:
							// Optional
								// AndGroup
									auto position12 = pos;
										// Terminal
										if(!match("%")){
											goto fail13;
										}
									term14:
										// Production
										if(parse_SubExpression()){
											smartAssign(var_delim,value_SubExpression);
											goto term5;
										}
									fail13:
									pos = position12;
								goto term5;
						fail9:
						pos = position8;
				term6:
					// AndGroup
						auto position16 = pos;
							// Terminal
							if(!match("%")){
								goto fail17;
							}
						term18:
							// Production
							if(parse_SubExpression()){
								smartAssign(var_delim,value_SubExpression);
								goto term5;
							}
						fail17:
						pos = position16;
						goto fail4;
			term5:
				// Optional
					// Production
					if(parse_SubExpression()){
						smartAssign(var_term,value_SubExpression);
						goto pass0;
					}
					goto pass0;
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_IteratorExpr = Iterator.create(var_expr,var_delim,var_term,var_ranges);
			debug Stdout.format("\tparse_IteratorExpr passed: {0}",value_IteratorExpr).newline;
			return true;
		fail1:
			value_IteratorExpr = (Expression).init;
			debug Stdout.format("\tparse_IteratorExpr failed").newline;
			return false;
	}

	/*
	RangeSetExpr
		= Range[] ranges
		::= ZeroOrMoreRange:~ranges | OneOrMoreRange:~ranges | OptionalRange:~ranges | "<" {IteratorRangeExpr:~ranges} % "," ">";

	*/
	Range[] value_RangeSetExpr;
	bool parse_RangeSetExpr(){
		debug Stdout("parse_RangeSetExpr").newline;
		Range[] var_ranges;

		// OrGroup pass0
			// Production
			if(parse_ZeroOrMoreRange()){
				smartAppend(var_ranges,value_ZeroOrMoreRange);
				goto pass0;
			}
		term2:
			// Production
			if(parse_OneOrMoreRange()){
				smartAppend(var_ranges,value_OneOrMoreRange);
				goto pass0;
			}
		term3:
			// Production
			if(parse_OptionalRange()){
				smartAppend(var_ranges,value_OptionalRange);
				goto pass0;
			}
		term4:
			// AndGroup
				auto position6 = pos;
					// Terminal
					if(!match("<")){
						goto fail7;
					}
				term8:
					// Iterator
					size_t counter13 = 0;
					start9:
						// (terminator)
							// Terminal
							if(match(">")){
								goto end10;
							}
						// (delimeter)
						delim12:
						if(counter13 > 0){
							// Terminal
							if(!match(",")){
								goto fail7;
							}
						}
						// (expression)
						expr11:
							// Production
							if(!parse_IteratorRangeExpr()){
								goto fail7;
							}
							smartAppend(var_ranges,value_IteratorRangeExpr);
						increment14:
						// (increment expr count)
							counter13 ++;
						goto start9;
					end10:
						// (range test)
							if(((counter13 >= 1))){
								goto pass0;
							}
				fail7:
				pos = position6;
				goto fail1;
		// Rule
		pass0:
			value_RangeSetExpr = var_ranges;
			debug Stdout.format("\tparse_RangeSetExpr passed: {0}",value_RangeSetExpr).newline;
			return true;
		fail1:
			value_RangeSetExpr = (Range[]).init;
			debug Stdout.format("\tparse_RangeSetExpr failed").newline;
			return false;
	}

	/*
	ZeroOrMoreRange
		= Range Range.ZeroOrMore()
		::= "*";

	*/
	Range value_ZeroOrMoreRange;
	bool parse_ZeroOrMoreRange(){
		debug Stdout("parse_ZeroOrMoreRange").newline;
		// Terminal
		if(!match("*")){
			goto fail1;
		}
		// Rule
		pass0:
			value_ZeroOrMoreRange = Range.ZeroOrMore();
			debug Stdout.format("\tparse_ZeroOrMoreRange passed: {0}",value_ZeroOrMoreRange).newline;
			return true;
		fail1:
			value_ZeroOrMoreRange = (Range).init;
			debug Stdout.format("\tparse_ZeroOrMoreRange failed").newline;
			return false;
	}

	/*
	OneOrMoreRange
		= Range Range.OneOrMore()
		::= "+";

	*/
	Range value_OneOrMoreRange;
	bool parse_OneOrMoreRange(){
		debug Stdout("parse_OneOrMoreRange").newline;
		// Terminal
		if(!match("+")){
			goto fail1;
		}
		// Rule
		pass0:
			value_OneOrMoreRange = Range.OneOrMore();
			debug Stdout.format("\tparse_OneOrMoreRange passed: {0}",value_OneOrMoreRange).newline;
			return true;
		fail1:
			value_OneOrMoreRange = (Range).init;
			debug Stdout.format("\tparse_OneOrMoreRange failed").newline;
			return false;
	}

	/*
	OptionalRange
		= Range Range.Optional()
		::= "?";

	*/
	Range value_OptionalRange;
	bool parse_OptionalRange(){
		debug Stdout("parse_OptionalRange").newline;
		// Terminal
		if(!match("?")){
			goto fail1;
		}
		// Rule
		pass0:
			value_OptionalRange = Range.Optional();
			debug Stdout.format("\tparse_OptionalRange passed: {0}",value_OptionalRange).newline;
			return true;
		fail1:
			value_OptionalRange = (Range).init;
			debug Stdout.format("\tparse_OptionalRange failed").newline;
			return false;
	}

	/*
	IteratorRangeExpr
		= Range Range(int start,int end)
		::= &TOK_RANGE &TOK_NUMBER:end | /&TOK_NUMBER:start &TOK_NUMBER:end [&TOK_RANGE &TOK_NUMBER:end];

	*/
	Range value_IteratorRangeExpr;
	bool parse_IteratorRangeExpr(){
		debug Stdout("parse_IteratorRangeExpr").newline;
		int var_start;
		int var_end;

		// OrGroup pass0
			// AndGroup
				auto position4 = pos;
					// CustomTerminal
					if(!match(TOK_RANGE)){
						goto fail5;
					}
				term6:
					// CustomTerminal
					if(match(TOK_NUMBER)){
						smartAssign(var_end,__match);
						goto pass0;
					}
				fail5:
				pos = position4;
		term2:
			// AndGroup
				auto position8 = pos;
					// Test
					auto position12 = pos;
						// CustomTerminal
						if(!match(TOK_NUMBER)){
							goto term10;
						}
						smartAssign(var_start,__match);
					fail11:
						pos = position12;
				term10:
					// CustomTerminal
					if(!match(TOK_NUMBER)){
						goto fail9;
					}
					smartAssign(var_end,__match);
				term13:
					// Optional
						// AndGroup
							auto position15 = pos;
								// CustomTerminal
								if(!match(TOK_RANGE)){
									goto fail16;
								}
							term17:
								// CustomTerminal
								if(match(TOK_NUMBER)){
									smartAssign(var_end,__match);
									goto pass0;
								}
							fail16:
							pos = position15;
						goto pass0;
				fail9:
				pos = position8;
				goto fail1;
		// Rule
		pass0:
			value_IteratorRangeExpr = Range(var_start,var_end);
			debug Stdout.format("\tparse_IteratorRangeExpr passed: {0}",value_IteratorRangeExpr).newline;
			return true;
		fail1:
			value_IteratorRangeExpr = (Range).init;
			debug Stdout.format("\tparse_IteratorRangeExpr failed").newline;
			return false;
	}

	/*
	OptionalExpr
		= new Optional(Expression expr,Binding binding)
		$String err1="Expected Expression"
		$String err2="Expected Closing \']\'"
		::= "[" ?!(err1) Expression:expr ?!(err2) "]" [Binding:binding];

	*/
	Optional value_OptionalExpr;
	bool parse_OptionalExpr(){
		debug Stdout("parse_OptionalExpr").newline;
		String var_err2 = "Expected Closing \']\'";
		Expression var_expr;
		Binding var_binding;
		String var_err1 = "Expected Expression";

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("[")){
					goto fail4;
				}
			term5:
				// ErrorPoint
					// Production
					if(parse_Expression()){
						smartAssign(var_expr,value_OrGroup);
						goto term6;
					}
				fail7:
					error(var_err1);
					goto fail4;
			term6:
				// ErrorPoint
					// Terminal
					if(match("]")){
						goto term8;
					}
				fail9:
					error(var_err2);
					goto fail4;
			term8:
				// Optional
					// Production
					if(parse_Binding()){
						smartAssign(var_binding,value_Binding);
						goto pass0;
					}
					goto pass0;
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_OptionalExpr = new Optional(var_expr,var_binding);
			debug Stdout.format("\tparse_OptionalExpr passed: {0}",value_OptionalExpr).newline;
			return true;
		fail1:
			value_OptionalExpr = (Optional).init;
			debug Stdout.format("\tparse_OptionalExpr failed").newline;
			return false;
	}

	/*
	Terminal
		= new Terminal(String text,Binding binding)
		::= &TOK_STRING:text [Binding:binding];

	*/
	Terminal value_Terminal;
	bool parse_Terminal(){
		debug Stdout("parse_Terminal").newline;
		Binding var_binding;
		String var_text;

		// AndGroup
			auto position3 = pos;
				// CustomTerminal
				if(!match(TOK_STRING)){
					goto fail4;
				}
				smartAssign(var_text,__match);
			term5:
				// Optional
					// Production
					if(parse_Binding()){
						smartAssign(var_binding,value_Binding);
						goto pass0;
					}
					goto pass0;
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_Terminal = new Terminal(var_text,var_binding);
			debug Stdout.format("\tparse_Terminal passed: {0}",value_Terminal).newline;
			return true;
		fail1:
			value_Terminal = (Terminal).init;
			debug Stdout.format("\tparse_Terminal failed").newline;
			return false;
	}

	/*
	CharacterRange
		= new CharRange(String start,String end,Binding binding)
		::= /&TOK_HEX:end &TOK_HEX:start ["-" &TOK_HEX:end] [Binding:binding];

	*/
	CharRange value_CharacterRange;
	bool parse_CharacterRange(){
		debug Stdout("parse_CharacterRange").newline;
		String var_start;
		String var_end;
		Binding var_binding;

		// AndGroup
			auto position3 = pos;
				// Test
				auto position7 = pos;
					// CustomTerminal
					if(!match(TOK_HEX)){
						goto term5;
					}
					smartAssign(var_end,__match);
				fail6:
					pos = position7;
			term5:
				// CustomTerminal
				if(!match(TOK_HEX)){
					goto fail4;
				}
				smartAssign(var_start,__match);
			term8:
				// Optional
					// AndGroup
						auto position11 = pos;
							// Terminal
							if(!match("-")){
								goto fail12;
							}
						term13:
							// CustomTerminal
							if(match(TOK_HEX)){
								smartAssign(var_end,__match);
								goto term9;
							}
						fail12:
						pos = position11;
						goto term9;
			term9:
				// Optional
					// Production
					if(parse_Binding()){
						smartAssign(var_binding,value_Binding);
						goto pass0;
					}
					goto pass0;
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_CharacterRange = new CharRange(var_start,var_end,var_binding);
			debug Stdout.format("\tparse_CharacterRange passed: {0}",value_CharacterRange).newline;
			return true;
		fail1:
			value_CharacterRange = (CharRange).init;
			debug Stdout.format("\tparse_CharacterRange failed").newline;
			return false;
	}

	/*
	Regexp
		= new RegularExpression(String text,Binding binding)
		::= &TOK_REGEX:text [Binding:binding];

	*/
	RegularExpression value_Regexp;
	bool parse_Regexp(){
		debug Stdout("parse_Regexp").newline;
		Binding var_binding;
		String var_text;

		// AndGroup
			auto position3 = pos;
				// CustomTerminal
				if(!match(TOK_REGEX)){
					goto fail4;
				}
				smartAssign(var_text,__match);
			term5:
				// Optional
					// Production
					if(parse_Binding()){
						smartAssign(var_binding,value_Binding);
						goto pass0;
					}
					goto pass0;
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_Regexp = new RegularExpression(var_text,var_binding);
			debug Stdout.format("\tparse_Regexp passed: {0}",value_Regexp).newline;
			return true;
		fail1:
			value_Regexp = (RegularExpression).init;
			debug Stdout.format("\tparse_Regexp failed").newline;
			return false;
	}

	/*
	NegateExpr
		= new Negate(Expression expr)
		::= "^" SubExpression:expr;

	*/
	Negate value_NegateExpr;
	bool parse_NegateExpr(){
		debug Stdout("parse_NegateExpr").newline;
		Expression var_expr;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("^")){
					goto fail4;
				}
			term5:
				// Production
				if(parse_SubExpression()){
					smartAssign(var_expr,value_SubExpression);
					goto pass0;
				}
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_NegateExpr = new Negate(var_expr);
			debug Stdout.format("\tparse_NegateExpr passed: {0}",value_NegateExpr).newline;
			return true;
		fail1:
			value_NegateExpr = (Negate).init;
			debug Stdout.format("\tparse_NegateExpr failed").newline;
			return false;
	}

	/*
	TestExpr
		= new Test(Expression expr)
		::= "/" SubExpression:expr;

	*/
	Test value_TestExpr;
	bool parse_TestExpr(){
		debug Stdout("parse_TestExpr").newline;
		Expression var_expr;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("/")){
					goto fail4;
				}
			term5:
				// Production
				if(parse_SubExpression()){
					smartAssign(var_expr,value_SubExpression);
					goto pass0;
				}
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_TestExpr = new Test(var_expr);
			debug Stdout.format("\tparse_TestExpr passed: {0}",value_TestExpr).newline;
			return true;
		fail1:
			value_TestExpr = (Test).init;
			debug Stdout.format("\tparse_TestExpr failed").newline;
			return false;
	}

	/*
	LiteralExpr
		= new Literal(String name,Binding binding,ProductionArg[] args)
		::= "@" Identifier:name ["!" "(" ProductionArg:~args* % "," ")"] [Binding:binding];

	*/
	Literal value_LiteralExpr;
	bool parse_LiteralExpr(){
		debug Stdout("parse_LiteralExpr").newline;
		String var_name;
		Binding var_binding;
		ProductionArg[] var_args;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("@")){
					goto fail4;
				}
			term5:
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAssign(var_name,value_Identifier);
			term6:
				// Optional
					// AndGroup
						auto position9 = pos;
							// Terminal
							if(!match("!")){
								goto fail10;
							}
						term11:
							// Terminal
							if(!match("(")){
								goto fail10;
							}
						term12:
							// Iterator
							size_t counter17 = 0;
							start13:
								// (terminator)
									// Terminal
									if(match(")")){
										goto end14;
									}
								// (delimeter)
								delim16:
								if(counter17 > 0){
									// Terminal
									if(!match(",")){
										goto fail10;
									}
								}
								// (expression)
								expr15:
									// Production
									if(!parse_ProductionArg()){
										goto fail10;
									}
									smartAppend(var_args,value_ProductionArg);
								increment18:
								// (increment expr count)
									counter17 ++;
								goto start13;
							end14:
								goto term7;
						fail10:
						pos = position9;
						goto term7;
			term7:
				// Optional
					// Production
					if(parse_Binding()){
						smartAssign(var_binding,value_Binding);
						goto pass0;
					}
					goto pass0;
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_LiteralExpr = new Literal(var_name,var_binding,var_args);
			debug Stdout.format("\tparse_LiteralExpr passed: {0}",value_LiteralExpr).newline;
			return true;
		fail1:
			value_LiteralExpr = (Literal).init;
			debug Stdout.format("\tparse_LiteralExpr failed").newline;
			return false;
	}

	/*
	CustomTerminal
		= new CustomTerminal(String name,Binding binding)
		::= "&" Identifier:name [Binding:binding];

	*/
	CustomTerminal value_CustomTerminal;
	bool parse_CustomTerminal(){
		debug Stdout("parse_CustomTerminal").newline;
		String var_name;
		Binding var_binding;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("&")){
					goto fail4;
				}
			term5:
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAssign(var_name,value_Identifier);
			term6:
				// Optional
					// Production
					if(parse_Binding()){
						smartAssign(var_binding,value_Binding);
						goto pass0;
					}
					goto pass0;
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_CustomTerminal = new CustomTerminal(var_name,var_binding);
			debug Stdout.format("\tparse_CustomTerminal passed: {0}",value_CustomTerminal).newline;
			return true;
		fail1:
			value_CustomTerminal = (CustomTerminal).init;
			debug Stdout.format("\tparse_CustomTerminal failed").newline;
			return false;
	}

	/*
	ErrorPoint
		= new ErrorPoint(ProductionArg arg,Expression expr)
		::= &TOK_ERRORPOINT "(" ProductionArg:arg ")" SubExpression:expr;

	*/
	ErrorPoint value_ErrorPoint;
	bool parse_ErrorPoint(){
		debug Stdout("parse_ErrorPoint").newline;
		Expression var_expr;
		ProductionArg var_arg;

		// AndGroup
			auto position3 = pos;
				// CustomTerminal
				if(!match(TOK_ERRORPOINT)){
					goto fail4;
				}
			term5:
				// Terminal
				if(!match("(")){
					goto fail4;
				}
			term6:
				// Production
				if(!parse_ProductionArg()){
					goto fail4;
				}
				smartAssign(var_arg,value_ProductionArg);
			term7:
				// Terminal
				if(!match(")")){
					goto fail4;
				}
			term8:
				// Production
				if(parse_SubExpression()){
					smartAssign(var_expr,value_SubExpression);
					goto pass0;
				}
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_ErrorPoint = new ErrorPoint(var_arg,var_expr);
			debug Stdout.format("\tparse_ErrorPoint passed: {0}",value_ErrorPoint).newline;
			return true;
		fail1:
			value_ErrorPoint = (ErrorPoint).init;
			debug Stdout.format("\tparse_ErrorPoint failed").newline;
			return false;
	}

	/*
	Binding
		= new Binding(String name,bool isConcat)
		::= ":" ["~" @true:isConcat] Identifier:name;

	*/
	Binding value_Binding;
	bool parse_Binding(){
		debug Stdout("parse_Binding").newline;
		String var_name;
		bool var_isConcat;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match(":")){
					goto fail4;
				}
			term5:
				// Optional
					// AndGroup
						auto position8 = pos;
							// Terminal
							if(!match("~")){
								goto fail9;
							}
						term10:
							// Literal
								auto literal11 = true;
								smartAssign(var_isConcat,literal11);
								goto term6;
						fail9:
						pos = position8;
						goto term6;
			term6:
				// Production
				if(parse_Identifier()){
					smartAssign(var_name,value_Identifier);
					goto pass0;
				}
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_Binding = new Binding(var_name,var_isConcat);
			debug Stdout.format("\tparse_Binding passed: {0}",value_Binding).newline;
			return true;
		fail1:
			value_Binding = (Binding).init;
			debug Stdout.format("\tparse_Binding failed").newline;
			return false;
	}

	/*
	Identifier
		= String concatTokens(Atom[] value)
		::= ({&TOK_IDENT} % "."):value;

	*/
	String value_Identifier;
	bool parse_Identifier(){
		debug Stdout("parse_Identifier").newline;
		Atom[] var_value;

		// Group (w/binding)
			auto position2 = pos;
			// Iterator
			size_t counter8 = 0;
			start4:
				// (terminator)
				if(!hasMore()){
					goto end5;
				}
				// (delimeter)
				delim7:
				if(counter8 > 0){
					// Terminal
					if(!match(".")){
						goto end5;
					}
				}
				// (expression)
				expr6:
					// CustomTerminal
					if(!match(TOK_IDENT)){
						goto end5;
					}
				increment9:
				// (increment expr count)
					counter8 ++;
				goto start4;
			end5:
				// (range test)
					if(!((counter8 >= 1))){
						goto fail1;
					}
			pass3:
			smartAssign(var_value,slice(position2,pos));
		// Rule
		pass0:
			value_Identifier = concatTokens(var_value);
			debug Stdout.format("\tparse_Identifier passed: {0}",value_Identifier).newline;
			return true;
		fail1:
			value_Identifier = (String).init;
			debug Stdout.format("\tparse_Identifier failed").newline;
			return false;
	}

	/*
	Directive
		= void runDirective(String name,String[] args)
		$String err1="Expected directive name"
		$String err2="Expected \';\'"
		::= "@" ?!(err1) Identifier:name ["(" (Identifier:~args | &TOK_STRING:~args)* % "," ")"] ?!(err2) ";";

	*/
	bool value_Directive;
	bool parse_Directive(){
		debug Stdout("parse_Directive").newline;
		String var_err2 = "Expected \';\'";
		String var_name;
		String[] var_args;
		String var_err1 = "Expected directive name";

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("@")){
					goto fail4;
				}
			term5:
				// ErrorPoint
					// Production
					if(parse_Identifier()){
						smartAssign(var_name,value_Identifier);
						goto term6;
					}
				fail7:
					error(var_err1);
					goto fail4;
			term6:
				// Optional
					// AndGroup
						auto position10 = pos;
							// Terminal
							if(!match("(")){
								goto fail11;
							}
						term12:
							// Iterator
							size_t counter17 = 0;
							start13:
								// (terminator)
									// Terminal
									if(match(")")){
										goto end14;
									}
								// (delimeter)
								delim16:
								if(counter17 > 0){
									// Terminal
									if(!match(",")){
										goto fail11;
									}
								}
								// (expression)
								expr15:
									// OrGroup increment18
										// Production
										if(parse_Identifier()){
											smartAppend(var_args,value_Identifier);
											goto increment18;
										}
									term19:
										// CustomTerminal
										if(!match(TOK_STRING)){
											goto fail11;
										}
										smartAppend(var_args,__match);
								increment18:
								// (increment expr count)
									counter17 ++;
								goto start13;
							end14:
								goto term8;
						fail11:
						pos = position10;
						goto term8;
			term8:
				// ErrorPoint
					// Terminal
					if(match(";")){
						goto pass0;
					}
				fail20:
					error(var_err2);
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			runDirective(var_name,var_args);
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_Directive failed").newline;
			return false;
	}

	/*
	Attribute
		= void setAttribute(String namespace,String name,String value)
		$String err1="Expected \'=\'"
		$String err1="Expected \';\'"
		::= "." [&TOK_IDENT:namespace "-"] &TOK_IDENT:name ?!(err1) "=" (Identifier:value | &TOK_STRING:value) ?!("err2") ";";

	*/
	bool value_Attribute;
	bool parse_Attribute(){
		debug Stdout("parse_Attribute").newline;
		String var_value;
		String var_name;
		String var_namespace;
		String var_err1 = "Expected \'=\'";

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match(".")){
					goto fail4;
				}
			term5:
				// Optional
					// AndGroup
						auto position8 = pos;
							// CustomTerminal
							if(!match(TOK_IDENT)){
								goto fail9;
							}
							smartAssign(var_namespace,__match);
						term10:
							// Terminal
							if(match("-")){
								goto term6;
							}
						fail9:
						pos = position8;
						goto term6;
			term6:
				// CustomTerminal
				if(!match(TOK_IDENT)){
					goto fail4;
				}
				smartAssign(var_name,__match);
			term11:
				// ErrorPoint
					// Terminal
					if(match("=")){
						goto term12;
					}
				fail13:
					error(var_err1);
					goto fail4;
			term12:
				// OrGroup term14
					// Production
					if(parse_Identifier()){
						smartAssign(var_value,value_Identifier);
						goto term14;
					}
				term15:
					// CustomTerminal
					if(!match(TOK_STRING)){
						goto fail4;
					}
					smartAssign(var_value,__match);
			term14:
				// ErrorPoint
					// Terminal
					if(match(";")){
						goto pass0;
					}
				fail16:
					error("err2");
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			setAttribute(var_namespace,var_name,var_value);
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_Attribute failed").newline;
			return false;
	}
}
