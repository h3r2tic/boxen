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
module enki.frontend.Enki2Lexer;
import enki.EnkiToken;
import enki.frontend.EnkiLexerBase;

debug import tango.io.Stdout;

class Enki2Lexer:EnkiLexerBase{
	static char[] getHelp(){
		return "";
	}

	/*
	Syntax
		= EnkiToken[] tokens
		::= (Whitespace | SlashStarComment | SlashSlashComment | NestingComment | RegexLiteral:~tokens | StringLiteral:~tokens | Number:~tokens | Hex:~tokens | SpecialToken:~tokens | Identifier:~tokens | LiteralToken:~tokens | @err!("Unexpected char"))* eoi;

	*/
	EnkiToken[] value_Syntax;
	bool parse_Syntax(){
		debug Stdout("parse_Syntax").newline;
		EnkiToken[] var_tokens;

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
					if(parse_RegexLiteral()){
						smartAppend(var_tokens,value_RegexLiteral);
						goto start2;
					}
				term9:
					// Production
					if(parse_StringLiteral()){
						smartAppend(var_tokens,value_StringLiteral);
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
					if(parse_Hex()){
						smartAppend(var_tokens,value_Hex);
						goto start2;
					}
				term12:
					// Production
					if(parse_SpecialToken()){
						smartAppend(var_tokens,value_SpecialToken);
						goto start2;
					}
				term13:
					// Production
					if(parse_Identifier()){
						smartAppend(var_tokens,value_Identifier);
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
			value_Syntax = (EnkiToken[]).init;
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
	RegexLiteral
		= EnkiToken RegexToken(String text)
		$String err="Expected closing `"
		::= "`" ?!(err) any:text* "`";

	*/
	EnkiToken value_RegexLiteral;
	bool parse_RegexLiteral(){
		debug Stdout("parse_RegexLiteral").newline;
		String var_err = "Expected closing `";
		String var_text;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("`")){
					goto fail4;
				}
			term5:
				// ErrorPoint
					// Iterator
					start7:
						// (terminator)
							// Terminal
							if(match("`")){
								goto end8;
							}
						// (expression)
						expr9:
							// Production
							if(!parse_any()){
								goto fail6;
							}
							smartAssign(var_text,value_any);
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
			value_RegexLiteral = RegexToken(var_text);
			debug Stdout.format("\tparse_RegexLiteral passed: {0}",value_RegexLiteral).newline;
			return true;
		fail1:
			value_RegexLiteral = (EnkiToken).init;
			debug Stdout.format("\tparse_RegexLiteral failed").newline;
			return false;
	}

	/*
	StringLiteral
		= EnkiToken StringToken(String text)
		$String err1="Expected closing \"\"\""
		$String err2="Expected closing \""
		$String err3="Expected closing \'"
		::= ("\"\"\"" ?!(err1) any:~text* "\"\"\"") | ("\"" ?!(err2) StringChar:~text* "\"") | ("\'" ?!(err2) StringChar:~text* "\'");

	*/
	EnkiToken value_StringLiteral;
	bool parse_StringLiteral(){
		debug Stdout("parse_StringLiteral").newline;
		String var_err2 = "Expected closing \"";
		String var_text;
		String var_err1 = "Expected closing \"\"\"";
		String var_err3 = "Expected closing \'";

		// OrGroup pass0
			// AndGroup
				auto position4 = pos;
					// Terminal
					if(!match("\"\"\"")){
						goto fail5;
					}
				term6:
					// ErrorPoint
						// Iterator
						start8:
							// (terminator)
								// Terminal
								if(match("\"\"\"")){
									goto end9;
								}
							// (expression)
							expr10:
								// Production
								if(!parse_any()){
									goto fail7;
								}
								smartAppend(var_text,value_any);
							goto start8;
						end9:
							goto pass0;
					fail7:
						error(var_err1);
				fail5:
				pos = position4;
		term2:
			// AndGroup
				auto position13 = pos;
					// Terminal
					if(!match("\"")){
						goto fail14;
					}
				term15:
					// ErrorPoint
						// Iterator
						start17:
							// (terminator)
								// Terminal
								if(match("\"")){
									goto end18;
								}
							// (expression)
							expr19:
								// Production
								if(!parse_StringChar()){
									goto fail16;
								}
								smartAppend(var_text,value_StringChar);
							goto start17;
						end18:
							goto pass0;
					fail16:
						error(var_err2);
				fail14:
				pos = position13;
		term11:
			// AndGroup
				auto position21 = pos;
					// Terminal
					if(!match("\'")){
						goto fail22;
					}
				term23:
					// ErrorPoint
						// Iterator
						start25:
							// (terminator)
								// Terminal
								if(match("\'")){
									goto end26;
								}
							// (expression)
							expr27:
								// Production
								if(!parse_StringChar()){
									goto fail24;
								}
								smartAppend(var_text,value_StringChar);
							goto start25;
						end26:
							goto pass0;
					fail24:
						error(var_err2);
				fail22:
				pos = position21;
				goto fail1;
		// Rule
		pass0:
			value_StringLiteral = StringToken(var_text);
			debug Stdout.format("\tparse_StringLiteral passed: {0}",value_StringLiteral).newline;
			return true;
		fail1:
			value_StringLiteral = (EnkiToken).init;
			debug Stdout.format("\tparse_StringLiteral failed").newline;
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
	Hex
		= EnkiToken HexToken(String text)
		$String err="Expected two, four or eight hex digits"
		::= "#" ?!(err) ({#30-#39 | #41-#46 | #61-#66}<2,4,8>):text;

	*/
	EnkiToken value_Hex;
	bool parse_Hex(){
		debug Stdout("parse_Hex").newline;
		String var_err = "Expected two, four or eight hex digits";
		String var_text;

		// AndGroup
			auto position3 = pos;
				// Terminal
				if(!match("#")){
					goto fail4;
				}
			term5:
				// ErrorPoint
					// Group (w/binding)
						auto position7 = pos;
						// Iterator
						size_t counter12 = 0;
						start9:
							// (terminator)
							if(counter12 == 8){
								goto end10;
							}
							// (expression)
							expr11:
								// OrGroup increment13
									// CharRange
									if(match(cast(char)0x30,cast(char)0x39)){
										goto increment13;
									}
								term14:
									// CharRange
									if(match(cast(char)0x41,cast(char)0x46)){
										goto increment13;
									}
								term15:
									// CharRange
									if(!match(cast(char)0x61,cast(char)0x66)){
										goto end10;
									}
							increment13:
							// (increment expr count)
								counter12 ++;
							goto start9;
						end10:
							// (range test)
								if(!((counter12 >= 1) || (counter12 == 2) || (counter12 == 4) || (counter12 == 8))){
									goto fail6;
								}
						pass8:
						smartAssign(var_text,slice(position7,pos));
						goto pass0;
				fail6:
					error(var_err);
			fail4:
			pos = position3;
			goto fail1;
		// Rule
		pass0:
			value_Hex = HexToken(var_text);
			debug Stdout.format("\tparse_Hex passed: {0}",value_Hex).newline;
			return true;
		fail1:
			value_Hex = (EnkiToken).init;
			debug Stdout.format("\tparse_Hex failed").newline;
			return false;
	}

	/*
	Number
		= EnkiToken NumberToken(String text)
		::= #30-#39:~text+;

	*/
	EnkiToken value_Number;
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
				// CharRange
				if(!match(cast(char)0x30,cast(char)0x39)){
					goto end3;
				}
				smartAppend(var_text,__match);
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
			value_Number = (EnkiToken).init;
			debug Stdout.format("\tparse_Number failed").newline;
			return false;
	}

	/*
	Identifier
		= EnkiToken IdentifierToken(String text)
		::= ((#41-#5A | #61-#7A | "_") (#30-#39 | #41-#5A | #61-#7A | "_")*):text;

	*/
	EnkiToken value_Identifier;
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
			value_Identifier = (EnkiToken).init;
			debug Stdout.format("\tparse_Identifier failed").newline;
			return false;
	}

	/*
	SpecialToken
		= EnkiToken CreateToken(String text,uint tok)
		::= "new" @TOK_NEW:tok | "::=" @TOK_RULEASSIGN:tok | "?!" @TOK_ERRORPOINT:tok | ".." @TOK_RANGE:tok;

	*/
	EnkiToken value_SpecialToken;
	bool parse_SpecialToken(){
		debug Stdout("parse_SpecialToken").newline;
		uint var_tok;
		String var_text;

		// OrGroup pass0
			// AndGroup
				auto position4 = pos;
					// Terminal
					if(!match("new")){
						goto fail5;
					}
				term6:
					// Literal
						auto literal7 = TOK_NEW;
						smartAssign(var_tok,literal7);
						goto pass0;
				fail5:
				pos = position4;
		term2:
			// AndGroup
				auto position10 = pos;
					// Terminal
					if(!match("::=")){
						goto fail11;
					}
				term12:
					// Literal
						auto literal13 = TOK_RULEASSIGN;
						smartAssign(var_tok,literal13);
						goto pass0;
				fail11:
				pos = position10;
		term8:
			// AndGroup
				auto position16 = pos;
					// Terminal
					if(!match("?!")){
						goto fail17;
					}
				term18:
					// Literal
						auto literal19 = TOK_ERRORPOINT;
						smartAssign(var_tok,literal19);
						goto pass0;
				fail17:
				pos = position16;
		term14:
			// AndGroup
				auto position21 = pos;
					// Terminal
					if(!match("..")){
						goto fail22;
					}
				term23:
					// Literal
						auto literal24 = TOK_RANGE;
						smartAssign(var_tok,literal24);
						goto pass0;
				fail22:
				pos = position21;
				goto fail1;
		// Rule
		pass0:
			value_SpecialToken = CreateToken(var_text,var_tok);
			debug Stdout.format("\tparse_SpecialToken passed: {0}",value_SpecialToken).newline;
			return true;
		fail1:
			value_SpecialToken = (EnkiToken).init;
			debug Stdout.format("\tparse_SpecialToken failed").newline;
			return false;
	}

	/*
	LiteralToken
		= EnkiToken LiteralToken(String text)
		::= (#21-#2F | #3A-#40 | #5B-#60 | #7B-#7E):text;

	*/
	EnkiToken value_LiteralToken;
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
				if(!match(cast(char)0x7B,cast(char)0x7E)){
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
			value_LiteralToken = (EnkiToken).init;
			debug Stdout.format("\tparse_LiteralToken failed").newline;
			return false;
	}
}
