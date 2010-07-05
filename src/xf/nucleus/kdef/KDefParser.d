module xf.nucleus.kdef.KDefParser;
private {
	import xf.nucleus.Value;
	import xf.nucleus.Code;
	import xf.nucleus.kdef.KDefToken;
	import xf.nucleus.Function;
	import xf.nucleus.kdef.Common;
	import xf.nucleus.kdef.KDefParserBase;
	import xf.nucleus.kernel.KernelDef;
	
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
		::= AssignStatement:st | ImportStatement:st | ConnectStatement:st | ConverterDeclStatement:st;

	*/
	Statement value_Statement;
	bool parse_Statement(){
		debug Stdout("parse_Statement").newline;
		Statement var_st;

		// OrGroup pass0
			// Production
			if(parse_AssignStatement()){
				smartAssign(var_st,value_AssignStatement);
				goto pass0;
			}
		term2:
			// Production
			if(parse_ImportStatement()){
				smartAssign(var_st,value_ImportStatement);
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
	ConnectStatement
		= ConnectStatement createConnectStatement(string from,string to)
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
			value_ConnectStatement = createConnectStatement(var_from,var_to);
			debug Stdout.format("\tparse_ConnectStatement passed: {0}",value_ConnectStatement).newline;
			return true;
		fail1:
			value_ConnectStatement = (ConnectStatement).init;
			debug Stdout.format("\tparse_ConnectStatement failed").newline;
			return false;
	}

	/*
	AssignStatement
		= AssignStatement createAssignStatement(string name,Value value)
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
			value_AssignStatement = createAssignStatement(var_name,var_value);
			debug Stdout.format("\tparse_AssignStatement passed: {0}",value_AssignStatement).newline;
			return true;
		fail1:
			value_AssignStatement = (AssignStatement).init;
			debug Stdout.format("\tparse_AssignStatement failed").newline;
			return false;
	}

	/*
	ImportStatement
		= ImportStatement createImportStatement(string name,string[] what)
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
			value_ImportStatement = createImportStatement(var_name,var_what);
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
	ConverterDeclStatement
		= ConverterDeclStatement createConverter(string name,string[] tags,ParamDef[] params,Code code,double cost)
		::= "converter" ["<" KernelTagList:tags ">"] "(" Number:cost ")" [Identifier:name] ParamList:params Code:code;

	*/
	ConverterDeclStatement value_ConverterDeclStatement;
	bool parse_ConverterDeclStatement(){
		debug Stdout("parse_ConverterDeclStatement").newline;
		string var_name;
		double var_cost;
		string[] var_tags;
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
					// AndGroup
						auto position8 = pos;
							// Terminal
							if(!match("<")){
								goto fail9;
							}
						term10:
							// Production
							if(!parse_KernelTagList()){
								goto fail9;
							}
							smartAssign(var_tags,value_KernelTagList);
						term11:
							// Terminal
							if(match(">")){
								goto term6;
							}
						fail9:
						pos = position8;
						goto term6;
			term6:
				// Terminal
				if(!match("(")){
					goto fail4;
				}
			term12:
				// Production
				if(!parse_Number()){
					goto fail4;
				}
				smartAssign(var_cost,value_Number);
			term13:
				// Terminal
				if(!match(")")){
					goto fail4;
				}
			term14:
				// Optional
					// Production
					if(!parse_Identifier()){
						goto term15;
					}
					smartAssign(var_name,value_Identifier);
			term15:
				// Production
				if(!parse_ParamList()){
					goto fail4;
				}
				smartAssign(var_params,value_ParamList);
			term16:
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
			value_ConverterDeclStatement = createConverter(var_name,var_tags,var_params,var_code,var_cost);
			debug Stdout.format("\tparse_ConverterDeclStatement passed: {0}",value_ConverterDeclStatement).newline;
			return true;
		fail1:
			value_ConverterDeclStatement = (ConverterDeclStatement).init;
			debug Stdout.format("\tparse_ConverterDeclStatement failed").newline;
			return false;
	}

	/*
	KernelDefValue
		= KernelDefValue value
		::= ConcreteKernelDefValue:value | AbstractKernelDefValue:value;

	*/
	KernelDefValue value_KernelDefValue;
	bool parse_KernelDefValue(){
		debug Stdout("parse_KernelDefValue").newline;
		KernelDefValue var_value;

		// OrGroup pass0
			// Production
			if(parse_ConcreteKernelDefValue()){
				smartAssign(var_value,value_ConcreteKernelDefValue);
				goto pass0;
			}
		term2:
			// Production
			if(!parse_AbstractKernelDefValue()){
				goto fail1;
			}
			smartAssign(var_value,value_AbstractKernelDefValue);
		// Rule
		pass0:
			value_KernelDefValue = var_value;
			debug Stdout.format("\tparse_KernelDefValue passed: {0}",value_KernelDefValue).newline;
			return true;
		fail1:
			value_KernelDefValue = (KernelDefValue).init;
			debug Stdout.format("\tparse_KernelDefValue failed").newline;
			return false;
	}

	/*
	ConcreteKernelDefValue
		= KernelDefValue createKernelDefValue(string superKernel,ParamDef[] params,Code code,string[] tags)
		::= "kernel" ["<" KernelTagList:tags ">"] [Identifier:superKernel] [ParamList:params] Code:code;

	*/
	KernelDefValue value_ConcreteKernelDefValue;
	bool parse_ConcreteKernelDefValue(){
		debug Stdout("parse_ConcreteKernelDefValue").newline;
		string[] var_tags;
		ParamDef[] var_params;
		string var_superKernel;
		Code var_code;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("kernel")){
					goto fail4;
				}
			term5:
				// Optional
					// AndGroup
						auto position8 = pos;
							// Terminal
							if(!match("<")){
								goto fail9;
							}
						term10:
							// Production
							if(!parse_KernelTagList()){
								goto fail9;
							}
							smartAssign(var_tags,value_KernelTagList);
						term11:
							// Terminal
							if(match(">")){
								goto term6;
							}
						fail9:
						pos = position8;
						goto term6;
			term6:
				// Optional
					// Production
					if(!parse_Identifier()){
						goto term12;
					}
					smartAssign(var_superKernel,value_Identifier);
			term12:
				// Optional
					// Production
					if(!parse_ParamList()){
						goto term13;
					}
					smartAssign(var_params,value_ParamList);
			term13:
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
			value_ConcreteKernelDefValue = createKernelDefValue(var_superKernel,var_params,var_code,var_tags);
			debug Stdout.format("\tparse_ConcreteKernelDefValue passed: {0}",value_ConcreteKernelDefValue).newline;
			return true;
		fail1:
			value_ConcreteKernelDefValue = (KernelDefValue).init;
			debug Stdout.format("\tparse_ConcreteKernelDefValue failed").newline;
			return false;
	}

	/*
	AbstractKernelDefValue
		= KernelDefValue createKernelDefValue(string superKernel,ParamDef[] params,Code code,string[] tags)
		::= "kernel" ["<" KernelTagList:tags ">"] [Identifier:superKernel] ParamList:params;

	*/
	KernelDefValue value_AbstractKernelDefValue;
	bool parse_AbstractKernelDefValue(){
		debug Stdout("parse_AbstractKernelDefValue").newline;
		string[] var_tags;
		ParamDef[] var_params;
		string var_superKernel;
		Code var_code;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("kernel")){
					goto fail4;
				}
			term5:
				// Optional
					// AndGroup
						auto position8 = pos;
							// Terminal
							if(!match("<")){
								goto fail9;
							}
						term10:
							// Production
							if(!parse_KernelTagList()){
								goto fail9;
							}
							smartAssign(var_tags,value_KernelTagList);
						term11:
							// Terminal
							if(match(">")){
								goto term6;
							}
						fail9:
						pos = position8;
						goto term6;
			term6:
				// Optional
					// Production
					if(!parse_Identifier()){
						goto term12;
					}
					smartAssign(var_superKernel,value_Identifier);
			term12:
				// Production
				if(parse_ParamList()){
					smartAssign(var_params,value_ParamList);
					goto pass0;
				}
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_AbstractKernelDefValue = createKernelDefValue(var_superKernel,var_params,var_code,var_tags);
			debug Stdout.format("\tparse_AbstractKernelDefValue passed: {0}",value_AbstractKernelDefValue).newline;
			return true;
		fail1:
			value_AbstractKernelDefValue = (KernelDefValue).init;
			debug Stdout.format("\tparse_AbstractKernelDefValue failed").newline;
			return false;
	}

	/*
	GraphDefValue
		= GraphDefValue createGraphDefValue(string superKernel,Statement[] stmts,string[] tags)
		::= "graph" ["<" KernelTagList:tags ">"] [Identifier:superKernel] "{" Statement:~stmts* "}";

	*/
	GraphDefValue value_GraphDefValue;
	bool parse_GraphDefValue(){
		debug Stdout("parse_GraphDefValue").newline;
		string[] var_tags;
		Statement[] var_stmts;
		string var_superKernel;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("graph")){
					goto fail4;
				}
			term5:
				// Optional
					// AndGroup
						auto position8 = pos;
							// Terminal
							if(!match("<")){
								goto fail9;
							}
						term10:
							// Production
							if(!parse_KernelTagList()){
								goto fail9;
							}
							smartAssign(var_tags,value_KernelTagList);
						term11:
							// Terminal
							if(match(">")){
								goto term6;
							}
						fail9:
						pos = position8;
						goto term6;
			term6:
				// Optional
					// Production
					if(!parse_Identifier()){
						goto term12;
					}
					smartAssign(var_superKernel,value_Identifier);
			term12:
				// Terminal
				if(!match("{")){
					goto fail4;
				}
			term13:
				// Iterator
				start14:
					// (terminator)
						// Terminal
						if(match("}")){
							goto end15;
						}
					// (expression)
					expr16:
						// Production
						if(!parse_Statement()){
							goto fail4;
						}
						smartAppend(var_stmts,value_Statement);
					goto start14;
				end15:
					goto pass0;
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_GraphDefValue = createGraphDefValue(var_superKernel,var_stmts,var_tags);
			debug Stdout.format("\tparse_GraphDefValue passed: {0}",value_GraphDefValue).newline;
			return true;
		fail1:
			value_GraphDefValue = (GraphDefValue).init;
			debug Stdout.format("\tparse_GraphDefValue failed").newline;
			return false;
	}

	/*
	GraphDefNodeValue
		= GraphDefNodeValue createGraphDefNodeValue(VarDef[] vars)
		::= "node" "{" VarDef:~vars* "}";

	*/
	GraphDefNodeValue value_GraphDefNodeValue;
	bool parse_GraphDefNodeValue(){
		debug Stdout("parse_GraphDefNodeValue").newline;
		VarDef[] var_vars;

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
				// Iterator
				start7:
					// (terminator)
						// Terminal
						if(match("}")){
							goto end8;
						}
					// (expression)
					expr9:
						// Production
						if(!parse_VarDef()){
							goto fail4;
						}
						smartAppend(var_vars,value_VarDef);
					goto start7;
				end8:
					goto pass0;
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_GraphDefNodeValue = createGraphDefNodeValue(var_vars);
			debug Stdout.format("\tparse_GraphDefNodeValue passed: {0}",value_GraphDefNodeValue).newline;
			return true;
		fail1:
			value_GraphDefNodeValue = (GraphDefNodeValue).init;
			debug Stdout.format("\tparse_GraphDefNodeValue failed").newline;
			return false;
	}

	/*
	TraitDefValue
		= TraitDefValue createTraitDefValue(string[] values,string defaultValue)
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
			value_TraitDefValue = createTraitDefValue(var_values,var_defaultValue);
			debug Stdout.format("\tparse_TraitDefValue passed: {0}",value_TraitDefValue).newline;
			return true;
		fail1:
			value_TraitDefValue = (TraitDefValue).init;
			debug Stdout.format("\tparse_TraitDefValue failed").newline;
			return false;
	}

	/*
	SurfaceDefValue
		= SurfaceDefValue createSurfaceDefValue(string illumKernel,VarDef[] vars)
		::= "surface" Identifier:illumKernel "{" VarDef:~vars* "}";

	*/
	SurfaceDefValue value_SurfaceDefValue;
	bool parse_SurfaceDefValue(){
		debug Stdout("parse_SurfaceDefValue").newline;
		string var_illumKernel;
		VarDef[] var_vars;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("surface")){
					goto fail4;
				}
			term5:
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAssign(var_illumKernel,value_Identifier);
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
						// Production
						if(!parse_VarDef()){
							goto fail4;
						}
						smartAppend(var_vars,value_VarDef);
					goto start8;
				end9:
					goto pass0;
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_SurfaceDefValue = createSurfaceDefValue(var_illumKernel,var_vars);
			debug Stdout.format("\tparse_SurfaceDefValue passed: {0}",value_SurfaceDefValue).newline;
			return true;
		fail1:
			value_SurfaceDefValue = (SurfaceDefValue).init;
			debug Stdout.format("\tparse_SurfaceDefValue failed").newline;
			return false;
	}

	/*
	MaterialDefValue
		= MaterialDefValue createMaterialDefValue(string pigmentKernel,VarDef[] vars)
		::= "material" Identifier:pigmentKernel "{" VarDef:~vars* "}";

	*/
	MaterialDefValue value_MaterialDefValue;
	bool parse_MaterialDefValue(){
		debug Stdout("parse_MaterialDefValue").newline;
		string var_pigmentKernel;
		VarDef[] var_vars;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("material")){
					goto fail4;
				}
			term5:
				// Production
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAssign(var_pigmentKernel,value_Identifier);
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
						// Production
						if(!parse_VarDef()){
							goto fail4;
						}
						smartAppend(var_vars,value_VarDef);
					goto start8;
				end9:
					goto pass0;
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_MaterialDefValue = createMaterialDefValue(var_pigmentKernel,var_vars);
			debug Stdout.format("\tparse_MaterialDefValue passed: {0}",value_MaterialDefValue).newline;
			return true;
		fail1:
			value_MaterialDefValue = (MaterialDefValue).init;
			debug Stdout.format("\tparse_MaterialDefValue failed").newline;
			return false;
	}

	/*
	SamplerDefValue
		= SamplerDefValue createSamplerDefValue(VarDef[] vars)
		::= "sampler" "{" VarDef:~vars* "}";

	*/
	SamplerDefValue value_SamplerDefValue;
	bool parse_SamplerDefValue(){
		debug Stdout("parse_SamplerDefValue").newline;
		VarDef[] var_vars;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("sampler")){
					goto fail4;
				}
			term5:
				// Terminal
				if(!match("{")){
					goto fail4;
				}
			term6:
				// Iterator
				start7:
					// (terminator)
						// Terminal
						if(match("}")){
							goto end8;
						}
					// (expression)
					expr9:
						// Production
						if(!parse_VarDef()){
							goto fail4;
						}
						smartAppend(var_vars,value_VarDef);
					goto start7;
				end8:
					goto pass0;
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_SamplerDefValue = createSamplerDefValue(var_vars);
			debug Stdout.format("\tparse_SamplerDefValue passed: {0}",value_SamplerDefValue).newline;
			return true;
		fail1:
			value_SamplerDefValue = (SamplerDefValue).init;
			debug Stdout.format("\tparse_SamplerDefValue failed").newline;
			return false;
	}

	/*
	Code
		= Code createCode(Atom[] tokens)
		::= "{" OpaqueCodeBlock:tokens "}";

	*/
	Code value_Code;
	bool parse_Code(){
		debug Stdout("parse_Code").newline;
		Atom[] var_tokens;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("{")){
					goto fail4;
				}
			term5:
				// Production
				if(!parse_OpaqueCodeBlock()){
					goto fail4;
				}
				smartAssign(var_tokens,value_OpaqueCodeBlock);
			term6:
				// Terminal
				if(match("}")){
					goto pass0;
				}
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_Code = createCode(var_tokens);
			debug Stdout.format("\tparse_Code passed: {0}",value_Code).newline;
			return true;
		fail1:
			value_Code = (Code).init;
			debug Stdout.format("\tparse_Code failed").newline;
			return false;
	}

	/*
	KernelTagList
		= string[] tags
		::= Identifier:~tags*;

	*/
	string[] value_KernelTagList;
	bool parse_KernelTagList(){
		debug Stdout("parse_KernelTagList").newline;
		string[] var_tags;

		// Iterator
		start2:
			// (terminator)
			if(!hasMore()){
				goto end3;
			}
			// (expression)
			expr4:
				// Production
				if(!parse_Identifier()){
					goto end3;
				}
				smartAppend(var_tags,value_Identifier);
			goto start2;
		end3:
		// Rule
		pass0:
			value_KernelTagList = var_tags;
			debug Stdout.format("\tparse_KernelTagList passed: {0}",value_KernelTagList).newline;
			return true;
		fail1:
			value_KernelTagList = (string[]).init;
			debug Stdout.format("\tparse_KernelTagList failed").newline;
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
		::= "(" (Param:~params* % ",") [","] ")";

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
						if(!parse_Param()){
							goto end8;
						}
						smartAppend(var_params,value_Param);
					increment12:
					// (increment expr count)
						counter11 ++;
					goto start7;
				end8:
			term6:
				// Optional
					// Terminal
					if(!match(",")){
						goto term13;
					}
			term13:
				// Terminal
				if(match(")")){
					goto pass0;
				}
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
		= ParamDef createParamDef(string dir="in",string type,ParamSemanticExp semantic,string name,Value defaultValue)
		::= [ParamDirection:dir] Identifier:name ["<" [ParamSemantic:semantic] ">"] ["=" Value:defaultValue];

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
				if(!parse_Identifier()){
					goto fail4;
				}
				smartAssign(var_name,value_Identifier);
			term6:
				// Optional
					// AndGroup
						auto position9 = pos;
							// Terminal
							if(!match("<")){
								goto fail10;
							}
						term11:
							// Optional
								// Production
								if(!parse_ParamSemantic()){
									goto term12;
								}
								smartAssign(var_semantic,value_ParamSemantic);
						term12:
							// Terminal
							if(match(">")){
								goto term7;
							}
						fail10:
						pos = position9;
						goto term7;
			term7:
				// Optional
					// AndGroup
						auto position14 = pos;
							// Terminal
							if(!match("=")){
								goto fail15;
							}
						term16:
							// Production
							if(parse_Value()){
								smartAssign(var_defaultValue,value_Value);
								goto pass0;
							}
						fail15:
						pos = position14;
					goto pass0;
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_Param = createParamDef(var_dir,var_type,var_semantic,var_name,var_defaultValue);
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
		::= (ParamSemanticTrait:a | "(" ParamSemantic:a ")") "+" ParamSemantic:b;

	*/
	ParamSemanticExp value_ParamSemanticSum;
	bool parse_ParamSemanticSum(){
		debug Stdout("parse_ParamSemanticSum").newline;
		ParamSemanticExp var_b;
		ParamSemanticExp var_a;

		// AndGroup
			auto position3 = pos;
				// OrGroup term5
					// Production
					if(parse_ParamSemanticTrait()){
						smartAssign(var_a,value_ParamSemanticTrait);
						goto term5;
					}
				term6:
					// AndGroup
						auto position8 = pos;
							// Terminal
							if(!match("(")){
								goto fail9;
							}
						term10:
							// Production
							if(!parse_ParamSemantic()){
								goto fail9;
							}
							smartAssign(var_a,value_ParamSemantic);
						term11:
							// Terminal
							if(match(")")){
								goto term5;
							}
						fail9:
						pos = position8;
						goto fail4;
			term5:
				// Terminal
				if(!match("+")){
					goto fail4;
				}
			term12:
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
		::= (ParamSemanticTrait:a | "(" ParamSemantic:a ")") "-" ParamSemantic:b;

	*/
	ParamSemanticExp value_ParamSemanticExclusion;
	bool parse_ParamSemanticExclusion(){
		debug Stdout("parse_ParamSemanticExclusion").newline;
		ParamSemanticExp var_b;
		ParamSemanticExp var_a;

		// AndGroup
			auto position3 = pos;
				// OrGroup term5
					// Production
					if(parse_ParamSemanticTrait()){
						smartAssign(var_a,value_ParamSemanticTrait);
						goto term5;
					}
				term6:
					// AndGroup
						auto position8 = pos;
							// Terminal
							if(!match("(")){
								goto fail9;
							}
						term10:
							// Production
							if(!parse_ParamSemantic()){
								goto fail9;
							}
							smartAssign(var_a,value_ParamSemantic);
						term11:
							// Terminal
							if(match(")")){
								goto term5;
							}
						fail9:
						pos = position8;
						goto fail4;
			term5:
				// Terminal
				if(!match("-")){
					goto fail4;
				}
			term12:
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
		::= (["in" "."] Identifier | "in" "." Identifier "." "actual"):name [Value:value];

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
				// Optional
					// Production
					if(parse_Value()){
						smartAssign(var_value,value_Value);
						goto pass0;
					}
					goto pass0;
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
	Value
		= Value value
		::= StringValue:value | BooleanValue:value | Vector4Value:value | Vector3Value:value | Vector2Value:value | NumberValue:value | KernelDefValue:value | GraphDefValue:value | GraphDefNodeValue:value | TraitDefValue:value | SurfaceDefValue:value | MaterialDefValue:value | SamplerDefValue:value | ParamListValue:value | IdentifierValue:value;

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
			if(parse_KernelDefValue()){
				smartAssign(var_value,value_KernelDefValue);
				goto pass0;
			}
		term8:
			// Production
			if(parse_GraphDefValue()){
				smartAssign(var_value,value_GraphDefValue);
				goto pass0;
			}
		term9:
			// Production
			if(parse_GraphDefNodeValue()){
				smartAssign(var_value,value_GraphDefNodeValue);
				goto pass0;
			}
		term10:
			// Production
			if(parse_TraitDefValue()){
				smartAssign(var_value,value_TraitDefValue);
				goto pass0;
			}
		term11:
			// Production
			if(parse_SurfaceDefValue()){
				smartAssign(var_value,value_SurfaceDefValue);
				goto pass0;
			}
		term12:
			// Production
			if(parse_MaterialDefValue()){
				smartAssign(var_value,value_MaterialDefValue);
				goto pass0;
			}
		term13:
			// Production
			if(parse_SamplerDefValue()){
				smartAssign(var_value,value_SamplerDefValue);
				goto pass0;
			}
		term14:
			// Production
			if(parse_ParamListValue()){
				smartAssign(var_value,value_ParamListValue);
				goto pass0;
			}
		term15:
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
		= BooleanValue createBooleanValue(string value)
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
			value_BooleanValue = createBooleanValue(var_value);
			debug Stdout.format("\tparse_BooleanValue passed: {0}",value_BooleanValue).newline;
			return true;
		fail1:
			value_BooleanValue = (BooleanValue).init;
			debug Stdout.format("\tparse_BooleanValue failed").newline;
			return false;
	}

	/*
	IdentifierValue
		= IdentifierValue createIdentifierValue(string value)
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
			value_IdentifierValue = createIdentifierValue(var_value);
			debug Stdout.format("\tparse_IdentifierValue passed: {0}",value_IdentifierValue).newline;
			return true;
		fail1:
			value_IdentifierValue = (IdentifierValue).init;
			debug Stdout.format("\tparse_IdentifierValue failed").newline;
			return false;
	}

	/*
	NumberValue
		= NumberValue createNumberValue(double value)
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
			value_NumberValue = createNumberValue(var_value);
			debug Stdout.format("\tparse_NumberValue passed: {0}",value_NumberValue).newline;
			return true;
		fail1:
			value_NumberValue = (NumberValue).init;
			debug Stdout.format("\tparse_NumberValue failed").newline;
			return false;
	}

	/*
	Vector2Value
		= Vector2Value createVector2Value(double x,double y)
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
			value_Vector2Value = createVector2Value(var_x,var_y);
			debug Stdout.format("\tparse_Vector2Value passed: {0}",value_Vector2Value).newline;
			return true;
		fail1:
			value_Vector2Value = (Vector2Value).init;
			debug Stdout.format("\tparse_Vector2Value failed").newline;
			return false;
	}

	/*
	Vector3Value
		= Vector3Value createVector3Value(double x,double y,double z)
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
			value_Vector3Value = createVector3Value(var_x,var_y,var_z);
			debug Stdout.format("\tparse_Vector3Value passed: {0}",value_Vector3Value).newline;
			return true;
		fail1:
			value_Vector3Value = (Vector3Value).init;
			debug Stdout.format("\tparse_Vector3Value failed").newline;
			return false;
	}

	/*
	Vector4Value
		= Vector4Value createVector4Value(double x,double y,double z,double w)
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
			value_Vector4Value = createVector4Value(var_x,var_y,var_z,var_w);
			debug Stdout.format("\tparse_Vector4Value passed: {0}",value_Vector4Value).newline;
			return true;
		fail1:
			value_Vector4Value = (Vector4Value).init;
			debug Stdout.format("\tparse_Vector4Value failed").newline;
			return false;
	}

	/*
	StringValue
		= StringValue createStringValue(char[] value)
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
			value_StringValue = createStringValue(var_value);
			debug Stdout.format("\tparse_StringValue passed: {0}",value_StringValue).newline;
			return true;
		fail1:
			value_StringValue = (StringValue).init;
			debug Stdout.format("\tparse_StringValue failed").newline;
			return false;
	}

	/*
	ParamListValue
		= ParamListValue createParamListValue(ParamDef[] params)
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
			value_ParamListValue = createParamListValue(var_params);
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
