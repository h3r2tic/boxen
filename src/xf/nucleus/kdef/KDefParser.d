module xf.nucleus.kdef.KDefParser;
private {
	import xf.nucleus.Value;
	import xf.nucleus.Code;
	import xf.nucleus.Function;
	import xf.nucleus.kdef.Common;
	import xf.nucleus.kdef.KDefParserBase;
	import xf.nucleus.kernel.KernelDef;
	import xf.nucleus.kernel.KernelImplDef;
	
	alias char[] string;
}
debug import tango.io.Stdout;

class KDefParser:KDefParserBase{
	static char[] getHelp(){
		return "";
	}

	/*
	Syntax
		= void parseSyntax(Statement[] statements)
		::= Statement:~statements* eoi;

	*/
	bool value_Syntax;
	bool parse_Syntax(){
		debug Stdout("parse_Syntax").newline;
		Statement[] var_statements;

		// Iterator
		start2:
			// (terminator)
				// Production
				if(parse_eoi()){
					goto end3;
				}
			// (expression)
			expr4:
				// Production
				if(!parse_Statement()){
					goto fail1;
				}
				smartAppend(var_statements,value_Statement);
			goto start2;
		end3:
		// Rule
		pass0:
			parseSyntax(var_statements);
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_Syntax failed").newline;
			return false;
	}

	/*
	Statement
		= Statement st
		::= PreprocessStatement:st | ImplementStatement:st | ConnectStatement:st | AssignStatement:st | ImportStatement:st | ConverterDeclStatement:st;

	*/
	Statement value_Statement;
	bool parse_Statement(){
		debug Stdout("parse_Statement").newline;
		Statement var_st;

		// OrGroup pass0
			// Production
			if(parse_PreprocessStatement()){
				smartAssign(var_st,value_PreprocessStatement);
				goto pass0;
			}
		term2:
			// Production
			if(parse_ImplementStatement()){
				smartAssign(var_st,value_ImplementStatement);
				goto pass0;
			}
		term3:
			// Production
			if(parse_ConnectStatement()){
				smartAssign(var_st,value_ConnectStatement);
				goto pass0;
			}
		term4:
			// Production
			if(parse_AssignStatement()){
				smartAssign(var_st,value_AssignStatement);
				goto pass0;
			}
		term5:
			// Production
			if(parse_ImportStatement()){
				smartAssign(var_st,value_ImportStatement);
				goto pass0;
			}
		term6:
			// Production
			if(!parse_ConverterDeclStatement()){
				goto fail1;
			}
			smartAssign(var_st,value_ConverterDeclStatement);
		// Rule
		pass0:
			value_Statement = var_st;
			debug Stdout.format("\tparse_Statement passed: {0}",value_Statement).newline;
			return true;
		fail1:
			value_Statement = (Statement).init;
			debug Stdout.format("\tparse_Statement failed").newline;
			return false;
	}

	/*
	ImplementStatement
		= new ImplementStatement(KernelImplDef[] impls,KernelImplementation impl)
		::= "implement" ?!("kernel impl list expected") KernelImpl:~impls* % "," ?!("uh, wanted a kernel implementation") KernelImplementation:impl;

	*/
	ImplementStatement value_ImplementStatement;
	bool parse_ImplementStatement(){
		debug Stdout("parse_ImplementStatement").newline;
		KernelImplDef[] var_impls;
		KernelImplementation var_impl;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("implement")){
					goto fail4;
				}
			term5:
				// ErrorPoint
					// Iterator
					size_t counter11 = 0;
					start7:
						// (terminator)
						if(!hasMore()){
							goto end8;
						}
						// (delimeter)
						delim10:
						if(counter11 > 0){
							// Terminal
							if(!match(",")){
								goto end8;
							}
						}
						// (expression)
						expr9:
							// Production
							if(!parse_KernelImpl()){
								goto end8;
							}
							smartAppend(var_impls,value_KernelImpl);
						increment12:
						// (increment expr count)
							counter11 ++;
						goto start7;
					end8:
						// ErrorPoint
							// Production
							if(parse_KernelImplementation()){
								smartAssign(var_impl,value_KernelImplementation);
								goto pass0;
							}
						fail13:
							error("uh, wanted a kernel implementation");
				fail6:
					error("kernel impl list expected");
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_ImplementStatement = new ImplementStatement(var_impls,var_impl);
			debug Stdout.format("\tparse_ImplementStatement passed: {0}",value_ImplementStatement).newline;
			return true;
		fail1:
			value_ImplementStatement = (ImplementStatement).init;
			debug Stdout.format("\tparse_ImplementStatement failed").newline;
			return false;
	}

	/*
	KernelImpl
		= KernelImplDef parseKernelImpl(string name,double score)
		::= Identifier:name "(" Number:score ")";

	*/
	KernelImplDef value_KernelImpl;
	bool parse_KernelImpl(){
		debug Stdout("parse_KernelImpl").newline;
		string var_name;
		double var_score;

		// AndGroup
			auto position3 = pos;
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAssign(var_name,value_Identifier);
			term5:
				// Terminal
				if(!match("(")){
					goto fail4;
				}
			term6:
				// Production
				if(!parse_Number()){
					goto fail4;
				}
				smartAssign(var_score,value_Number);
			term7:
				// Terminal
				if(match(")")){
					goto pass0;
				}
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_KernelImpl = parseKernelImpl(var_name,var_score);
			debug Stdout.format("\tparse_KernelImpl passed: {0}",value_KernelImpl).newline;
			return true;
		fail1:
			value_KernelImpl = (KernelImplDef).init;
			debug Stdout.format("\tparse_KernelImpl failed").newline;
			return false;
	}

	/*
	ConnectStatement
		= new ConnectStatement(string from,string to)
		::= "connect" Identifier:from Identifier:to ";";

	*/
	ConnectStatement value_ConnectStatement;
	bool parse_ConnectStatement(){
		debug Stdout("parse_ConnectStatement").newline;
		string var_from;
		string var_to;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("connect")){
					goto fail4;
				}
			term5:
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAssign(var_from,value_Identifier);
			term6:
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAssign(var_to,value_Identifier);
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
			value_ConnectStatement = new ConnectStatement(var_from,var_to);
			debug Stdout.format("\tparse_ConnectStatement passed: {0}",value_ConnectStatement).newline;
			return true;
		fail1:
			value_ConnectStatement = (ConnectStatement).init;
			debug Stdout.format("\tparse_ConnectStatement failed").newline;
			return false;
	}

	/*
	AssignStatement
		= new AssignStatement(string name,Value value)
		::= Identifier:name "=" Value:value ?!("\';\' expected") ";";

	*/
	AssignStatement value_AssignStatement;
	bool parse_AssignStatement(){
		debug Stdout("parse_AssignStatement").newline;
		Value var_value;
		string var_name;

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
				if(!parse_Value()){
					goto fail4;
				}
				smartAssign(var_value,value_Value);
			term7:
				// ErrorPoint
					// Terminal
					if(match(";")){
						goto pass0;
					}
				fail8:
					error("\';\' expected");
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_AssignStatement = new AssignStatement(var_name,var_value);
			debug Stdout.format("\tparse_AssignStatement passed: {0}",value_AssignStatement).newline;
			return true;
		fail1:
			value_AssignStatement = (AssignStatement).init;
			debug Stdout.format("\tparse_AssignStatement failed").newline;
			return false;
	}

	/*
	ImportStatement
		= new ImportStatement(string name,string[] what)
		::= "import" String:name [":" WildcardIdentifier:~what* % ","] ";";

	*/
	ImportStatement value_ImportStatement;
	bool parse_ImportStatement(){
		debug Stdout("parse_ImportStatement").newline;
		string var_name;
		string[] var_what;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("import")){
					goto fail4;
				}
			term5:
				// Production
				if(!parse_String()){
					goto fail4;
				}
				smartAssign(var_name,value_String);
			term6:
				// Optional
					// AndGroup
						auto position9 = pos;
							// Terminal
							if(!match(":")){
								goto fail10;
							}
						term11:
							// Iterator
							size_t counter16 = 0;
							start12:
								// (terminator)
								if(!hasMore()){
									goto end13;
								}
								// (delimeter)
								delim15:
								if(counter16 > 0){
									// Terminal
									if(!match(",")){
										goto end13;
									}
								}
								// (expression)
								expr14:
									// Production
									if(!parse_WildcardIdentifier()){
										goto end13;
									}
									smartAppend(var_what,value_WildcardIdentifier);
								increment17:
								// (increment expr count)
									counter16 ++;
								goto start12;
							end13:
								goto term7;
						fail10:
						pos = position9;
						goto term7;
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
			value_ImportStatement = new ImportStatement(var_name,var_what);
			debug Stdout.format("\tparse_ImportStatement passed: {0}",value_ImportStatement).newline;
			return true;
		fail1:
			value_ImportStatement = (ImportStatement).init;
			debug Stdout.format("\tparse_ImportStatement failed").newline;
			return false;
	}

	/*
	WildcardIdentifier
		= string name
		::= (Identifier "*"):name | Identifier:name;

	*/
	string value_WildcardIdentifier;
	bool parse_WildcardIdentifier(){
		debug Stdout("parse_WildcardIdentifier").newline;
		string var_name;

		// OrGroup pass0
			// Group (w/binding)
				auto position3 = pos;
				// AndGroup
					auto position6 = pos;
						// Production
						if(!parse_Identifier()){
							goto fail7;
						}
					term8:
						// Terminal
						if(match("*")){
							goto pass4;
						}
					fail7:
					pos = position6;
					goto term2;
				pass4:
				smartAssign(var_name,slice(position3,pos));
				goto pass0;
		term2:
			// Production
			if(!parse_Identifier()){
				goto fail1;
			}
			smartAssign(var_name,value_Identifier);
		// Rule
		pass0:
			value_WildcardIdentifier = var_name;
			debug Stdout.format("\tparse_WildcardIdentifier passed: {0}",value_WildcardIdentifier).newline;
			return true;
		fail1:
			value_WildcardIdentifier = (string).init;
			debug Stdout.format("\tparse_WildcardIdentifier failed").newline;
			return false;
	}

	/*
	PreprocessStatement
		= new PreprocessStatement(string processor,string processorFunction)
		::= "preprocess" Identifier:processorFunction Identifier:processor ";";

	*/
	PreprocessStatement value_PreprocessStatement;
	bool parse_PreprocessStatement(){
		debug Stdout("parse_PreprocessStatement").newline;
		string var_processor;
		string var_processorFunction;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("preprocess")){
					goto fail4;
				}
			term5:
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAssign(var_processorFunction,value_Identifier);
			term6:
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAssign(var_processor,value_Identifier);
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
			value_PreprocessStatement = new PreprocessStatement(var_processor,var_processorFunction);
			debug Stdout.format("\tparse_PreprocessStatement passed: {0}",value_PreprocessStatement).newline;
			return true;
		fail1:
			value_PreprocessStatement = (PreprocessStatement).init;
			debug Stdout.format("\tparse_PreprocessStatement failed").newline;
			return false;
	}

	/*
	ConverterDeclStatement
		= new ConverterDeclStatement(ParamDef[] params,Code code,string name)
		::= "converter" [Identifier:name] ParamList:params Code:code;

	*/
	ConverterDeclStatement value_ConverterDeclStatement;
	bool parse_ConverterDeclStatement(){
		debug Stdout("parse_ConverterDeclStatement").newline;
		string var_name;
		ParamDef[] var_params;
		Code var_code;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("converter")){
					goto fail4;
				}
			term5:
				// Optional
					// Production
					if(!parse_Identifier()){
						goto term6;
					}
					smartAssign(var_name,value_Identifier);
			term6:
				// Production
				if(!parse_ParamList()){
					goto fail4;
				}
				smartAssign(var_params,value_ParamList);
			term7:
				// Production
				if(parse_Code()){
					smartAssign(var_code,value_Code);
					goto pass0;
				}
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_ConverterDeclStatement = new ConverterDeclStatement(var_params,var_code,var_name);
			debug Stdout.format("\tparse_ConverterDeclStatement passed: {0}",value_ConverterDeclStatement).newline;
			return true;
		fail1:
			value_ConverterDeclStatement = (ConverterDeclStatement).init;
			debug Stdout.format("\tparse_ConverterDeclStatement failed").newline;
			return false;
	}

	/*
	KernelImplementation
		= KernelImplementation impl
		::= QuarkDefValue:impl | GraphDefValue:impl;

	*/
	KernelImplementation value_KernelImplementation;
	bool parse_KernelImplementation(){
		debug Stdout("parse_KernelImplementation").newline;
		KernelImplementation var_impl;

		// OrGroup pass0
			// Production
			if(parse_QuarkDefValue()){
				smartAssign(var_impl,value_QuarkDefValue);
				goto pass0;
			}
		term2:
			// Production
			if(!parse_GraphDefValue()){
				goto fail1;
			}
			smartAssign(var_impl,value_GraphDefValue);
		// Rule
		pass0:
			value_KernelImplementation = var_impl;
			debug Stdout.format("\tparse_KernelImplementation passed: {0}",value_KernelImplementation).newline;
			return true;
		fail1:
			value_KernelImplementation = (KernelImplementation).init;
			debug Stdout.format("\tparse_KernelImplementation failed").newline;
			return false;
	}

	/*
	QuarkDefValue
		= new QuarkDefValue(char[] name,Code[] inlineCode,Function[] quarkFunctions)
		::= "quark" Identifier:name "{" (Code:~inlineCode | Function:~quarkFunctions)* "}";

	*/
	QuarkDefValue value_QuarkDefValue;
	bool parse_QuarkDefValue(){
		debug Stdout("parse_QuarkDefValue").newline;
		char[] var_name;
		Function[] var_quarkFunctions;
		Code[] var_inlineCode;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("quark")){
					goto fail4;
				}
			term5:
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAssign(var_name,value_Identifier);
			term6:
				// Terminal
				if(!match("{")){
					goto fail4;
				}
			term7:
				// Iterator
				start8:
					// (terminator)
						// Terminal
						if(match("}")){
							goto end9;
						}
					// (expression)
					expr10:
						// OrGroup start8
							// Production
							if(parse_Code()){
								smartAppend(var_inlineCode,value_Code);
								goto start8;
							}
						term11:
							// Production
							if(!parse_Function()){
								goto fail4;
							}
							smartAppend(var_quarkFunctions,value_Function);
					goto start8;
				end9:
					goto pass0;
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_QuarkDefValue = new QuarkDefValue(var_name,var_inlineCode,var_quarkFunctions);
			debug Stdout.format("\tparse_QuarkDefValue passed: {0}",value_QuarkDefValue).newline;
			return true;
		fail1:
			value_QuarkDefValue = (QuarkDefValue).init;
			debug Stdout.format("\tparse_QuarkDefValue failed").newline;
			return false;
	}

	/*
	GraphDefValue
		= new GraphDefValue(GraphDef graphDef,string label)
		::= "graph" [Identifier:label] "{" GraphDefBody:graphDef "}";

	*/
	GraphDefValue value_GraphDefValue;
	bool parse_GraphDefValue(){
		debug Stdout("parse_GraphDefValue").newline;
		GraphDef var_graphDef;
		string var_label;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("graph")){
					goto fail4;
				}
			term5:
				// Optional
					// Production
					if(!parse_Identifier()){
						goto term6;
					}
					smartAssign(var_label,value_Identifier);
			term6:
				// Terminal
				if(!match("{")){
					goto fail4;
				}
			term7:
				// Production
				if(!parse_GraphDefBody()){
					goto fail4;
				}
				smartAssign(var_graphDef,value_GraphDefBody);
			term8:
				// Terminal
				if(match("}")){
					goto pass0;
				}
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_GraphDefValue = new GraphDefValue(var_graphDef,var_label);
			debug Stdout.format("\tparse_GraphDefValue passed: {0}",value_GraphDefValue).newline;
			return true;
		fail1:
			value_GraphDefValue = (GraphDefValue).init;
			debug Stdout.format("\tparse_GraphDefValue failed").newline;
			return false;
	}

	/*
	GraphDefBody
		= new GraphDef(Statement[] statements)
		::= Statement:~statements*;

	*/
	GraphDef value_GraphDefBody;
	bool parse_GraphDefBody(){
		debug Stdout("parse_GraphDefBody").newline;
		Statement[] var_statements;

		// Iterator
		start2:
			// (terminator)
			if(!hasMore()){
				goto end3;
			}
			// (expression)
			expr4:
				// Production
				if(!parse_Statement()){
					goto end3;
				}
				smartAppend(var_statements,value_Statement);
			goto start2;
		end3:
		// Rule
		pass0:
			value_GraphDefBody = new GraphDef(var_statements);
			debug Stdout.format("\tparse_GraphDefBody passed: {0}",value_GraphDefBody).newline;
			return true;
		fail1:
			value_GraphDefBody = (GraphDef).init;
			debug Stdout.format("\tparse_GraphDefBody failed").newline;
			return false;
	}

	/*
	KernelDefValue
		= new KernelDefValue(string domain="any",KernelDef kernelDef,string[] bases)
		::= [("gpu" | "cpu"):domain] "kernel" [KernelInheritList:bases] ?!("\'{\' expected") "{" KernelDefBody:kernelDef ?!("\'}\' expected") "}";

	*/
	KernelDefValue value_KernelDefValue;
	bool parse_KernelDefValue(){
		debug Stdout("parse_KernelDefValue").newline;
		KernelDef var_kernelDef;
		string[] var_bases;
		string var_domain = "any";

		// AndGroup
			auto position3 = pos;
				// Optional
					// Group (w/binding)
						auto position6 = pos;
						// OrGroup pass7
							// Terminal
							if(match("gpu")){
								goto pass7;
							}
						term8:
							// Terminal
							if(!match("cpu")){
								goto term5;
							}
						pass7:
						smartAssign(var_domain,slice(position6,pos));
			term5:
				// Terminal
				if(!match("kernel")){
					goto fail4;
				}
			term9:
				// Optional
					// Production
					if(!parse_KernelInheritList()){
						goto term10;
					}
					smartAssign(var_bases,value_KernelInheritList);
			term10:
				// ErrorPoint
					// Terminal
					if(match("{")){
						goto term11;
					}
				fail12:
					error("\'{\' expected");
					goto fail4;
			term11:
				// Production
				if(!parse_KernelDefBody()){
					goto fail4;
				}
				smartAssign(var_kernelDef,value_KernelDefBody);
			term13:
				// ErrorPoint
					// Terminal
					if(match("}")){
						goto pass0;
					}
				fail14:
					error("\'}\' expected");
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_KernelDefValue = new KernelDefValue(var_domain,var_kernelDef,var_bases);
			debug Stdout.format("\tparse_KernelDefValue passed: {0}",value_KernelDefValue).newline;
			return true;
		fail1:
			value_KernelDefValue = (KernelDefValue).init;
			debug Stdout.format("\tparse_KernelDefValue failed").newline;
			return false;
	}

	/*
	GraphDefNodeValue
		= new GraphDefNodeValue(GraphDefNode node)
		::= "node" "{" GraphDefNodeBody:node "}";

	*/
	GraphDefNodeValue value_GraphDefNodeValue;
	bool parse_GraphDefNodeValue(){
		debug Stdout("parse_GraphDefNodeValue").newline;
		GraphDefNode var_node;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("node")){
					goto fail4;
				}
			term5:
				// Terminal
				if(!match("{")){
					goto fail4;
				}
			term6:
				// Production
				if(!parse_GraphDefNodeBody()){
					goto fail4;
				}
				smartAssign(var_node,value_GraphDefNodeBody);
			term7:
				// Terminal
				if(match("}")){
					goto pass0;
				}
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_GraphDefNodeValue = new GraphDefNodeValue(var_node);
			debug Stdout.format("\tparse_GraphDefNodeValue passed: {0}",value_GraphDefNodeValue).newline;
			return true;
		fail1:
			value_GraphDefNodeValue = (GraphDefNodeValue).init;
			debug Stdout.format("\tparse_GraphDefNodeValue failed").newline;
			return false;
	}

	/*
	GraphDefNodeBody
		= new GraphDefNode(VarDef[] variables)
		::= VarDef:~variables*;

	*/
	GraphDefNode value_GraphDefNodeBody;
	bool parse_GraphDefNodeBody(){
		debug Stdout("parse_GraphDefNodeBody").newline;
		VarDef[] var_variables;

		// Iterator
		start2:
			// (terminator)
			if(!hasMore()){
				goto end3;
			}
			// (expression)
			expr4:
				// Production
				if(!parse_VarDef()){
					goto end3;
				}
				smartAppend(var_variables,value_VarDef);
			goto start2;
		end3:
		// Rule
		pass0:
			value_GraphDefNodeBody = new GraphDefNode(var_variables);
			debug Stdout.format("\tparse_GraphDefNodeBody passed: {0}",value_GraphDefNodeBody).newline;
			return true;
		fail1:
			value_GraphDefNodeBody = (GraphDefNode).init;
			debug Stdout.format("\tparse_GraphDefNodeBody failed").newline;
			return false;
	}

	/*
	TraitDefValue
		= new TraitDefValue(string[] values,string defaultValue)
		::= "trait" "{" Identifier:~values % "," "}" ["=" ?!("default value identifier exptected") Identifier:defaultValue];

	*/
	TraitDefValue value_TraitDefValue;
	bool parse_TraitDefValue(){
		debug Stdout("parse_TraitDefValue").newline;
		string[] var_values;
		string var_defaultValue;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("trait")){
					goto fail4;
				}
			term5:
				// Terminal
				if(!match("{")){
					goto fail4;
				}
			term6:
				// Iterator
				size_t counter12 = 0;
				start8:
					// (terminator)
						// Terminal
						if(match("}")){
							goto end9;
						}
					// (delimeter)
					delim11:
					if(counter12 > 0){
						// Terminal
						if(!match(",")){
							goto fail4;
						}
					}
					// (expression)
					expr10:
						// Production
						if(!parse_Identifier()){
							goto fail4;
						}
						smartAppend(var_values,value_Identifier);
					increment13:
					// (increment expr count)
						counter12 ++;
					goto start8;
				end9:
			term7:
				// Optional
					// AndGroup
						auto position15 = pos;
							// Terminal
							if(!match("=")){
								goto fail16;
							}
						term17:
							// ErrorPoint
								// Production
								if(parse_Identifier()){
									smartAssign(var_defaultValue,value_Identifier);
									goto pass0;
								}
							fail18:
								error("default value identifier exptected");
						fail16:
						pos = position15;
					goto pass0;
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_TraitDefValue = new TraitDefValue(var_values,var_defaultValue);
			debug Stdout.format("\tparse_TraitDefValue passed: {0}",value_TraitDefValue).newline;
			return true;
		fail1:
			value_TraitDefValue = (TraitDefValue).init;
			debug Stdout.format("\tparse_TraitDefValue failed").newline;
			return false;
	}

	/*
	Code
		= new Code(string language,Atom[] tokens)
		::= ("D" | "Cg"):language "{" OpaqueCodeBlock:tokens "}";

	*/
	Code value_Code;
	bool parse_Code(){
		debug Stdout("parse_Code").newline;
		Atom[] var_tokens;
		string var_language;

		// AndGroup
			auto position3 = pos;
				// Group (w/binding)
					auto position6 = pos;
					// OrGroup pass7
						// Terminal
						if(match("D")){
							goto pass7;
						}
					term8:
						// Terminal
						if(!match("Cg")){
							goto fail4;
						}
					pass7:
					smartAssign(var_language,slice(position6,pos));
			term5:
				// Terminal
				if(!match("{")){
					goto fail4;
				}
			term9:
				// Production
				if(!parse_OpaqueCodeBlock()){
					goto fail4;
				}
				smartAssign(var_tokens,value_OpaqueCodeBlock);
			term10:
				// Terminal
				if(match("}")){
					goto pass0;
				}
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_Code = new Code(var_language,var_tokens);
			debug Stdout.format("\tparse_Code passed: {0}",value_Code).newline;
			return true;
		fail1:
			value_Code = (Code).init;
			debug Stdout.format("\tparse_Code failed").newline;
			return false;
	}

	/*
	KernelInheritList
		= string[] bases
		::= Identifier:~bases* % ",";

	*/
	string[] value_KernelInheritList;
	bool parse_KernelInheritList(){
		debug Stdout("parse_KernelInheritList").newline;
		string[] var_bases;

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
				if(!match(",")){
					goto end3;
				}
			}
			// (expression)
			expr4:
				// Production
				if(!parse_Identifier()){
					goto end3;
				}
				smartAppend(var_bases,value_Identifier);
			increment7:
			// (increment expr count)
				counter6 ++;
			goto start2;
		end3:
		// Rule
		pass0:
			value_KernelInheritList = var_bases;
			debug Stdout.format("\tparse_KernelInheritList passed: {0}",value_KernelInheritList).newline;
			return true;
		fail1:
			value_KernelInheritList = (string[]).init;
			debug Stdout.format("\tparse_KernelInheritList failed").newline;
			return false;
	}

	/*
	KernelDefBody
		= KernelDef parseKernelDef(AbstractFunction[] funcs,string[] before,string[] after,ParamDef[] attribs)
		$string errSemi="\';\' expected"
		$string errIdent="kernel name expected"
		::= (AbstractFunction:~funcs | "before" ?!(errIdent) Identifier:~before ?!(errSemi) ";" | "after" ?!(errIdent) Identifier:~after ?!(errSemi) ";" | "attribs" "=" ParamList:params ";")*;

	*/
	KernelDef value_KernelDefBody;
	bool parse_KernelDefBody(){
		debug Stdout("parse_KernelDefBody").newline;
		string var_errSemi = "\';\' expected";
		string[] var_before;
		ParamDef[] var_attribs;
		ParamDef[] var_params;
		AbstractFunction[] var_funcs;
		string[] var_after;
		string var_errIdent = "kernel name expected";

		// Iterator
		start2:
			// (terminator)
			if(!hasMore()){
				goto end3;
			}
			// (expression)
			expr4:
				// OrGroup start2
					// Production
					if(parse_AbstractFunction()){
						smartAppend(var_funcs,value_AbstractFunction);
						goto start2;
					}
				term5:
					// AndGroup
						auto position8 = pos;
							// Terminal
							if(!match("before")){
								goto fail9;
							}
						term10:
							// ErrorPoint
								// Production
								if(parse_Identifier()){
									smartAppend(var_before,value_Identifier);
									goto term11;
								}
							fail12:
								error(var_errIdent);
								goto fail9;
						term11:
							// ErrorPoint
								// Terminal
								if(match(";")){
									goto start2;
								}
							fail13:
								error(var_errSemi);
						fail9:
						pos = position8;
				term6:
					// AndGroup
						auto position16 = pos;
							// Terminal
							if(!match("after")){
								goto fail17;
							}
						term18:
							// ErrorPoint
								// Production
								if(parse_Identifier()){
									smartAppend(var_after,value_Identifier);
									goto term19;
								}
							fail20:
								error(var_errIdent);
								goto fail17;
						term19:
							// ErrorPoint
								// Terminal
								if(match(";")){
									goto start2;
								}
							fail21:
								error(var_errSemi);
						fail17:
						pos = position16;
				term14:
					// AndGroup
						auto position23 = pos;
							// Terminal
							if(!match("attribs")){
								goto fail24;
							}
						term25:
							// Terminal
							if(!match("=")){
								goto fail24;
							}
						term26:
							// Production
							if(!parse_ParamList()){
								goto fail24;
							}
							smartAssign(var_params,value_ParamList);
						term27:
							// Terminal
							if(match(";")){
								goto start2;
							}
						fail24:
						pos = position23;
						goto end3;
			goto start2;
		end3:
		// Rule
		pass0:
			value_KernelDefBody = parseKernelDef(var_funcs,var_before,var_after,var_attribs);
			debug Stdout.format("\tparse_KernelDefBody passed: {0}",value_KernelDefBody).newline;
			return true;
		fail1:
			value_KernelDefBody = (KernelDef).init;
			debug Stdout.format("\tparse_KernelDefBody failed").newline;
			return false;
	}

	/*
	AbstractFunction
		= AbstractFunction createAbstractFunction(string name,ParamDef[] params)
		$string semicolonExpected="\';\' expected"
		$string nameExpected="kernel function name expected"
		::= "quark" ?!(nameExpected) Identifier:name ParamList:params ?!(semicolonExpected) ";";

	*/
	AbstractFunction value_AbstractFunction;
	bool parse_AbstractFunction(){
		debug Stdout("parse_AbstractFunction").newline;
		string var_name;
		string var_nameExpected = "kernel function name expected";
		string var_semicolonExpected = "\';\' expected";
		ParamDef[] var_params;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("quark")){
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
					error(var_nameExpected);
					goto fail4;
			term6:
				// Production
				if(!parse_ParamList()){
					goto fail4;
				}
				smartAssign(var_params,value_ParamList);
			term8:
				// ErrorPoint
					// Terminal
					if(match(";")){
						goto pass0;
					}
				fail9:
					error(var_semicolonExpected);
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_AbstractFunction = createAbstractFunction(var_name,var_params);
			debug Stdout.format("\tparse_AbstractFunction passed: {0}",value_AbstractFunction).newline;
			return true;
		fail1:
			value_AbstractFunction = (AbstractFunction).init;
			debug Stdout.format("\tparse_AbstractFunction failed").newline;
			return false;
	}

	/*
	Function
		= Function createFunction(string name,ParamDef[] params,Code code)
		$string semicolonExpected="\';\' expected"
		$string nameExpected="quark function name expected"
		::= "quark" ?!(nameExpected) Identifier:name ParamList:params ?!(semicolonExpected) Code:code;

	*/
	Function value_Function;
	bool parse_Function(){
		debug Stdout("parse_Function").newline;
		string var_name;
		string var_nameExpected = "quark function name expected";
		string var_semicolonExpected = "\';\' expected";
		ParamDef[] var_params;
		Code var_code;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("quark")){
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
					error(var_nameExpected);
					goto fail4;
			term6:
				// Production
				if(!parse_ParamList()){
					goto fail4;
				}
				smartAssign(var_params,value_ParamList);
			term8:
				// ErrorPoint
					// Production
					if(parse_Code()){
						smartAssign(var_code,value_Code);
						goto pass0;
					}
				fail9:
					error(var_semicolonExpected);
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_Function = createFunction(var_name,var_params,var_code);
			debug Stdout.format("\tparse_Function passed: {0}",value_Function).newline;
			return true;
		fail1:
			value_Function = (Function).init;
			debug Stdout.format("\tparse_Function failed").newline;
			return false;
	}

	/*
	OpaqueCodeBlock
		= Atom[] tokens
		::= (&TOK_LITERAL:~tokens | &TOK_STRING:~tokens | &TOK_VERBATIM_STRING:~tokens | &TOK_NUMBER:~tokens | &TOK_IDENT:~tokens | "{":~tokens OpaqueCodeBlock:~tokens "}":~tokens)*;

	*/
	Atom[] value_OpaqueCodeBlock;
	bool parse_OpaqueCodeBlock(){
		debug Stdout("parse_OpaqueCodeBlock").newline;
		Atom[] var_tokens;

		// Iterator
		start2:
			// (terminator)
			if(!hasMore()){
				goto end3;
			}
			// (expression)
			expr4:
				// OrGroup start2
					// CustomTerminal
					if(match(TOK_LITERAL)){
						smartAppend(var_tokens,__match);
						goto start2;
					}
				term5:
					// CustomTerminal
					if(match(TOK_STRING)){
						smartAppend(var_tokens,__match);
						goto start2;
					}
				term6:
					// CustomTerminal
					if(match(TOK_VERBATIM_STRING)){
						smartAppend(var_tokens,__match);
						goto start2;
					}
				term7:
					// CustomTerminal
					if(match(TOK_NUMBER)){
						smartAppend(var_tokens,__match);
						goto start2;
					}
				term8:
					// CustomTerminal
					if(match(TOK_IDENT)){
						smartAppend(var_tokens,__match);
						goto start2;
					}
				term9:
					// AndGroup
						auto position11 = pos;
							// Terminal
							if(!match("{")){
								goto fail12;
							}
							smartAppend(var_tokens,__match);
						term13:
							// Production
							if(!parse_OpaqueCodeBlock()){
								goto fail12;
							}
							smartAppend(var_tokens,value_OpaqueCodeBlock);
						term14:
							// Terminal
							if(match("}")){
								smartAppend(var_tokens,__match);
								goto start2;
							}
						fail12:
						pos = position11;
						goto end3;
			goto start2;
		end3:
		// Rule
		pass0:
			value_OpaqueCodeBlock = var_tokens;
			debug Stdout.format("\tparse_OpaqueCodeBlock passed: {0}",value_OpaqueCodeBlock).newline;
			return true;
		fail1:
			value_OpaqueCodeBlock = (Atom[]).init;
			debug Stdout.format("\tparse_OpaqueCodeBlock failed").newline;
			return false;
	}

	/*
	ParamList
		= ParamDef[] params
		::= "(" Param:~params* % "," ")";

	*/
	ParamDef[] value_ParamList;
	bool parse_ParamList(){
		debug Stdout("parse_ParamList").newline;
		ParamDef[] var_params;

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
			value_ParamList = var_params;
			debug Stdout.format("\tparse_ParamList passed: {0}",value_ParamList).newline;
			return true;
		fail1:
			value_ParamList = (ParamDef[]).init;
			debug Stdout.format("\tparse_ParamList failed").newline;
			return false;
	}

	/*
	Param
		= new ParamDef(string dir="in",string type,ParamSemanticExp semantic,string name,Value defaultValue)
		::= [ParamDirection:dir] ParamType:type Identifier:name ["<" ParamSemantic:semantic ">"] ["=" Value:defaultValue];

	*/
	ParamDef value_Param;
	bool parse_Param(){
		debug Stdout("parse_Param").newline;
		string var_name;
		string var_dir = "in";
		ParamSemanticExp var_semantic;
		string var_type;
		Value var_defaultValue;

		// AndGroup
			auto position3 = pos;
				// Optional
					// Production
					if(!parse_ParamDirection()){
						goto term5;
					}
					smartAssign(var_dir,value_ParamDirection);
			term5:
				// Production
				if(!parse_ParamType()){
					goto fail4;
				}
				smartAssign(var_type,value_ParamType);
			term6:
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAssign(var_name,value_Identifier);
			term7:
				// Optional
					// AndGroup
						auto position10 = pos;
							// Terminal
							if(!match("<")){
								goto fail11;
							}
						term12:
							// Production
							if(!parse_ParamSemantic()){
								goto fail11;
							}
							smartAssign(var_semantic,value_ParamSemantic);
						term13:
							// Terminal
							if(match(">")){
								goto term8;
							}
						fail11:
						pos = position10;
						goto term8;
			term8:
				// Optional
					// AndGroup
						auto position15 = pos;
							// Terminal
							if(!match("=")){
								goto fail16;
							}
						term17:
							// Production
							if(parse_Value()){
								smartAssign(var_defaultValue,value_Value);
								goto pass0;
							}
						fail16:
						pos = position15;
					goto pass0;
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_Param = new ParamDef(var_dir,var_type,var_semantic,var_name,var_defaultValue);
			debug Stdout.format("\tparse_Param passed: {0}",value_Param).newline;
			return true;
		fail1:
			value_Param = (ParamDef).init;
			debug Stdout.format("\tparse_Param failed").newline;
			return false;
	}

	/*
	ParamDirection
		= string dir
		::= "in":dir | "out":dir | "inout":dir | "own":dir;

	*/
	string value_ParamDirection;
	bool parse_ParamDirection(){
		debug Stdout("parse_ParamDirection").newline;
		string var_dir;

		// OrGroup pass0
			// Terminal
			if(match("in")){
				smartAssign(var_dir,__match);
				goto pass0;
			}
		term2:
			// Terminal
			if(match("out")){
				smartAssign(var_dir,__match);
				goto pass0;
			}
		term3:
			// Terminal
			if(match("inout")){
				smartAssign(var_dir,__match);
				goto pass0;
			}
		term4:
			// Terminal
			if(!match("own")){
				goto fail1;
			}
			smartAssign(var_dir,__match);
		// Rule
		pass0:
			value_ParamDirection = var_dir;
			debug Stdout.format("\tparse_ParamDirection passed: {0}",value_ParamDirection).newline;
			return true;
		fail1:
			value_ParamDirection = (string).init;
			debug Stdout.format("\tparse_ParamDirection failed").newline;
			return false;
	}

	/*
	ParamType
		= string type
		::= (Identifier ("[" [ParamType | Number] "]")*):type;

	*/
	string value_ParamType;
	bool parse_ParamType(){
		debug Stdout("parse_ParamType").newline;
		string var_type;

		// Group (w/binding)
			auto position2 = pos;
			// AndGroup
				auto position5 = pos;
					// Production
					if(!parse_Identifier()){
						goto fail6;
					}
				term7:
					// Iterator
					start8:
						// (terminator)
						if(!hasMore()){
							goto end9;
						}
						// (expression)
						expr10:
							// AndGroup
								auto position12 = pos;
									// Terminal
									if(!match("[")){
										goto fail13;
									}
								term14:
									// Optional
										// OrGroup term15
											// Production
											if(parse_ParamType()){
												goto term15;
											}
										term16:
											// Production
											if(!parse_Number()){
												goto term15;
											}
								term15:
									// Terminal
									if(match("]")){
										goto start8;
									}
								fail13:
								pos = position12;
								goto end9;
						goto start8;
					end9:
						goto pass3;
				fail6:
				pos = position5;
				goto fail1;
			pass3:
			smartAssign(var_type,slice(position2,pos));
		// Rule
		pass0:
			value_ParamType = var_type;
			debug Stdout.format("\tparse_ParamType passed: {0}",value_ParamType).newline;
			return true;
		fail1:
			value_ParamType = (string).init;
			debug Stdout.format("\tparse_ParamType failed").newline;
			return false;
	}

	/*
	ParamSemantic
		= ParamSemanticExp value
		::= ParamSemanticSum:value | ParamSemanticExclusion:value | "(" ParamSemantic:value ")" | ParamSemanticTrait:value;

	*/
	ParamSemanticExp value_ParamSemantic;
	bool parse_ParamSemantic(){
		debug Stdout("parse_ParamSemantic").newline;
		ParamSemanticExp var_value;

		// OrGroup pass0
			// Production
			if(parse_ParamSemanticSum()){
				smartAssign(var_value,value_ParamSemanticSum);
				goto pass0;
			}
		term2:
			// Production
			if(parse_ParamSemanticExclusion()){
				smartAssign(var_value,value_ParamSemanticExclusion);
				goto pass0;
			}
		term3:
			// AndGroup
				auto position6 = pos;
					// Terminal
					if(!match("(")){
						goto fail7;
					}
				term8:
					// Production
					if(!parse_ParamSemantic()){
						goto fail7;
					}
					smartAssign(var_value,value_ParamSemantic);
				term9:
					// Terminal
					if(match(")")){
						goto pass0;
					}
				fail7:
				pos = position6;
		term4:
			// Production
			if(!parse_ParamSemanticTrait()){
				goto fail1;
			}
			smartAssign(var_value,value_ParamSemanticTrait);
		// Rule
		pass0:
			value_ParamSemantic = var_value;
			debug Stdout.format("\tparse_ParamSemantic passed: {0}",value_ParamSemantic).newline;
			return true;
		fail1:
			value_ParamSemantic = (ParamSemanticExp).init;
			debug Stdout.format("\tparse_ParamSemantic failed").newline;
			return false;
	}

	/*
	ParamSemanticSum
		= ParamSemanticExp createParamSemanticSum(ParamSemanticExp a,ParamSemanticExp b)
		::= ParamSemantic:a "+" ParamSemantic:b;

	*/
	ParamSemanticExp value_ParamSemanticSum;
	bool parse_ParamSemanticSum(){
		debug Stdout("parse_ParamSemanticSum").newline;
		ParamSemanticExp var_b;
		ParamSemanticExp var_a;

		// AndGroup
			auto position3 = pos;
				// Production
				if(!parse_ParamSemantic()){
					goto fail4;
				}
				smartAssign(var_a,value_ParamSemantic);
			term5:
				// Terminal
				if(!match("+")){
					goto fail4;
				}
			term6:
				// Production
				if(parse_ParamSemantic()){
					smartAssign(var_b,value_ParamSemantic);
					goto pass0;
				}
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_ParamSemanticSum = createParamSemanticSum(var_a,var_b);
			debug Stdout.format("\tparse_ParamSemanticSum passed: {0}",value_ParamSemanticSum).newline;
			return true;
		fail1:
			value_ParamSemanticSum = (ParamSemanticExp).init;
			debug Stdout.format("\tparse_ParamSemanticSum failed").newline;
			return false;
	}

	/*
	ParamSemanticExclusion
		= ParamSemanticExp createParamSemanticExclusion(ParamSemanticExp a,ParamSemanticExp b)
		::= ParamSemantic:a "-" ParamSemantic:b;

	*/
	ParamSemanticExp value_ParamSemanticExclusion;
	bool parse_ParamSemanticExclusion(){
		debug Stdout("parse_ParamSemanticExclusion").newline;
		ParamSemanticExp var_b;
		ParamSemanticExp var_a;

		// AndGroup
			auto position3 = pos;
				// Production
				if(!parse_ParamSemantic()){
					goto fail4;
				}
				smartAssign(var_a,value_ParamSemantic);
			term5:
				// Terminal
				if(!match("-")){
					goto fail4;
				}
			term6:
				// Production
				if(parse_ParamSemantic()){
					smartAssign(var_b,value_ParamSemantic);
					goto pass0;
				}
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_ParamSemanticExclusion = createParamSemanticExclusion(var_a,var_b);
			debug Stdout.format("\tparse_ParamSemanticExclusion passed: {0}",value_ParamSemanticExclusion).newline;
			return true;
		fail1:
			value_ParamSemanticExclusion = (ParamSemanticExp).init;
			debug Stdout.format("\tparse_ParamSemanticExclusion failed").newline;
			return false;
	}

	/*
	ParamSemanticTrait
		= ParamSemanticExp parseParamSemanticTrait(string name,Value value)
		::= (["in" "."] Identifier | "in" "." Identifier "." "actual"):name "=" Value:value;

	*/
	ParamSemanticExp value_ParamSemanticTrait;
	bool parse_ParamSemanticTrait(){
		debug Stdout("parse_ParamSemanticTrait").newline;
		Value var_value;
		string var_name;

		// AndGroup
			auto position3 = pos;
				// Group (w/binding)
					auto position6 = pos;
					// OrGroup pass7
						// AndGroup
							auto position10 = pos;
								// Optional
									// AndGroup
										auto position14 = pos;
											// Terminal
											if(!match("in")){
												goto fail15;
											}
										term16:
											// Terminal
											if(match(".")){
												goto term12;
											}
										fail15:
										pos = position14;
										goto term12;
							term12:
								// Production
								if(parse_Identifier()){
									goto pass7;
								}
							fail11:
							pos = position10;
					term8:
						// AndGroup
							auto position18 = pos;
								// Terminal
								if(!match("in")){
									goto fail19;
								}
							term20:
								// Terminal
								if(!match(".")){
									goto fail19;
								}
							term21:
								// Production
								if(!parse_Identifier()){
									goto fail19;
								}
							term22:
								// Terminal
								if(!match(".")){
									goto fail19;
								}
							term23:
								// Terminal
								if(match("actual")){
									goto pass7;
								}
							fail19:
							pos = position18;
							goto fail4;
					pass7:
					smartAssign(var_name,slice(position6,pos));
			term5:
				// Terminal
				if(!match("=")){
					goto fail4;
				}
			term24:
				// Production
				if(parse_Value()){
					smartAssign(var_value,value_Value);
					goto pass0;
				}
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_ParamSemanticTrait = parseParamSemanticTrait(var_name,var_value);
			debug Stdout.format("\tparse_ParamSemanticTrait passed: {0}",value_ParamSemanticTrait).newline;
			return true;
		fail1:
			value_ParamSemanticTrait = (ParamSemanticExp).init;
			debug Stdout.format("\tparse_ParamSemanticTrait failed").newline;
			return false;
	}

	/*
	VarDef
		= VarDef parseVarDef(string name,Value value)
		::= Identifier:name "=" Value:value ";";

	*/
	VarDef value_VarDef;
	bool parse_VarDef(){
		debug Stdout("parse_VarDef").newline;
		Value var_value;
		string var_name;

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
				if(!parse_Value()){
					goto fail4;
				}
				smartAssign(var_value,value_Value);
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
			value_VarDef = parseVarDef(var_name,var_value);
			debug Stdout.format("\tparse_VarDef passed: {0}",value_VarDef).newline;
			return true;
		fail1:
			value_VarDef = (VarDef).init;
			debug Stdout.format("\tparse_VarDef failed").newline;
			return false;
	}

	/*
	TemplateArg
		= VarDef parseVarDef(string name,Value value)
		::= Identifier:name "=" Value:value;

	*/
	VarDef value_TemplateArg;
	bool parse_TemplateArg(){
		debug Stdout("parse_TemplateArg").newline;
		Value var_value;
		string var_name;

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
				if(parse_Value()){
					smartAssign(var_value,value_Value);
					goto pass0;
				}
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_TemplateArg = parseVarDef(var_name,var_value);
			debug Stdout.format("\tparse_TemplateArg passed: {0}",value_TemplateArg).newline;
			return true;
		fail1:
			value_TemplateArg = (VarDef).init;
			debug Stdout.format("\tparse_TemplateArg failed").newline;
			return false;
	}

	/*
	TemplateArgList
		= VarDef[] list
		::= TemplateArg:~list ("," TemplateArg:~list)*;

	*/
	VarDef[] value_TemplateArgList;
	bool parse_TemplateArgList(){
		debug Stdout("parse_TemplateArgList").newline;
		VarDef[] var_list;

		// AndGroup
			auto position3 = pos;
				// Production
				if(!parse_TemplateArg()){
					goto fail4;
				}
				smartAppend(var_list,value_TemplateArg);
			term5:
				// Iterator
				start6:
					// (terminator)
					if(!hasMore()){
						goto end7;
					}
					// (expression)
					expr8:
						// AndGroup
							auto position10 = pos;
								// Terminal
								if(!match(",")){
									goto fail11;
								}
							term12:
								// Production
								if(parse_TemplateArg()){
									smartAppend(var_list,value_TemplateArg);
									goto start6;
								}
							fail11:
							pos = position10;
							goto end7;
					goto start6;
				end7:
					goto pass0;
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_TemplateArgList = var_list;
			debug Stdout.format("\tparse_TemplateArgList passed: {0}",value_TemplateArgList).newline;
			return true;
		fail1:
			value_TemplateArgList = (VarDef[]).init;
			debug Stdout.format("\tparse_TemplateArgList failed").newline;
			return false;
	}

	/*
	Value
		= Value value
		::= StringValue:value | BooleanValue:value | Vector4Value:value | Vector3Value:value | Vector2Value:value | NumberValue:value | QuarkDefValue:value | KernelDefValue:value | GraphDefValue:value | GraphDefNodeValue:value | TraitDefValue:value | ParamListValue:value | IdentifierValue:value;

	*/
	Value value_Value;
	bool parse_Value(){
		debug Stdout("parse_Value").newline;
		Value var_value;

		// OrGroup pass0
			// Production
			if(parse_StringValue()){
				smartAssign(var_value,value_StringValue);
				goto pass0;
			}
		term2:
			// Production
			if(parse_BooleanValue()){
				smartAssign(var_value,value_BooleanValue);
				goto pass0;
			}
		term3:
			// Production
			if(parse_Vector4Value()){
				smartAssign(var_value,value_Vector4Value);
				goto pass0;
			}
		term4:
			// Production
			if(parse_Vector3Value()){
				smartAssign(var_value,value_Vector3Value);
				goto pass0;
			}
		term5:
			// Production
			if(parse_Vector2Value()){
				smartAssign(var_value,value_Vector2Value);
				goto pass0;
			}
		term6:
			// Production
			if(parse_NumberValue()){
				smartAssign(var_value,value_NumberValue);
				goto pass0;
			}
		term7:
			// Production
			if(parse_QuarkDefValue()){
				smartAssign(var_value,value_QuarkDefValue);
				goto pass0;
			}
		term8:
			// Production
			if(parse_KernelDefValue()){
				smartAssign(var_value,value_KernelDefValue);
				goto pass0;
			}
		term9:
			// Production
			if(parse_GraphDefValue()){
				smartAssign(var_value,value_GraphDefValue);
				goto pass0;
			}
		term10:
			// Production
			if(parse_GraphDefNodeValue()){
				smartAssign(var_value,value_GraphDefNodeValue);
				goto pass0;
			}
		term11:
			// Production
			if(parse_TraitDefValue()){
				smartAssign(var_value,value_TraitDefValue);
				goto pass0;
			}
		term12:
			// Production
			if(parse_ParamListValue()){
				smartAssign(var_value,value_ParamListValue);
				goto pass0;
			}
		term13:
			// Production
			if(!parse_IdentifierValue()){
				goto fail1;
			}
			smartAssign(var_value,value_IdentifierValue);
		// Rule
		pass0:
			value_Value = var_value;
			debug Stdout.format("\tparse_Value passed: {0}",value_Value).newline;
			return true;
		fail1:
			value_Value = (Value).init;
			debug Stdout.format("\tparse_Value failed").newline;
			return false;
	}

	/*
	BooleanValue
		= new BooleanValue(string value)
		::= ("true" | "false"):value;

	*/
	BooleanValue value_BooleanValue;
	bool parse_BooleanValue(){
		debug Stdout("parse_BooleanValue").newline;
		string var_value;

		// Group (w/binding)
			auto position2 = pos;
			// OrGroup pass3
				// Terminal
				if(match("true")){
					goto pass3;
				}
			term4:
				// Terminal
				if(!match("false")){
					goto fail1;
				}
			pass3:
			smartAssign(var_value,slice(position2,pos));
		// Rule
		pass0:
			value_BooleanValue = new BooleanValue(var_value);
			debug Stdout.format("\tparse_BooleanValue passed: {0}",value_BooleanValue).newline;
			return true;
		fail1:
			value_BooleanValue = (BooleanValue).init;
			debug Stdout.format("\tparse_BooleanValue failed").newline;
			return false;
	}

	/*
	IdentifierValue
		= new IdentifierValue(string value)
		::= Identifier:value;

	*/
	IdentifierValue value_IdentifierValue;
	bool parse_IdentifierValue(){
		debug Stdout("parse_IdentifierValue").newline;
		string var_value;

		// Production
		if(!parse_Identifier()){
			goto fail1;
		}
		smartAssign(var_value,value_Identifier);
		// Rule
		pass0:
			value_IdentifierValue = new IdentifierValue(var_value);
			debug Stdout.format("\tparse_IdentifierValue passed: {0}",value_IdentifierValue).newline;
			return true;
		fail1:
			value_IdentifierValue = (IdentifierValue).init;
			debug Stdout.format("\tparse_IdentifierValue failed").newline;
			return false;
	}

	/*
	NumberValue
		= new NumberValue(double value)
		::= Number:value;

	*/
	NumberValue value_NumberValue;
	bool parse_NumberValue(){
		debug Stdout("parse_NumberValue").newline;
		double var_value;

		// Production
		if(!parse_Number()){
			goto fail1;
		}
		smartAssign(var_value,value_Number);
		// Rule
		pass0:
			value_NumberValue = new NumberValue(var_value);
			debug Stdout.format("\tparse_NumberValue passed: {0}",value_NumberValue).newline;
			return true;
		fail1:
			value_NumberValue = (NumberValue).init;
			debug Stdout.format("\tparse_NumberValue failed").newline;
			return false;
	}

	/*
	Vector2Value
		= new Vector2Value(double x,double y)
		::= Number:x Number:y;

	*/
	Vector2Value value_Vector2Value;
	bool parse_Vector2Value(){
		debug Stdout("parse_Vector2Value").newline;
		double var_x;
		double var_y;

		// AndGroup
			auto position3 = pos;
				// Production
				if(!parse_Number()){
					goto fail4;
				}
				smartAssign(var_x,value_Number);
			term5:
				// Production
				if(parse_Number()){
					smartAssign(var_y,value_Number);
					goto pass0;
				}
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_Vector2Value = new Vector2Value(var_x,var_y);
			debug Stdout.format("\tparse_Vector2Value passed: {0}",value_Vector2Value).newline;
			return true;
		fail1:
			value_Vector2Value = (Vector2Value).init;
			debug Stdout.format("\tparse_Vector2Value failed").newline;
			return false;
	}

	/*
	Vector3Value
		= new Vector3Value(double x,double y,double z)
		::= Number:x Number:y Number:z;

	*/
	Vector3Value value_Vector3Value;
	bool parse_Vector3Value(){
		debug Stdout("parse_Vector3Value").newline;
		double var_z;
		double var_x;
		double var_y;

		// AndGroup
			auto position3 = pos;
				// Production
				if(!parse_Number()){
					goto fail4;
				}
				smartAssign(var_x,value_Number);
			term5:
				// Production
				if(!parse_Number()){
					goto fail4;
				}
				smartAssign(var_y,value_Number);
			term6:
				// Production
				if(parse_Number()){
					smartAssign(var_z,value_Number);
					goto pass0;
				}
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_Vector3Value = new Vector3Value(var_x,var_y,var_z);
			debug Stdout.format("\tparse_Vector3Value passed: {0}",value_Vector3Value).newline;
			return true;
		fail1:
			value_Vector3Value = (Vector3Value).init;
			debug Stdout.format("\tparse_Vector3Value failed").newline;
			return false;
	}

	/*
	Vector4Value
		= new Vector4Value(double x,double y,double z,double w)
		::= Number:x Number:y Number:z Number:w;

	*/
	Vector4Value value_Vector4Value;
	bool parse_Vector4Value(){
		debug Stdout("parse_Vector4Value").newline;
		double var_z;
		double var_w;
		double var_x;
		double var_y;

		// AndGroup
			auto position3 = pos;
				// Production
				if(!parse_Number()){
					goto fail4;
				}
				smartAssign(var_x,value_Number);
			term5:
				// Production
				if(!parse_Number()){
					goto fail4;
				}
				smartAssign(var_y,value_Number);
			term6:
				// Production
				if(!parse_Number()){
					goto fail4;
				}
				smartAssign(var_z,value_Number);
			term7:
				// Production
				if(parse_Number()){
					smartAssign(var_w,value_Number);
					goto pass0;
				}
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_Vector4Value = new Vector4Value(var_x,var_y,var_z,var_w);
			debug Stdout.format("\tparse_Vector4Value passed: {0}",value_Vector4Value).newline;
			return true;
		fail1:
			value_Vector4Value = (Vector4Value).init;
			debug Stdout.format("\tparse_Vector4Value failed").newline;
			return false;
	}

	/*
	StringValue
		= new StringValue(char[] value)
		::= &TOK_STRING:value;

	*/
	StringValue value_StringValue;
	bool parse_StringValue(){
		debug Stdout("parse_StringValue").newline;
		char[] var_value;

		// CustomTerminal
		if(!match(TOK_STRING)){
			goto fail1;
		}
		smartAssign(var_value,__match);
		// Rule
		pass0:
			value_StringValue = new StringValue(var_value);
			debug Stdout.format("\tparse_StringValue passed: {0}",value_StringValue).newline;
			return true;
		fail1:
			value_StringValue = (StringValue).init;
			debug Stdout.format("\tparse_StringValue failed").newline;
			return false;
	}

	/*
	ParamListValue
		= new ParamListValue(ParamDef[] params)
		::= ParamList:params;

	*/
	ParamListValue value_ParamListValue;
	bool parse_ParamListValue(){
		debug Stdout("parse_ParamListValue").newline;
		ParamDef[] var_params;

		// Production
		if(!parse_ParamList()){
			goto fail1;
		}
		smartAssign(var_params,value_ParamList);
		// Rule
		pass0:
			value_ParamListValue = new ParamListValue(var_params);
			debug Stdout.format("\tparse_ParamListValue passed: {0}",value_ParamListValue).newline;
			return true;
		fail1:
			value_ParamListValue = (ParamListValue).init;
			debug Stdout.format("\tparse_ParamListValue failed").newline;
			return false;
	}

	/*
	Identifier
		= string concatTokens(Atom[] value)
		::= ({&TOK_IDENT} % "."):value;

	*/
	string value_Identifier;
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
			value_Identifier = (string).init;
			debug Stdout.format("\tparse_Identifier failed").newline;
			return false;
	}

	/*
	Number
		= double parseDouble(char[] value)
		::= &TOK_NUMBER:value;

	*/
	double value_Number;
	bool parse_Number(){
		debug Stdout("parse_Number").newline;
		char[] var_value;

		// CustomTerminal
		if(!match(TOK_NUMBER)){
			goto fail1;
		}
		smartAssign(var_value,__match);
		// Rule
		pass0:
			value_Number = parseDouble(var_value);
			debug Stdout.format("\tparse_Number passed: {0}",value_Number).newline;
			return true;
		fail1:
			value_Number = (double).init;
			debug Stdout.format("\tparse_Number failed").newline;
			return false;
	}

	/*
	String
		= string value
		::= &TOK_STRING:value;

	*/
	string value_String;
	bool parse_String(){
		debug Stdout("parse_String").newline;
		string var_value;

		// CustomTerminal
		if(!match(TOK_STRING)){
			goto fail1;
		}
		smartAssign(var_value,__match);
		// Rule
		pass0:
			value_String = var_value;
			debug Stdout.format("\tparse_String passed: {0}",value_String).newline;
			return true;
		fail1:
			value_String = (string).init;
			debug Stdout.format("\tparse_String failed").newline;
			return false;
	}
}
