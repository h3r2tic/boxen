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
module enki.frontend.Enki1Parser;
private import enki.frontend.Enki1ParserBase;
private import enki.EnkiToken;
private import enki.Binding;
private import enki.Expression;
private import enki.Param;
private import enki.ProductionArg;
private import enki.Rule;
private import enki.RulePredicate;

debug import tango.io.Stdout;

class Enki1Parser:Enki1ParserBase{
	static char[] getHelp(){
		return "\r\nRendition of the Enki V1 grammar, for backwards compatibility.  \r\nUsers are strongly discouraged from using this grammar due to its \r\nnumerous grammatical faults and quirks.  Please see the \'enki2\' frontend.\r\n";
	}

	/*
	Syntax
		::= (Rule | Directive)* eoi;

	*/
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
					if(parse_Rule()){
						goto start2;
					}
				term5:
					// Production
					if(!parse_Directive()){
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
	Rule
		= void addRule(String name,Param[] decl,RulePredicate pred,Param[] vars,Expression expr)
		::= Identifier:name [RuleDecl:decl] [RulePredicate:pred] &TOK_RULEASSIGN Expression:expr ";";

	*/
	bool parse_Rule(){
		debug Stdout("parse_Rule").newline;
		Param[] var_vars;
		Expression var_expr;
		Param[] var_decl;
		RulePredicate var_pred;
		String var_name;

		// AndGroup
			auto position3 = getPos();
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAssign(var_name,getMatchValue!(String)());
			term5:
				// Optional
					// Production
					if(!parse_RuleDecl()){
						goto term6;
					}
					smartAssign(var_decl,getMatchValue!(Param[])());
			term6:
				// Optional
					// Production
					if(!parse_RulePredicate()){
						goto term7;
					}
					smartAssign(var_pred,getMatchValue!(RulePredicate)());
			term7:
				// CustomTerminal
				if(!match(TOK_RULEASSIGN)){
					goto fail4;
				}
			term8:
				// Production
				if(!parse_Expression()){
					goto fail4;
				}
				smartAssign(var_expr,getMatchValue!(OrGroup)());
			term9:
				// Terminal
				if(match(";")){
					goto pass0;
				}
			fail4:
			setPos(position3);
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
	bool parse_RuleDecl(){
		debug Stdout("parse_RuleDecl").newline;
		Param[] var_params;

		// Production
		if(!parse_ParamsExpr()){
			goto fail1;
		}
		smartAssign(var_params,getMatchValue!(Param[])());
		// Rule
		pass0:
			setMatchValue(var_params);
			debug Stdout.format("\tparse_RuleDecl passed: {0}",getMatchValue!(Param[])).newline;
			return true;
		fail1:
			setMatchValue((Param[]).init);
			debug Stdout.format("\tparse_RuleDecl failed").newline;
			return false;
	}

	/*
	RulePredicate
		= RulePredicate pred
		::= "=" (ClassPredicate:pred | FunctionPredicate:pred | BindingPredicate:pred);

	*/
	bool parse_RulePredicate(){
		debug Stdout("parse_RulePredicate").newline;
		RulePredicate var_pred;

		// AndGroup
			auto position3 = getPos();
				// Terminal
				if(!match("=")){
					goto fail4;
				}
			term5:
				// OrGroup pass0
					// Production
					if(parse_ClassPredicate()){
						smartAssign(var_pred,getMatchValue!(ClassPredicate)());
						goto pass0;
					}
				term6:
					// Production
					if(parse_FunctionPredicate()){
						smartAssign(var_pred,getMatchValue!(FunctionPredicate)());
						goto pass0;
					}
				term7:
					// Production
					if(parse_BindingPredicate()){
						smartAssign(var_pred,getMatchValue!(BindingPredicate)());
						goto pass0;
					}
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			setMatchValue(var_pred);
			debug Stdout.format("\tparse_RulePredicate passed: {0}",getMatchValue!(RulePredicate)).newline;
			return true;
		fail1:
			setMatchValue((RulePredicate).init);
			debug Stdout.format("\tparse_RulePredicate failed").newline;
			return false;
	}

	/*
	ClassPredicate
		= new ClassPredicate(String name,Param[] params)
		::= &TOK_NEW Identifier:name ParamsExpr:params;

	*/
	bool parse_ClassPredicate(){
		debug Stdout("parse_ClassPredicate").newline;
		Param[] var_params;
		String var_name;

		// AndGroup
			auto position3 = getPos();
				// CustomTerminal
				if(!match(TOK_NEW)){
					goto fail4;
				}
			term5:
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAssign(var_name,getMatchValue!(String)());
			term6:
				// Production
				if(parse_ParamsExpr()){
					smartAssign(var_params,getMatchValue!(Param[])());
					goto pass0;
				}
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			setMatchValue(new ClassPredicate(var_name,var_params));
			debug Stdout.format("\tparse_ClassPredicate passed: {0}",getMatchValue!(ClassPredicate)).newline;
			return true;
		fail1:
			setMatchValue((ClassPredicate).init);
			debug Stdout.format("\tparse_ClassPredicate failed").newline;
			return false;
	}

	/*
	FunctionPredicate
		= new FunctionPredicate(Param decl,Param[] params)
		::= ExplicitParam:decl ParamsExpr:params;

	*/
	bool parse_FunctionPredicate(){
		debug Stdout("parse_FunctionPredicate").newline;
		Param var_decl;
		Param[] var_params;

		// AndGroup
			auto position3 = getPos();
				// Production
				if(!parse_ExplicitParam()){
					goto fail4;
				}
				smartAssign(var_decl,getMatchValue!(Param)());
			term5:
				// Production
				if(parse_ParamsExpr()){
					smartAssign(var_params,getMatchValue!(Param[])());
					goto pass0;
				}
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			setMatchValue(new FunctionPredicate(var_decl,var_params));
			debug Stdout.format("\tparse_FunctionPredicate passed: {0}",getMatchValue!(FunctionPredicate)).newline;
			return true;
		fail1:
			setMatchValue((FunctionPredicate).init);
			debug Stdout.format("\tparse_FunctionPredicate failed").newline;
			return false;
	}

	/*
	BindingPredicate
		= new BindingPredicate(Param param)
		::= Param:param;

	*/
	bool parse_BindingPredicate(){
		debug Stdout("parse_BindingPredicate").newline;
		Param var_param;

		// Production
		if(!parse_Param()){
			goto fail1;
		}
		smartAssign(var_param,getMatchValue!(Param)());
		// Rule
		pass0:
			setMatchValue(new BindingPredicate(var_param));
			debug Stdout.format("\tparse_BindingPredicate passed: {0}",getMatchValue!(BindingPredicate)).newline;
			return true;
		fail1:
			setMatchValue((BindingPredicate).init);
			debug Stdout.format("\tparse_BindingPredicate failed").newline;
			return false;
	}

	/*
	ParamsExpr
		= Param[] params
		::= "(" {Param:~params} % "," ")";

	*/
	bool parse_ParamsExpr(){
		debug Stdout("parse_ParamsExpr").newline;
		Param[] var_params;

		// AndGroup
			auto position3 = getPos();
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
						smartAppend(var_params,getMatchValue!(Param)());
					increment11:
					// (increment expr count)
						counter10 ++;
					goto start6;
				end7:
					// (range test)
						if(((counter10 >= 1))){
							goto pass0;
						}
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			setMatchValue(var_params);
			debug Stdout.format("\tparse_ParamsExpr passed: {0}",getMatchValue!(Param[])).newline;
			return true;
		fail1:
			setMatchValue((Param[]).init);
			debug Stdout.format("\tparse_ParamsExpr failed").newline;
			return false;
	}

	/*
	Param
		= Param param
		::= ExplicitParam:param | WeakParam:param;

	*/
	bool parse_Param(){
		debug Stdout("parse_Param").newline;
		Param var_param;

		// OrGroup pass0
			// Production
			if(parse_ExplicitParam()){
				smartAssign(var_param,getMatchValue!(Param)());
				goto pass0;
			}
		term2:
			// Production
			if(!parse_WeakParam()){
				goto fail1;
			}
			smartAssign(var_param,getMatchValue!(Param)());
		// Rule
		pass0:
			setMatchValue(var_param);
			debug Stdout.format("\tparse_Param passed: {0}",getMatchValue!(Param)).newline;
			return true;
		fail1:
			setMatchValue((Param).init);
			debug Stdout.format("\tparse_Param failed").newline;
			return false;
	}

	/*
	WeakParam
		= new Param(String name,String value)
		::= Identifier:name;

	*/
	bool parse_WeakParam(){
		debug Stdout("parse_WeakParam").newline;
		String var_value;
		String var_name;

		// Production
		if(!parse_Identifier()){
			goto fail1;
		}
		smartAssign(var_name,getMatchValue!(String)());
		// Rule
		pass0:
			setMatchValue(new Param(var_name,var_value));
			debug Stdout.format("\tparse_WeakParam passed: {0}",getMatchValue!(Param)).newline;
			return true;
		fail1:
			setMatchValue((Param).init);
			debug Stdout.format("\tparse_WeakParam failed").newline;
			return false;
	}

	/*
	ExplicitParam
		= new Param(String type,String name,String value)
		::= ParamType:type Identifier:name ["=" &TOK_STRING:value];

	*/
	bool parse_ExplicitParam(){
		debug Stdout("parse_ExplicitParam").newline;
		String var_type;
		String var_value;
		String var_name;

		// AndGroup
			auto position3 = getPos();
				// Production
				auto position6 = getPos();
				if(!parse_ParamType()){
					goto fail4;
				}
				smartAssign(var_type,slice(position6,getPos()));
			term5:
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAssign(var_name,getMatchValue!(String)());
			term7:
				// Optional
					// AndGroup
						auto position9 = getPos();
							// Terminal
							if(!match("=")){
								goto fail10;
							}
						term11:
							// CustomTerminal
							if(match(TOK_STRING)){
								smartAssign(var_value,getMatchValue!(String)());
								goto pass0;
							}
						fail10:
						setPos(position9);
					goto pass0;
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			setMatchValue(new Param(var_type,var_name,var_value));
			debug Stdout.format("\tparse_ExplicitParam passed: {0}",getMatchValue!(Param)).newline;
			return true;
		fail1:
			setMatchValue((Param).init);
			debug Stdout.format("\tparse_ExplicitParam failed").newline;
			return false;
	}

	/*
	ParamType
		::= Identifier Brackets;

	*/
	bool parse_ParamType(){
		debug Stdout("parse_ParamType").newline;
		// AndGroup
			auto position3 = getPos();
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
			term5:
				// Production
				if(parse_Brackets()){
					goto pass0;
				}
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_ParamType failed").newline;
			return false;
	}

	/*
	Brackets
		::= ["[" "]" Brackets];

	*/
	bool parse_Brackets(){
		debug Stdout("parse_Brackets").newline;
		// Optional
			// AndGroup
				auto position3 = getPos();
					// Terminal
					if(!match("[")){
						goto fail4;
					}
				term5:
					// Terminal
					if(!match("]")){
						goto fail4;
					}
				term6:
					// Production
					if(parse_Brackets()){
						goto pass0;
					}
				fail4:
				setPos(position3);
				goto pass0;
		// Rule
		pass0:
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_Brackets failed").newline;
			return false;
	}
	alias parse_OrGroup parse_Expression;

	/*
	OrGroup
		= new OrGroup(Expression[] exprs)
		::= (AndGroup:~exprs)+ % "|";

	*/
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
				smartAppend(var_exprs,getMatchValue!(AndGroup)());
			increment7:
			// (increment expr count)
				counter6 ++;
			goto start2;
		end3:
			// (range test)
				if(!((counter6 >= 1))){
					goto fail1;
					goto pass0;
				}
		// Rule
		pass0:
			setMatchValue(new OrGroup(var_exprs));
			debug Stdout.format("\tparse_OrGroup passed: {0}",getMatchValue!(OrGroup)).newline;
			return true;
		fail1:
			setMatchValue((OrGroup).init);
			debug Stdout.format("\tparse_OrGroup failed").newline;
			return false;
	}

	/*
	AndGroup
		= new AndGroup(Expression[] exprs)
		::= (SubExpression:~exprs)+;

	*/
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
				smartAppend(var_exprs,getMatchValue!(Expression)());
			increment6:
			// (increment expr count)
				counter5 ++;
			goto start2;
		end3:
			// (range test)
				if(!((counter5 >= 1))){
					goto fail1;
					goto pass0;
				}
		// Rule
		pass0:
			setMatchValue(new AndGroup(var_exprs));
			debug Stdout.format("\tparse_AndGroup passed: {0}",getMatchValue!(AndGroup)).newline;
			return true;
		fail1:
			setMatchValue((AndGroup).init);
			debug Stdout.format("\tparse_AndGroup failed").newline;
			return false;
	}

	/*
	SubExpression
		= Expression expr
		::= Production:expr | Substitution:expr | Terminal:expr | Range:expr | Regexp:expr | GroupExpr:expr | OptionalExpr:expr | ZeroOrMoreExpr:expr | NegateExpr:expr | TestExpr:expr | LiteralExpr:expr | CustomTerminal:expr;

	*/
	bool parse_SubExpression(){
		debug Stdout("parse_SubExpression").newline;
		Expression var_expr;

		// OrGroup pass0
			// Production
			if(parse_Production()){
				smartAssign(var_expr,getMatchValue!(Production)());
				goto pass0;
			}
		term2:
			// Production
			if(parse_Substitution()){
				smartAssign(var_expr,getMatchValue!(Substitution)());
				goto pass0;
			}
		term3:
			// Production
			if(parse_Terminal()){
				smartAssign(var_expr,getMatchValue!(Terminal)());
				goto pass0;
			}
		term4:
			// Production
			if(parse_Range()){
				smartAssign(var_expr,getMatchValue!(CharRange)());
				goto pass0;
			}
		term5:
			// Production
			if(parse_Regexp()){
				smartAssign(var_expr,getMatchValue!(RegularExpression)());
				goto pass0;
			}
		term6:
			// Production
			if(parse_GroupExpr()){
				smartAssign(var_expr,getMatchValue!(Group)());
				goto pass0;
			}
		term7:
			// Production
			if(parse_OptionalExpr()){
				smartAssign(var_expr,getMatchValue!(Optional)());
				goto pass0;
			}
		term8:
			// Production
			if(parse_ZeroOrMoreExpr()){
				smartAssign(var_expr,getMatchValue!(Group)());
				goto pass0;
			}
		term9:
			// Production
			if(parse_NegateExpr()){
				smartAssign(var_expr,getMatchValue!(Negate)());
				goto pass0;
			}
		term10:
			// Production
			if(parse_TestExpr()){
				smartAssign(var_expr,getMatchValue!(Test)());
				goto pass0;
			}
		term11:
			// Production
			if(parse_LiteralExpr()){
				smartAssign(var_expr,getMatchValue!(Literal)());
				goto pass0;
			}
		term12:
			// Production
			if(!parse_CustomTerminal()){
				goto fail1;
			}
			smartAssign(var_expr,getMatchValue!(CustomTerminal)());
		// Rule
		pass0:
			setMatchValue(var_expr);
			debug Stdout.format("\tparse_SubExpression passed: {0}",getMatchValue!(Expression)).newline;
			return true;
		fail1:
			setMatchValue((Expression).init);
			debug Stdout.format("\tparse_SubExpression failed").newline;
			return false;
	}

	/*
	Production
		= new Production(String name,Binding binding,ProductionArg[] args)
		::= Identifier:name ["!(" (ProductionArg:~args)+ % "," ")"] [Binding:binding];

	*/
	bool parse_Production(){
		debug Stdout("parse_Production").newline;
		ProductionArg[] var_args;
		String var_name;
		Binding var_binding;

		// AndGroup
			auto position3 = getPos();
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAssign(var_name,getMatchValue!(String)());
			term5:
				// Optional
					// AndGroup
						auto position8 = getPos();
							// Terminal
							if(!match("!(")){
								goto fail9;
							}
						term10:
							// Iterator
							size_t counter15 = 0;
							start11:
								// (terminator)
									// Terminal
									if(match(")")){
										goto end12;
									}
								// (delimeter)
								delim14:
								if(counter15 > 0){
									// Terminal
									if(!match(",")){
										goto fail9;
									}
								}
								// (expression)
								expr13:
									// Production
									if(!parse_ProductionArg()){
										goto fail9;
									}
									smartAppend(var_args,getMatchValue!(ProductionArg)());
								increment16:
								// (increment expr count)
									counter15 ++;
								goto start11;
							end12:
								// (range test)
									if(((counter15 >= 1))){
										goto term6;
									}
						fail9:
						setPos(position8);
						goto term6;
			term6:
				// Optional
					// Production
					if(parse_Binding()){
						smartAssign(var_binding,getMatchValue!(Binding)());
						goto pass0;
					}
					goto pass0;
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			setMatchValue(new Production(var_name,var_binding,var_args));
			debug Stdout.format("\tparse_Production passed: {0}",getMatchValue!(Production)).newline;
			return true;
		fail1:
			setMatchValue((Production).init);
			debug Stdout.format("\tparse_Production failed").newline;
			return false;
	}

	/*
	ProductionArg
		= ProductionArg arg
		::= StringProductionArg:arg | BindingProductionArg:arg;

	*/
	bool parse_ProductionArg(){
		debug Stdout("parse_ProductionArg").newline;
		ProductionArg var_arg;

		// OrGroup pass0
			// Production
			if(parse_StringProductionArg()){
				smartAssign(var_arg,getMatchValue!(StringProductionArg)());
				goto pass0;
			}
		term2:
			// Production
			if(!parse_BindingProductionArg()){
				goto fail1;
			}
			smartAssign(var_arg,getMatchValue!(BindingProductionArg)());
		// Rule
		pass0:
			setMatchValue(var_arg);
			debug Stdout.format("\tparse_ProductionArg passed: {0}",getMatchValue!(ProductionArg)).newline;
			return true;
		fail1:
			setMatchValue((ProductionArg).init);
			debug Stdout.format("\tparse_ProductionArg failed").newline;
			return false;
	}

	/*
	StringProductionArg
		= new StringProductionArg(String value)
		::= &TOK_STRING:value;

	*/
	bool parse_StringProductionArg(){
		debug Stdout("parse_StringProductionArg").newline;
		String var_value;

		// CustomTerminal
		if(!match(TOK_STRING)){
			goto fail1;
		}
		smartAssign(var_value,getMatchValue!(String)());
		// Rule
		pass0:
			setMatchValue(new StringProductionArg(var_value));
			debug Stdout.format("\tparse_StringProductionArg passed: {0}",getMatchValue!(StringProductionArg)).newline;
			return true;
		fail1:
			setMatchValue((StringProductionArg).init);
			debug Stdout.format("\tparse_StringProductionArg failed").newline;
			return false;
	}

	/*
	BindingProductionArg
		= new BindingProductionArg(String value)
		::= Identifier:value;

	*/
	bool parse_BindingProductionArg(){
		debug Stdout("parse_BindingProductionArg").newline;
		String var_value;

		// Production
		if(!parse_Identifier()){
			goto fail1;
		}
		smartAssign(var_value,getMatchValue!(String)());
		// Rule
		pass0:
			setMatchValue(new BindingProductionArg(var_value));
			debug Stdout.format("\tparse_BindingProductionArg passed: {0}",getMatchValue!(BindingProductionArg)).newline;
			return true;
		fail1:
			setMatchValue((BindingProductionArg).init);
			debug Stdout.format("\tparse_BindingProductionArg failed").newline;
			return false;
	}

	/*
	Substitution
		= new Substitution(String name,Binding binding)
		::= "." Identifier:name [Binding:binding];

	*/
	bool parse_Substitution(){
		debug Stdout("parse_Substitution").newline;
		String var_name;
		Binding var_binding;

		// AndGroup
			auto position3 = getPos();
				// Terminal
				if(!match(".")){
					goto fail4;
				}
			term5:
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAssign(var_name,getMatchValue!(String)());
			term6:
				// Optional
					// Production
					if(parse_Binding()){
						smartAssign(var_binding,getMatchValue!(Binding)());
						goto pass0;
					}
					goto pass0;
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			setMatchValue(new Substitution(var_name,var_binding));
			debug Stdout.format("\tparse_Substitution passed: {0}",getMatchValue!(Substitution)).newline;
			return true;
		fail1:
			setMatchValue((Substitution).init);
			debug Stdout.format("\tparse_Substitution failed").newline;
			return false;
	}

	/*
	GroupExpr
		= new Group(Expression expr,Binding binding)
		::= "(" Expression:expr ")" [Binding:binding];

	*/
	bool parse_GroupExpr(){
		debug Stdout("parse_GroupExpr").newline;
		Expression var_expr;
		Binding var_binding;

		// AndGroup
			auto position3 = getPos();
				// Terminal
				if(!match("(")){
					goto fail4;
				}
			term5:
				// Production
				if(!parse_Expression()){
					goto fail4;
				}
				smartAssign(var_expr,getMatchValue!(OrGroup)());
			term6:
				// Terminal
				if(!match(")")){
					goto fail4;
				}
			term7:
				// Optional
					// Production
					if(parse_Binding()){
						smartAssign(var_binding,getMatchValue!(Binding)());
						goto pass0;
					}
					goto pass0;
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			setMatchValue(new Group(var_expr,var_binding));
			debug Stdout.format("\tparse_GroupExpr passed: {0}",getMatchValue!(Group)).newline;
			return true;
		fail1:
			setMatchValue((Group).init);
			debug Stdout.format("\tparse_GroupExpr failed").newline;
			return false;
	}

	/*
	OptionalExpr
		= new Optional(Expression expr,Binding binding)
		::= "[" Expression:expr "]" [Binding:binding];

	*/
	bool parse_OptionalExpr(){
		debug Stdout("parse_OptionalExpr").newline;
		Expression var_expr;
		Binding var_binding;

		// AndGroup
			auto position3 = getPos();
				// Terminal
				if(!match("[")){
					goto fail4;
				}
			term5:
				// Production
				if(!parse_Expression()){
					goto fail4;
				}
				smartAssign(var_expr,getMatchValue!(OrGroup)());
			term6:
				// Terminal
				if(!match("]")){
					goto fail4;
				}
			term7:
				// Optional
					// Production
					if(parse_Binding()){
						smartAssign(var_binding,getMatchValue!(Binding)());
						goto pass0;
					}
					goto pass0;
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			setMatchValue(new Optional(var_expr,var_binding));
			debug Stdout.format("\tparse_OptionalExpr passed: {0}",getMatchValue!(Optional)).newline;
			return true;
		fail1:
			setMatchValue((Optional).init);
			debug Stdout.format("\tparse_OptionalExpr failed").newline;
			return false;
	}

	/*
	ZeroOrMoreExpr
		= new Group(Expression expr,Binding binding)
		::= ZeroOrMoreExprCore!(binding):expr;

	*/
	bool parse_ZeroOrMoreExpr(){
		debug Stdout("parse_ZeroOrMoreExpr").newline;
		Expression var_expr;
		Binding var_binding;

		// Production
		if(!parse_ZeroOrMoreExprCore(var_binding)){
			goto fail1;
		}
		smartAssign(var_expr,getMatchValue!(OneOrMoreExpr)());
		// Rule
		pass0:
			setMatchValue(new Group(var_expr,var_binding));
			debug Stdout.format("\tparse_ZeroOrMoreExpr passed: {0}",getMatchValue!(Group)).newline;
			return true;
		fail1:
			setMatchValue((Group).init);
			debug Stdout.format("\tparse_ZeroOrMoreExpr failed").newline;
			return false;
	}

	/*
	ZeroOrMoreExprCore(Binding binding)
		= new OneOrMoreExpr(Expression expr)
		::= "{" Expression:expr "}" [Binding:binding];

	*/
	bool parse_ZeroOrMoreExprCore(Binding var_binding){
		debug Stdout("parse_ZeroOrMoreExprCore").newline;
		Expression var_expr;

		// AndGroup
			auto position3 = getPos();
				// Terminal
				if(!match("{")){
					goto fail4;
				}
			term5:
				// Production
				if(!parse_Expression()){
					goto fail4;
				}
				smartAssign(var_expr,getMatchValue!(OrGroup)());
			term6:
				// Terminal
				if(!match("}")){
					goto fail4;
				}
			term7:
				// Optional
					// Production
					if(parse_Binding()){
						smartAssign(var_binding,getMatchValue!(Binding)());
						goto pass0;
					}
					goto pass0;
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			setMatchValue(new OneOrMoreExpr(var_expr));
			debug Stdout.format("\tparse_ZeroOrMoreExprCore passed: {0}",getMatchValue!(OneOrMoreExpr)).newline;
			return true;
		fail1:
			setMatchValue((OneOrMoreExpr).init);
			debug Stdout.format("\tparse_ZeroOrMoreExprCore failed").newline;
			return false;
	}

	/*
	Terminal
		= new Terminal(String text,Binding binding)
		::= &TOK_STRING:text [Binding:binding];

	*/
	bool parse_Terminal(){
		debug Stdout("parse_Terminal").newline;
		String var_text;
		Binding var_binding;

		// AndGroup
			auto position3 = getPos();
				// CustomTerminal
				if(!match(TOK_STRING)){
					goto fail4;
				}
				smartAssign(var_text,getMatchValue!(String)());
			term5:
				// Optional
					// Production
					if(parse_Binding()){
						smartAssign(var_binding,getMatchValue!(Binding)());
						goto pass0;
					}
					goto pass0;
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			setMatchValue(new Terminal(var_text,var_binding));
			debug Stdout.format("\tparse_Terminal passed: {0}",getMatchValue!(Terminal)).newline;
			return true;
		fail1:
			setMatchValue((Terminal).init);
			debug Stdout.format("\tparse_Terminal failed").newline;
			return false;
	}

	/*
	Range
		= new CharRange(String start,String end,Binding binding)
		::= /&TOK_HEX:end &TOK_HEX:start ["-" &TOK_HEX:end] [Binding:binding];

	*/
	bool parse_Range(){
		debug Stdout("parse_Range").newline;
		String var_end;
		String var_start;
		Binding var_binding;

		// AndGroup
			auto position3 = getPos();
				// Test
				auto position7 = getPos();
					// CustomTerminal
					if(!match(TOK_HEX)){
						goto term5;
					}
					smartAssign(var_end,getMatchValue!(String)());
				fail6:
					setPos(position7);
			term5:
				// CustomTerminal
				if(!match(TOK_HEX)){
					goto fail4;
				}
				smartAssign(var_start,getMatchValue!(String)());
			term8:
				// Optional
					// AndGroup
						auto position11 = getPos();
							// Terminal
							if(!match("-")){
								goto fail12;
							}
						term13:
							// CustomTerminal
							if(match(TOK_HEX)){
								smartAssign(var_end,getMatchValue!(String)());
								goto term9;
							}
						fail12:
						setPos(position11);
						goto term9;
			term9:
				// Optional
					// Production
					if(parse_Binding()){
						smartAssign(var_binding,getMatchValue!(Binding)());
						goto pass0;
					}
					goto pass0;
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			setMatchValue(new CharRange(var_start,var_end,var_binding));
			debug Stdout.format("\tparse_Range passed: {0}",getMatchValue!(CharRange)).newline;
			return true;
		fail1:
			setMatchValue((CharRange).init);
			debug Stdout.format("\tparse_Range failed").newline;
			return false;
	}

	/*
	Regexp
		= new RegularExpression(String text,Binding binding)
		::= &TOK_REGEX:text [Binding:binding];

	*/
	bool parse_Regexp(){
		debug Stdout("parse_Regexp").newline;
		String var_text;
		Binding var_binding;

		// AndGroup
			auto position3 = getPos();
				// CustomTerminal
				if(!match(TOK_REGEX)){
					goto fail4;
				}
				smartAssign(var_text,getMatchValue!(String)());
			term5:
				// Optional
					// Production
					if(parse_Binding()){
						smartAssign(var_binding,getMatchValue!(Binding)());
						goto pass0;
					}
					goto pass0;
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			setMatchValue(new RegularExpression(var_text,var_binding));
			debug Stdout.format("\tparse_Regexp passed: {0}",getMatchValue!(RegularExpression)).newline;
			return true;
		fail1:
			setMatchValue((RegularExpression).init);
			debug Stdout.format("\tparse_Regexp failed").newline;
			return false;
	}

	/*
	NegateExpr
		= new Negate(Expression expr)
		::= "!" SubExpression:expr;

	*/
	bool parse_NegateExpr(){
		debug Stdout("parse_NegateExpr").newline;
		Expression var_expr;

		// AndGroup
			auto position3 = getPos();
				// Terminal
				if(!match("!")){
					goto fail4;
				}
			term5:
				// Production
				if(parse_SubExpression()){
					smartAssign(var_expr,getMatchValue!(Expression)());
					goto pass0;
				}
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			setMatchValue(new Negate(var_expr));
			debug Stdout.format("\tparse_NegateExpr passed: {0}",getMatchValue!(Negate)).newline;
			return true;
		fail1:
			setMatchValue((Negate).init);
			debug Stdout.format("\tparse_NegateExpr failed").newline;
			return false;
	}

	/*
	TestExpr
		= new Test(Expression expr)
		::= "/" SubExpression:expr;

	*/
	bool parse_TestExpr(){
		debug Stdout("parse_TestExpr").newline;
		Expression var_expr;

		// AndGroup
			auto position3 = getPos();
				// Terminal
				if(!match("/")){
					goto fail4;
				}
			term5:
				// Production
				if(parse_SubExpression()){
					smartAssign(var_expr,getMatchValue!(Expression)());
					goto pass0;
				}
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			setMatchValue(new Test(var_expr));
			debug Stdout.format("\tparse_TestExpr passed: {0}",getMatchValue!(Test)).newline;
			return true;
		fail1:
			setMatchValue((Test).init);
			debug Stdout.format("\tparse_TestExpr failed").newline;
			return false;
	}

	/*
	LiteralExpr
		= new Literal(String name,Binding binding,ProductionArg[] args)
		::= "@" Identifier:name ["!(" (ProductionArg:~args)* % "," ")"] [Binding:binding];

	*/
	bool parse_LiteralExpr(){
		debug Stdout("parse_LiteralExpr").newline;
		ProductionArg[] var_args;
		String var_name;
		Binding var_binding;

		// AndGroup
			auto position3 = getPos();
				// Terminal
				if(!match("@")){
					goto fail4;
				}
			term5:
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAssign(var_name,getMatchValue!(String)());
			term6:
				// Optional
					// AndGroup
						auto position9 = getPos();
							// Terminal
							if(!match("!(")){
								goto fail10;
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
										goto fail10;
									}
								}
								// (expression)
								expr14:
									// Production
									if(!parse_ProductionArg()){
										goto fail10;
									}
									smartAppend(var_args,getMatchValue!(ProductionArg)());
								increment17:
								// (increment expr count)
									counter16 ++;
								goto start12;
							end13:
								goto term7;
						fail10:
						setPos(position9);
						goto term7;
			term7:
				// Optional
					// Production
					if(parse_Binding()){
						smartAssign(var_binding,getMatchValue!(Binding)());
						goto pass0;
					}
					goto pass0;
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			setMatchValue(new Literal(var_name,var_binding,var_args));
			debug Stdout.format("\tparse_LiteralExpr passed: {0}",getMatchValue!(Literal)).newline;
			return true;
		fail1:
			setMatchValue((Literal).init);
			debug Stdout.format("\tparse_LiteralExpr failed").newline;
			return false;
	}

	/*
	CustomTerminal
		= new CustomTerminal(String name,Binding binding)
		::= "&" Identifier:name [Binding:binding];

	*/
	bool parse_CustomTerminal(){
		debug Stdout("parse_CustomTerminal").newline;
		String var_name;
		Binding var_binding;

		// AndGroup
			auto position3 = getPos();
				// Terminal
				if(!match("&")){
					goto fail4;
				}
			term5:
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAssign(var_name,getMatchValue!(String)());
			term6:
				// Optional
					// Production
					if(parse_Binding()){
						smartAssign(var_binding,getMatchValue!(Binding)());
						goto pass0;
					}
					goto pass0;
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			setMatchValue(new CustomTerminal(var_name,var_binding));
			debug Stdout.format("\tparse_CustomTerminal passed: {0}",getMatchValue!(CustomTerminal)).newline;
			return true;
		fail1:
			setMatchValue((CustomTerminal).init);
			debug Stdout.format("\tparse_CustomTerminal failed").newline;
			return false;
	}

	/*
	Binding
		= new Binding(String name,bool isConcat)
		::= ":" ["~" @true:isConcat] Identifier:name;

	*/
	bool parse_Binding(){
		debug Stdout("parse_Binding").newline;
		bool var_isConcat;
		String var_name;

		// AndGroup
			auto position3 = getPos();
				// Terminal
				if(!match(":")){
					goto fail4;
				}
			term5:
				// Optional
					// AndGroup
						auto position8 = getPos();
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
						setPos(position8);
						goto term6;
			term6:
				// Production
				if(parse_Identifier()){
					smartAssign(var_name,getMatchValue!(String)());
					goto pass0;
				}
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			setMatchValue(new Binding(var_name,var_isConcat));
			debug Stdout.format("\tparse_Binding passed: {0}",getMatchValue!(Binding)).newline;
			return true;
		fail1:
			setMatchValue((Binding).init);
			debug Stdout.format("\tparse_Binding failed").newline;
			return false;
	}

	/*
	Identifier
		= String value
		::= ({&TOK_IDENT} % "."):value;

	*/
	bool parse_Identifier(){
		debug Stdout("parse_Identifier").newline;
		String var_value;

		// Group (w/binding)
			auto position2 = getPos();
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
						goto pass3;
					}
			pass3:
			smartAssign(var_value,slice(position2,getPos()));
		// Rule
		pass0:
			setMatchValue(var_value);
			debug Stdout.format("\tparse_Identifier passed: {0}",getMatchValue!(String)).newline;
			return true;
		fail1:
			setMatchValue((String).init);
			debug Stdout.format("\tparse_Identifier failed").newline;
			return false;
	}

	/*
	Directive
		::= "." (ImportDirective:~dir | BaseClassDirective:~dir | ClassnameDirective:~dir | DefineDirective:~dir | IncludeDirective:~dir | AliasDirective:~dir | ModuleDirective:~dir | CodeDirective:~dir | TypelibDirective:~dir | ParseTypeDirective:~dir | BoilerplateDirective:~dir | HeaderDirective:~dir | UTFDirective:~dir);

	*/
	bool parse_Directive(){
		debug Stdout("parse_Directive").newline;
		String var_dir;

		// AndGroup
			auto position3 = getPos();
				// Terminal
				if(!match(".")){
					goto fail4;
				}
			term5:
				// OrGroup pass0
					// Production
					auto position7 = getPos();
					if(parse_ImportDirective()){
						smartAppend(var_dir,slice(position7,getPos()));
						goto pass0;
					}
				term6:
					// Production
					auto position9 = getPos();
					if(parse_BaseClassDirective()){
						smartAppend(var_dir,slice(position9,getPos()));
						goto pass0;
					}
				term8:
					// Production
					auto position11 = getPos();
					if(parse_ClassnameDirective()){
						smartAppend(var_dir,slice(position11,getPos()));
						goto pass0;
					}
				term10:
					// Production
					auto position13 = getPos();
					if(parse_DefineDirective()){
						smartAppend(var_dir,slice(position13,getPos()));
						goto pass0;
					}
				term12:
					// Production
					auto position15 = getPos();
					if(parse_IncludeDirective()){
						smartAppend(var_dir,slice(position15,getPos()));
						goto pass0;
					}
				term14:
					// Production
					auto position17 = getPos();
					if(parse_AliasDirective()){
						smartAppend(var_dir,slice(position17,getPos()));
						goto pass0;
					}
				term16:
					// Production
					auto position19 = getPos();
					if(parse_ModuleDirective()){
						smartAppend(var_dir,slice(position19,getPos()));
						goto pass0;
					}
				term18:
					// Production
					auto position21 = getPos();
					if(parse_CodeDirective()){
						smartAppend(var_dir,slice(position21,getPos()));
						goto pass0;
					}
				term20:
					// Production
					auto position23 = getPos();
					if(parse_TypelibDirective()){
						smartAppend(var_dir,slice(position23,getPos()));
						goto pass0;
					}
				term22:
					// Production
					auto position25 = getPos();
					if(parse_ParseTypeDirective()){
						smartAppend(var_dir,slice(position25,getPos()));
						goto pass0;
					}
				term24:
					// Production
					auto position27 = getPos();
					if(parse_BoilerplateDirective()){
						smartAppend(var_dir,slice(position27,getPos()));
						goto pass0;
					}
				term26:
					// Production
					auto position29 = getPos();
					if(parse_HeaderDirective()){
						smartAppend(var_dir,slice(position29,getPos()));
						goto pass0;
					}
				term28:
					// Production
					auto position30 = getPos();
					if(parse_UTFDirective()){
						smartAppend(var_dir,slice(position30,getPos()));
						goto pass0;
					}
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_Directive failed").newline;
			return false;
	}

	/*
	ImportDirective
		= void addImport(String imp)
		::= Keyword!("import") "(" DirectiveArg:imp ")" ";";

	*/
	bool parse_ImportDirective(){
		debug Stdout("parse_ImportDirective").newline;
		String var_imp;

		// AndGroup
			auto position3 = getPos();
				// Production
				if(!parse_Keyword("import")){
					goto fail4;
				}
			term5:
				// Terminal
				if(!match("(")){
					goto fail4;
				}
			term6:
				// Production
				if(!parse_DirectiveArg()){
					goto fail4;
				}
				smartAssign(var_imp,getMatchValue!(String)());
			term7:
				// Terminal
				if(!match(")")){
					goto fail4;
				}
			term8:
				// Terminal
				if(match(";")){
					goto pass0;
				}
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			addImport(var_imp);
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_ImportDirective failed").newline;
			return false;
	}

	/*
	BaseClassDirective
		= void setBaseClass(String imp)
		::= Keyword!("baseclass") "(" DirectiveArg:name ")" ";";

	*/
	bool parse_BaseClassDirective(){
		debug Stdout("parse_BaseClassDirective").newline;
		String var_imp;
		String var_name;

		// AndGroup
			auto position3 = getPos();
				// Production
				if(!parse_Keyword("baseclass")){
					goto fail4;
				}
			term5:
				// Terminal
				if(!match("(")){
					goto fail4;
				}
			term6:
				// Production
				if(!parse_DirectiveArg()){
					goto fail4;
				}
				smartAssign(var_name,getMatchValue!(String)());
			term7:
				// Terminal
				if(!match(")")){
					goto fail4;
				}
			term8:
				// Terminal
				if(match(";")){
					goto pass0;
				}
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			setBaseClass(var_imp);
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_BaseClassDirective failed").newline;
			return false;
	}

	/*
	ClassnameDirective
		= void setClassname(String imp)
		::= Keyword!("classname") "(" DirectiveArg:name ")" ";";

	*/
	bool parse_ClassnameDirective(){
		debug Stdout("parse_ClassnameDirective").newline;
		String var_imp;
		String var_name;

		// AndGroup
			auto position3 = getPos();
				// Production
				if(!parse_Keyword("classname")){
					goto fail4;
				}
			term5:
				// Terminal
				if(!match("(")){
					goto fail4;
				}
			term6:
				// Production
				if(!parse_DirectiveArg()){
					goto fail4;
				}
				smartAssign(var_name,getMatchValue!(String)());
			term7:
				// Terminal
				if(!match(")")){
					goto fail4;
				}
			term8:
				// Terminal
				if(match(";")){
					goto pass0;
				}
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			setClassname(var_imp);
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_ClassnameDirective failed").newline;
			return false;
	}

	/*
	DefineDirective
		= void addPrototype(String name,String returnType)
		::= Keyword!("define") "(" DirectiveArg:returnType "," DirectiveArg:name "," DirectiveArg:isTerminal ["," DirectiveArg:description] ")" ";";

	*/
	bool parse_DefineDirective(){
		debug Stdout("parse_DefineDirective").newline;
		String var_returnType;
		String var_isTerminal;
		String var_name;
		String var_description;

		// AndGroup
			auto position3 = getPos();
				// Production
				if(!parse_Keyword("define")){
					goto fail4;
				}
			term5:
				// Terminal
				if(!match("(")){
					goto fail4;
				}
			term6:
				// Production
				if(!parse_DirectiveArg()){
					goto fail4;
				}
				smartAssign(var_returnType,getMatchValue!(String)());
			term7:
				// Terminal
				if(!match(",")){
					goto fail4;
				}
			term8:
				// Production
				if(!parse_DirectiveArg()){
					goto fail4;
				}
				smartAssign(var_name,getMatchValue!(String)());
			term9:
				// Terminal
				if(!match(",")){
					goto fail4;
				}
			term10:
				// Production
				if(!parse_DirectiveArg()){
					goto fail4;
				}
				smartAssign(var_isTerminal,getMatchValue!(String)());
			term11:
				// Optional
					// AndGroup
						auto position14 = getPos();
							// Terminal
							if(!match(",")){
								goto fail15;
							}
						term16:
							// Production
							if(parse_DirectiveArg()){
								smartAssign(var_description,getMatchValue!(String)());
								goto term12;
							}
						fail15:
						setPos(position14);
						goto term12;
			term12:
				// Terminal
				if(!match(")")){
					goto fail4;
				}
			term17:
				// Terminal
				if(match(";")){
					goto pass0;
				}
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			addPrototype(var_name,var_returnType);
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_DefineDirective failed").newline;
			return false;
	}

	/*
	IncludeDirective
		= void includeDirective(String filename)
		::= Keyword!("include") "(" &TOK_STRING:filename ")" ";";

	*/
	bool parse_IncludeDirective(){
		debug Stdout("parse_IncludeDirective").newline;
		String var_filename;

		// AndGroup
			auto position3 = getPos();
				// Production
				if(!parse_Keyword("include")){
					goto fail4;
				}
			term5:
				// Terminal
				if(!match("(")){
					goto fail4;
				}
			term6:
				// CustomTerminal
				if(!match(TOK_STRING)){
					goto fail4;
				}
				smartAssign(var_filename,getMatchValue!(String)());
			term7:
				// Terminal
				if(!match(")")){
					goto fail4;
				}
			term8:
				// Terminal
				if(match(";")){
					goto pass0;
				}
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			includeDirective(var_filename);
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_IncludeDirective failed").newline;
			return false;
	}

	/*
	AliasDirective
		= void addAlias(String ruleAlias,String rule)
		::= Keyword!("alias") "(" DirectiveArg:rule "," DirectiveArg:ruleAlias ")" ";";

	*/
	bool parse_AliasDirective(){
		debug Stdout("parse_AliasDirective").newline;
		String var_rule;
		String var_ruleAlias;

		// AndGroup
			auto position3 = getPos();
				// Production
				if(!parse_Keyword("alias")){
					goto fail4;
				}
			term5:
				// Terminal
				if(!match("(")){
					goto fail4;
				}
			term6:
				// Production
				if(!parse_DirectiveArg()){
					goto fail4;
				}
				smartAssign(var_rule,getMatchValue!(String)());
			term7:
				// Terminal
				if(!match(",")){
					goto fail4;
				}
			term8:
				// Production
				if(!parse_DirectiveArg()){
					goto fail4;
				}
				smartAssign(var_ruleAlias,getMatchValue!(String)());
			term9:
				// Terminal
				if(!match(")")){
					goto fail4;
				}
			term10:
				// Terminal
				if(match(";")){
					goto pass0;
				}
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			addAlias(var_ruleAlias,var_rule);
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_AliasDirective failed").newline;
			return false;
	}

	/*
	ModuleDirective
		= void setModulename(String moduleName)
		::= Keyword!("module") "(" DirectiveArg:moduleName ")" ";";

	*/
	bool parse_ModuleDirective(){
		debug Stdout("parse_ModuleDirective").newline;
		String var_moduleName;

		// AndGroup
			auto position3 = getPos();
				// Production
				if(!parse_Keyword("module")){
					goto fail4;
				}
			term5:
				// Terminal
				if(!match("(")){
					goto fail4;
				}
			term6:
				// Production
				if(!parse_DirectiveArg()){
					goto fail4;
				}
				smartAssign(var_moduleName,getMatchValue!(String)());
			term7:
				// Terminal
				if(!match(")")){
					goto fail4;
				}
			term8:
				// Terminal
				if(match(";")){
					goto pass0;
				}
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			setModulename(var_moduleName);
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_ModuleDirective failed").newline;
			return false;
	}

	/*
	CodeDirective
		::= Keyword!("code") "{{{" &TOK_STRING "}}}";

	*/
	bool parse_CodeDirective(){
		debug Stdout("parse_CodeDirective").newline;
		// AndGroup
			auto position3 = getPos();
				// Production
				if(!parse_Keyword("code")){
					goto fail4;
				}
			term5:
				// Terminal
				if(!match("{{{")){
					goto fail4;
				}
			term6:
				// CustomTerminal
				if(!match(TOK_STRING)){
					goto fail4;
				}
			term7:
				// Terminal
				if(match("}}}")){
					goto pass0;
				}
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_CodeDirective failed").newline;
			return false;
	}

	/*
	TypelibDirective
		::= Keyword!("typelib") "(" DirectiveArg:importName ")" ";";

	*/
	bool parse_TypelibDirective(){
		debug Stdout("parse_TypelibDirective").newline;
		String var_importName;

		// AndGroup
			auto position3 = getPos();
				// Production
				if(!parse_Keyword("typelib")){
					goto fail4;
				}
			term5:
				// Terminal
				if(!match("(")){
					goto fail4;
				}
			term6:
				// Production
				if(!parse_DirectiveArg()){
					goto fail4;
				}
				smartAssign(var_importName,getMatchValue!(String)());
			term7:
				// Terminal
				if(!match(")")){
					goto fail4;
				}
			term8:
				// Terminal
				if(match(";")){
					goto pass0;
				}
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_TypelibDirective failed").newline;
			return false;
	}

	/*
	ParseTypeDirective
		::= Keyword!("parsetype") "(" DirectiveArg:typeName ")" ";";

	*/
	bool parse_ParseTypeDirective(){
		debug Stdout("parse_ParseTypeDirective").newline;
		String var_typeName;

		// AndGroup
			auto position3 = getPos();
				// Production
				if(!parse_Keyword("parsetype")){
					goto fail4;
				}
			term5:
				// Terminal
				if(!match("(")){
					goto fail4;
				}
			term6:
				// Production
				if(!parse_DirectiveArg()){
					goto fail4;
				}
				smartAssign(var_typeName,getMatchValue!(String)());
			term7:
				// Terminal
				if(!match(")")){
					goto fail4;
				}
			term8:
				// Terminal
				if(match(";")){
					goto pass0;
				}
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_ParseTypeDirective failed").newline;
			return false;
	}

	/*
	BoilerplateDirective
		= void setBoilerplate(String code)
		::= Keyword!("boilerplate") "{{{" &TOK_STRING:code "}}}";

	*/
	bool parse_BoilerplateDirective(){
		debug Stdout("parse_BoilerplateDirective").newline;
		String var_code;

		// AndGroup
			auto position3 = getPos();
				// Production
				if(!parse_Keyword("boilerplate")){
					goto fail4;
				}
			term5:
				// Terminal
				if(!match("{{{")){
					goto fail4;
				}
			term6:
				// CustomTerminal
				if(!match(TOK_STRING)){
					goto fail4;
				}
				smartAssign(var_code,getMatchValue!(String)());
			term7:
				// Terminal
				if(match("}}}")){
					goto pass0;
				}
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			setBoilerplate(var_code);
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_BoilerplateDirective failed").newline;
			return false;
	}

	/*
	HeaderDirective
		= void setHeader(String code)
		::= Keyword!("header") "{{{" &TOK_STRING:code "}}}";

	*/
	bool parse_HeaderDirective(){
		debug Stdout("parse_HeaderDirective").newline;
		String var_code;

		// AndGroup
			auto position3 = getPos();
				// Production
				if(!parse_Keyword("header")){
					goto fail4;
				}
			term5:
				// Terminal
				if(!match("{{{")){
					goto fail4;
				}
			term6:
				// CustomTerminal
				if(!match(TOK_STRING)){
					goto fail4;
				}
				smartAssign(var_code,getMatchValue!(String)());
			term7:
				// Terminal
				if(match("}}}")){
					goto pass0;
				}
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			setHeader(var_code);
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_HeaderDirective failed").newline;
			return false;
	}

	/*
	UTFDirective
		::= Keyword!("utf") "(" DirectiveArg:value ")" ";";

	*/
	bool parse_UTFDirective(){
		debug Stdout("parse_UTFDirective").newline;
		String var_value;

		// AndGroup
			auto position3 = getPos();
				// Production
				if(!parse_Keyword("utf")){
					goto fail4;
				}
			term5:
				// Terminal
				if(!match("(")){
					goto fail4;
				}
			term6:
				// Production
				if(!parse_DirectiveArg()){
					goto fail4;
				}
				smartAssign(var_value,getMatchValue!(String)());
			term7:
				// Terminal
				if(!match(")")){
					goto fail4;
				}
			term8:
				// Terminal
				if(match(";")){
					goto pass0;
				}
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_UTFDirective failed").newline;
			return false;
	}

	/*
	DirectiveArg
		= String arg
		::= Identifier:arg | &TOK_STRING:arg;

	*/
	bool parse_DirectiveArg(){
		debug Stdout("parse_DirectiveArg").newline;
		String var_arg;

		// OrGroup pass0
			// Production
			if(parse_Identifier()){
				smartAssign(var_arg,getMatchValue!(String)());
				goto pass0;
			}
		term2:
			// CustomTerminal
			if(!match(TOK_STRING)){
				goto fail1;
			}
			smartAssign(var_arg,getMatchValue!(String)());
		// Rule
		pass0:
			setMatchValue(var_arg);
			debug Stdout.format("\tparse_DirectiveArg passed: {0}",getMatchValue!(String)).newline;
			return true;
		fail1:
			setMatchValue((String).init);
			debug Stdout.format("\tparse_DirectiveArg failed").newline;
			return false;
	}
}
