module xf.nucleus.kdef.KDefLexer;
private {
	import xf.nucleus.kdef.KDefToken;
	import xf.nucleus.kdef.KDefLexerBase;
}
debug import tango.io.Stdout;

class KDefLexer:KDefLexerBase{
	static char[] getHelp(){
		return "";
	}

	/*
	Syntax
		= KDefToken[] tokens
		::= (Whitespace | SlashStarComment | SlashSlashComment | NestingComment | StringLiteral:~tokens | VerbatimStringLiteral:~tokens | Number:~tokens | Identifier:~tokens | LeftCurly:~tokens | RightCurly:~tokens | LiteralToken:~tokens | @err!("Unexpected char"))* eoi;

	*/
	KDefToken[] value_Syntax;
	bool parse_Syntax(){
		debug Stdout("parse_Syntax").newline;
		KDefToken[] var_tokens;

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
					if(parse_Whitespace()){
						goto start2;
					}
				term5:
					// Production
					if(parse_SlashStarComment()){
						goto start2;
					}
				term6:
					// Production
					if(parse_SlashSlashComment()){
						goto start2;
					}
				term7:
					// Production
					if(parse_NestingComment()){
						goto start2;
					}
				term8:
					// Production
					if(parse_StringLiteral()){
						smartAppend(var_tokens,value_StringLiteral);
						goto start2;
					}
				term9:
					// Production
					if(parse_VerbatimStringLiteral()){
						smartAppend(var_tokens,value_VerbatimStringLiteral);
						goto start2;
					}
				term10:
					// Production
					if(parse_Number()){
						smartAppend(var_tokens,value_Number);
						goto start2;
					}
				term11:
					// Production
					if(parse_Identifier()){
						smartAppend(var_tokens,value_Identifier);
						goto start2;
					}
				term12:
					// Production
					if(parse_LeftCurly()){
						smartAppend(var_tokens,value_LeftCurly);
						goto start2;
					}
				term13:
					// Production
					if(parse_RightCurly()){
						smartAppend(var_tokens,value_RightCurly);
						goto start2;
					}
				term14:
					// Production
					if(parse_LiteralToken()){
						smartAppend(var_tokens,value_LiteralToken);
						goto start2;
					}
				term15:
					// Literal
						err("Unexpected char");
			goto start2;
		end3:
		// Rule
		pass0:
			value_Syntax = var_tokens;
			debug Stdout.format("\tparse_Syntax passed: {0}",value_Syntax).newline;
			return true;
		fail1:
			value_Syntax = (KDefToken[]).init;
			debug Stdout.format("\tparse_Syntax failed").newline;
			return false;
	}

	/*
	Whitespace
		::= {" " | "\t" | "\r" | "\n"};

	*/
	bool value_Whitespace;
	bool parse_Whitespace(){
		debug Stdout("parse_Whitespace").newline;
		// Iterator
		size_t counter5 = 0;
		start2:
			// (terminator)
			if(!hasMore()){
				goto end3;
			}
			// (expression)
			expr4:
				// OrGroup increment6
					// Terminal
					if(match(" ")){
						goto increment6;
					}
				term7:
					// Terminal
					if(match("\t")){
						goto increment6;
					}
				term8:
					// Terminal
					if(match("\r")){
						goto increment6;
					}
				term9:
					// Terminal
					if(!match("\n")){
						goto end3;
					}
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
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_Whitespace failed").newline;
			return false;
	}

	/*
	SlashStarComment
		$String err="Expected closing *\/"
		::= "/*" ?!(err) any* "*\/";

	*/
	bool value_SlashStarComment;
	bool parse_SlashStarComment(){
		debug Stdout("parse_SlashStarComment").newline;
		String var_err = "Expected closing */";

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("/*")){
					goto fail4;
				}
			term5:
				// ErrorPoint
					// Iterator
					start7:
						// (terminator)
							// Terminal
							if(match("*/")){
								goto end8;
							}
						// (expression)
						expr9:
							// Production
							if(!parse_any()){
								goto fail6;
							}
						goto start7;
					end8:
						goto pass0;
				fail6:
					error(var_err);
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_SlashStarComment failed").newline;
			return false;
	}

	/*
	SlashSlashComment
		$String err="Expected terminating newline"
		::= "//" ?!(err) any* ("\n" | eoi);

	*/
	bool value_SlashSlashComment;
	bool parse_SlashSlashComment(){
		debug Stdout("parse_SlashSlashComment").newline;
		String var_err = "Expected terminating newline";

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("//")){
					goto fail4;
				}
			term5:
				// ErrorPoint
					// Iterator
					start7:
						// (terminator)
							// OrGroup end8
								// Terminal
								if(match("\n")){
									goto end8;
								}
							term10:
								// Production
								if(parse_eoi()){
									goto end8;
								}
						// (expression)
						expr9:
							// Production
							if(!parse_any()){
								goto fail6;
							}
						goto start7;
					end8:
						goto pass0;
				fail6:
					error(var_err);
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_SlashSlashComment failed").newline;
			return false;
	}

	/*
	NestingComment
		$String err="Expected closing +\/"
		::= "/+" ?!(err) (NestingComment | any)* "+\/";

	*/
	bool value_NestingComment;
	bool parse_NestingComment(){
		debug Stdout("parse_NestingComment").newline;
		String var_err = "Expected closing +/";

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("/+")){
					goto fail4;
				}
			term5:
				// ErrorPoint
					// Iterator
					start7:
						// (terminator)
							// Terminal
							if(match("+/")){
								goto end8;
							}
						// (expression)
						expr9:
							// OrGroup start7
								// Production
								if(parse_NestingComment()){
									goto start7;
								}
							term10:
								// Production
								if(!parse_any()){
									goto fail6;
								}
						goto start7;
					end8:
						goto pass0;
				fail6:
					error(var_err);
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_NestingComment failed").newline;
			return false;
	}

	/*
	StringLiteral
		= KDefToken StringToken(String text)
		$String err2="Expected closing \""
		::= "\"" ?!(err2) StringChar:~text* "\"";

	*/
	KDefToken value_StringLiteral;
	bool parse_StringLiteral(){
		debug Stdout("parse_StringLiteral").newline;
		String var_err2 = "Expected closing \"";
		String var_text;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("\"")){
					goto fail4;
				}
			term5:
				// ErrorPoint
					// Iterator
					start7:
						// (terminator)
							// Terminal
							if(match("\"")){
								goto end8;
							}
						// (expression)
						expr9:
							// Production
							if(!parse_StringChar()){
								goto fail6;
							}
							smartAppend(var_text,value_StringChar);
						goto start7;
					end8:
						goto pass0;
				fail6:
					error(var_err2);
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_StringLiteral = StringToken(var_text);
			debug Stdout.format("\tparse_StringLiteral passed: {0}",value_StringLiteral).newline;
			return true;
		fail1:
			value_StringLiteral = (KDefToken).init;
			debug Stdout.format("\tparse_StringLiteral failed").newline;
			return false;
	}

	/*
	VerbatimStringLiteral
		= KDefToken VerbatimStringToken(String text)
		::= "`" any:~text* "`";

	*/
	KDefToken value_VerbatimStringLiteral;
	bool parse_VerbatimStringLiteral(){
		debug Stdout("parse_VerbatimStringLiteral").newline;
		String var_text;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("`")){
					goto fail4;
				}
			term5:
				// Iterator
				start6:
					// (terminator)
						// Terminal
						if(match("`")){
							goto end7;
						}
					// (expression)
					expr8:
						// Production
						if(!parse_any()){
							goto fail4;
						}
						smartAppend(var_text,value_any);
					goto start6;
				end7:
					goto pass0;
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_VerbatimStringLiteral = VerbatimStringToken(var_text);
			debug Stdout.format("\tparse_VerbatimStringLiteral passed: {0}",value_VerbatimStringLiteral).newline;
			return true;
		fail1:
			value_VerbatimStringLiteral = (KDefToken).init;
			debug Stdout.format("\tparse_VerbatimStringLiteral failed").newline;
			return false;
	}

	/*
	StringChar
		= String ch
		::= "\\" ("n" @NEWLINE:ch | "r" @CARRAIGE_RETURN:ch | "t" @TAB:ch | "\"" @DOUBLE_QUOTE:ch | "\'" @SINGLE_QUOTE:ch | "\\" @SLASH:ch | @err!("Unexpected escape sequence")) | any:ch;

	*/
	String value_StringChar;
	bool parse_StringChar(){
		debug Stdout("parse_StringChar").newline;
		String var_ch;

		// OrGroup pass0
			// AndGroup
				auto position4 = pos;
					// Terminal
					if(!match("\\")){
						goto fail5;
					}
				term6:
					// OrGroup pass0
						// AndGroup
							auto position9 = pos;
								// Terminal
								if(!match("n")){
									goto fail10;
								}
							term11:
								// Literal
									auto literal12 = NEWLINE;
									smartAssign(var_ch,literal12);
									goto pass0;
							fail10:
							pos = position9;
					term7:
						// AndGroup
							auto position15 = pos;
								// Terminal
								if(!match("r")){
									goto fail16;
								}
							term17:
								// Literal
									auto literal18 = CARRAIGE_RETURN;
									smartAssign(var_ch,literal18);
									goto pass0;
							fail16:
							pos = position15;
					term13:
						// AndGroup
							auto position21 = pos;
								// Terminal
								if(!match("t")){
									goto fail22;
								}
							term23:
								// Literal
									auto literal24 = TAB;
									smartAssign(var_ch,literal24);
									goto pass0;
							fail22:
							pos = position21;
					term19:
						// AndGroup
							auto position27 = pos;
								// Terminal
								if(!match("\"")){
									goto fail28;
								}
							term29:
								// Literal
									auto literal30 = DOUBLE_QUOTE;
									smartAssign(var_ch,literal30);
									goto pass0;
							fail28:
							pos = position27;
					term25:
						// AndGroup
							auto position33 = pos;
								// Terminal
								if(!match("\'")){
									goto fail34;
								}
							term35:
								// Literal
									auto literal36 = SINGLE_QUOTE;
									smartAssign(var_ch,literal36);
									goto pass0;
							fail34:
							pos = position33;
					term31:
						// AndGroup
							auto position39 = pos;
								// Terminal
								if(!match("\\")){
									goto fail40;
								}
							term41:
								// Literal
									auto literal42 = SLASH;
									smartAssign(var_ch,literal42);
									goto pass0;
							fail40:
							pos = position39;
					term37:
						// Literal
							err("Unexpected escape sequence");
							goto pass0;
				fail5:
				pos = position4;
		term2:
			// Production
			if(!parse_any()){
				goto fail1;
			}
			smartAssign(var_ch,value_any);
		// Rule
		pass0:
			value_StringChar = var_ch;
			debug Stdout.format("\tparse_StringChar passed: {0}",value_StringChar).newline;
			return true;
		fail1:
			value_StringChar = (String).init;
			debug Stdout.format("\tparse_StringChar failed").newline;
			return false;
	}

	/*
	Number
		= KDefToken NumberToken(String text)
		::= ("-" | #30-#39 | #2E):~text+;

	*/
	KDefToken value_Number;
	bool parse_Number(){
		debug Stdout("parse_Number").newline;
		String var_text;

		// Iterator
		size_t counter5 = 0;
		start2:
			// (terminator)
			if(!hasMore()){
				goto end3;
			}
			// (expression)
			expr4:
				// Group (w/binding)
					auto position7 = pos;
					// OrGroup pass8
						// Terminal
						if(match("-")){
							goto pass8;
						}
					term9:
						// CharRange
						if(match(cast(char)0x30,cast(char)0x39)){
							goto pass8;
						}
					term10:
						// CharRange
						if(!match(cast(char)0x2E)){
							goto end3;
						}
					pass8:
					smartAppend(var_text,slice(position7,pos));
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
			value_Number = NumberToken(var_text);
			debug Stdout.format("\tparse_Number passed: {0}",value_Number).newline;
			return true;
		fail1:
			value_Number = (KDefToken).init;
			debug Stdout.format("\tparse_Number failed").newline;
			return false;
	}

	/*
	Identifier
		= KDefToken IdentifierToken(String text)
		::= ((#41-#5A | #61-#7A | "_") (#30-#39 | #41-#5A | #61-#7A | "_")*):text;

	*/
	KDefToken value_Identifier;
	bool parse_Identifier(){
		debug Stdout("parse_Identifier").newline;
		String var_text;

		// Group (w/binding)
			auto position2 = pos;
			// AndGroup
				auto position5 = pos;
					// OrGroup term7
						// CharRange
						if(match(cast(char)0x41,cast(char)0x5A)){
							goto term7;
						}
					term8:
						// CharRange
						if(match(cast(char)0x61,cast(char)0x7A)){
							goto term7;
						}
					term9:
						// Terminal
						if(!match("_")){
							goto fail6;
						}
				term7:
					// Iterator
					start10:
						// (terminator)
						if(!hasMore()){
							goto end11;
						}
						// (expression)
						expr12:
							// OrGroup start10
								// CharRange
								if(match(cast(char)0x30,cast(char)0x39)){
									goto start10;
								}
							term13:
								// CharRange
								if(match(cast(char)0x41,cast(char)0x5A)){
									goto start10;
								}
							term14:
								// CharRange
								if(match(cast(char)0x61,cast(char)0x7A)){
									goto start10;
								}
							term15:
								// Terminal
								if(!match("_")){
									goto end11;
								}
						goto start10;
					end11:
						goto pass3;
				fail6:
				pos = position5;
				goto fail1;
			pass3:
			smartAssign(var_text,slice(position2,pos));
		// Rule
		pass0:
			value_Identifier = IdentifierToken(var_text);
			debug Stdout.format("\tparse_Identifier passed: {0}",value_Identifier).newline;
			return true;
		fail1:
			value_Identifier = (KDefToken).init;
			debug Stdout.format("\tparse_Identifier failed").newline;
			return false;
	}

	/*
	LeftCurly
		= KDefToken LeftCurly(String text)
		::= #7B:text;

	*/
	KDefToken value_LeftCurly;
	bool parse_LeftCurly(){
		debug Stdout("parse_LeftCurly").newline;
		String var_text;

		// CharRange
		if(!match(cast(char)0x7B)){
			goto fail1;
		}
		smartAssign(var_text,__match);
		// Rule
		pass0:
			value_LeftCurly = LeftCurly(var_text);
			debug Stdout.format("\tparse_LeftCurly passed: {0}",value_LeftCurly).newline;
			return true;
		fail1:
			value_LeftCurly = (KDefToken).init;
			debug Stdout.format("\tparse_LeftCurly failed").newline;
			return false;
	}

	/*
	RightCurly
		= KDefToken RightCurly(String text)
		::= #7D:text;

	*/
	KDefToken value_RightCurly;
	bool parse_RightCurly(){
		debug Stdout("parse_RightCurly").newline;
		String var_text;

		// CharRange
		if(!match(cast(char)0x7D)){
			goto fail1;
		}
		smartAssign(var_text,__match);
		// Rule
		pass0:
			value_RightCurly = RightCurly(var_text);
			debug Stdout.format("\tparse_RightCurly passed: {0}",value_RightCurly).newline;
			return true;
		fail1:
			value_RightCurly = (KDefToken).init;
			debug Stdout.format("\tparse_RightCurly failed").newline;
			return false;
	}

	/*
	LiteralToken
		= KDefToken LiteralToken(String text)
		::= (#21-#2F | #3A-#40 | #5B-#60 | #7C | #7E):text;

	*/
	KDefToken value_LiteralToken;
	bool parse_LiteralToken(){
		debug Stdout("parse_LiteralToken").newline;
		String var_text;

		// Group (w/binding)
			auto position2 = pos;
			// OrGroup pass3
				// CharRange
				if(match(cast(char)0x21,cast(char)0x2F)){
					goto pass3;
				}
			term4:
				// CharRange
				if(match(cast(char)0x3A,cast(char)0x40)){
					goto pass3;
				}
			term5:
				// CharRange
				if(match(cast(char)0x5B,cast(char)0x60)){
					goto pass3;
				}
			term6:
				// CharRange
				if(match(cast(char)0x7C)){
					goto pass3;
				}
			term7:
				// CharRange
				if(!match(cast(char)0x7E)){
					goto fail1;
				}
			pass3:
			smartAssign(var_text,slice(position2,pos));
		// Rule
		pass0:
			value_LiteralToken = LiteralToken(var_text);
			debug Stdout.format("\tparse_LiteralToken passed: {0}",value_LiteralToken).newline;
			return true;
		fail1:
			value_LiteralToken = (KDefToken).init;
			debug Stdout.format("\tparse_LiteralToken failed").newline;
			return false;
	}
}
