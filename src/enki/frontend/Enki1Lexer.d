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
module enki.frontend.Enki1Lexer;
private import enki.EnkiToken;
private import enki.frontend.EnkiLexerBase;

debug import tango.io.Stdout;

class Enki1Lexer:EnkiLexerBase{
	static char[] getHelp(){
		return "";
	}

	/*
	Tokens
		= EnkiToken[] tokens
		::= [PoundComment] (Whitespace | SlashStarComment | SlashSlashComment | RegexLiteral:~tokens | StringLiteral:~tokens | CurlyLiteral:~tokens | Number:~tokens | Hex:~tokens | SpecialToken:~tokens | Identifier:~tokens | LiteralToken:~tokens | @err!("Unexpected char"))* eoi;

	*/
	bool parse_Tokens(){
		debug Stdout("parse_Tokens").newline;
		EnkiToken[] var_tokens;

		// AndGroup
			auto position3 = getPos();
				// Optional
					// Production
					if(!parse_PoundComment()){
						goto term5;
					}
			term5:
				// Iterator
				start6:
					// (terminator)
						// Production
						if(parse_eoi()){
							goto end7;
						}
					// (expression)
					expr8:
						// OrGroup start6
							// Production
							if(parse_Whitespace()){
								goto start6;
							}
						term9:
							// Production
							if(parse_SlashStarComment()){
								goto start6;
							}
						term10:
							// Production
							if(parse_SlashSlashComment()){
								goto start6;
							}
						term11:
							// Production
							if(parse_RegexLiteral()){
								smartAppend(var_tokens,getMatchValue!(EnkiToken)());
								goto start6;
							}
						term12:
							// Production
							if(parse_StringLiteral()){
								smartAppend(var_tokens,getMatchValue!(EnkiToken)());
								goto start6;
							}
						term13:
							// Production
							if(parse_CurlyLiteral()){
								smartAppend(var_tokens,getMatchValue!(EnkiToken[])());
								goto start6;
							}
						term14:
							// Production
							if(parse_Number()){
								smartAppend(var_tokens,getMatchValue!(EnkiToken)());
								goto start6;
							}
						term15:
							// Production
							if(parse_Hex()){
								smartAppend(var_tokens,getMatchValue!(EnkiToken)());
								goto start6;
							}
						term16:
							// Production
							if(parse_SpecialToken()){
								smartAppend(var_tokens,getMatchValue!(EnkiToken)());
								goto start6;
							}
						term17:
							// Production
							if(parse_Identifier()){
								smartAppend(var_tokens,getMatchValue!(EnkiToken)());
								goto start6;
							}
						term18:
							// Production
							if(parse_LiteralToken()){
								smartAppend(var_tokens,getMatchValue!(EnkiToken)());
								goto start6;
							}
						term19:
							// Literal
								err("Unexpected char");
					goto start6;
				end7:
					goto pass0;
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			setMatchValue(var_tokens);
			debug Stdout.format("\tparse_Tokens passed: {0}",getMatchValue!(EnkiToken[])).newline;
			return true;
		fail1:
			setMatchValue((EnkiToken[]).init);
			debug Stdout.format("\tparse_Tokens failed").newline;
			return false;
	}

	/*
	Newline
		::= ("\n" | "\r\n" | "\n\r") [PoundComment];

	*/
	bool parse_Newline(){
		debug Stdout("parse_Newline").newline;
		// AndGroup
			auto position3 = getPos();
				// OrGroup term5
					// Terminal
					if(match("\n")){
						goto term5;
					}
				term6:
					// Terminal
					if(match("\r\n")){
						goto term5;
					}
				term7:
					// Terminal
					if(!match("\n\r")){
						goto fail4;
					}
			term5:
				// Optional
					// Production
					if(parse_PoundComment()){
						goto pass0;
					}
					goto pass0;
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_Newline failed").newline;
			return false;
	}

	/*
	Whitespace
		::= {" " | "\t" | Newline};

	*/
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
					// Production
					if(!parse_Newline()){
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
					goto pass0;
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
	bool parse_SlashStarComment(){
		debug Stdout("parse_SlashStarComment").newline;
		String var_err = "Expected closing */";

		// AndGroup
			auto position3 = getPos();
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
			setPos(position3);
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
		::= "//" ?!(err) any* (Newline | eoi);

	*/
	bool parse_SlashSlashComment(){
		debug Stdout("parse_SlashSlashComment").newline;
		String var_err = "Expected terminating newline";

		// AndGroup
			auto position3 = getPos();
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
								// Production
								if(parse_Newline()){
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
			setPos(position3);
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
	PoundComment
		::= "#" any* (Newline | eoi);

	*/
	bool parse_PoundComment(){
		debug Stdout("parse_PoundComment").newline;
		// AndGroup
			auto position3 = getPos();
				// Terminal
				if(!match("#")){
					goto fail4;
				}
			term5:
				// Iterator
				start6:
					// (terminator)
						// OrGroup end7
							// Production
							if(parse_Newline()){
								goto end7;
							}
						term9:
							// Production
							if(parse_eoi()){
								goto end7;
							}
					// (expression)
					expr8:
						// Production
						if(!parse_any()){
							goto fail4;
						}
					goto start6;
				end7:
					goto pass0;
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			debug Stdout("passed").newline;
			return true;
		fail1:
			debug Stdout.format("\tparse_PoundComment failed").newline;
			return false;
	}

	/*
	RegexLiteral
		= EnkiToken RegexToken(String text)
		$String err1="Expected closing `"
		$String err2="Expected closing \""
		$String err3="Expected closing \'"
		::= "`" ?!(err1) (any:text)* "`" | "r" ("\"" ?!(err2) (StringChar:~text)* "\"") | "r" ("\'" ?!(err2) (StringChar:~text)* "\'");

	*/
	bool parse_RegexLiteral(){
		debug Stdout("parse_RegexLiteral").newline;
		String var_text;
		String var_err1 = "Expected closing `";
		String var_err2 = "Expected closing \"";
		String var_err3 = "Expected closing \'";

		// AndGroup
			auto position3 = getPos();
				// Terminal
				if(!match("`")){
					goto fail4;
				}
			term5:
				// ErrorPoint
					// OrGroup pass0
						// Iterator
						start8:
							// (terminator)
								// Terminal
								if(match("`")){
									goto end9;
								}
							// (expression)
							expr10:
								// Production
								if(!parse_any()){
									goto term7;
								}
								smartAssign(var_text,getMatchValue!(String)());
							goto start8;
						end9:
							goto pass0;
					term7:
						// AndGroup
							auto position13 = getPos();
								// Terminal
								if(!match("r")){
									goto fail14;
								}
							term15:
								// AndGroup
									auto position17 = getPos();
										// Terminal
										if(!match("\"")){
											goto fail18;
										}
									term19:
										// ErrorPoint
											// Iterator
											start21:
												// (terminator)
													// Terminal
													if(match("\"")){
														goto end22;
													}
												// (expression)
												expr23:
													// Production
													if(!parse_StringChar()){
														goto fail20;
													}
													smartAppend(var_text,getMatchValue!(String)());
												goto start21;
											end22:
												goto pass0;
										fail20:
											error(var_err2);
									fail18:
									setPos(position17);
							fail14:
							setPos(position13);
					term11:
						// AndGroup
							auto position25 = getPos();
								// Terminal
								if(!match("r")){
									goto fail26;
								}
							term27:
								// AndGroup
									auto position29 = getPos();
										// Terminal
										if(!match("\'")){
											goto fail30;
										}
									term31:
										// ErrorPoint
											// Iterator
											start33:
												// (terminator)
													// Terminal
													if(match("\'")){
														goto end34;
													}
												// (expression)
												expr35:
													// Production
													if(!parse_StringChar()){
														goto fail32;
													}
													smartAppend(var_text,getMatchValue!(String)());
												goto start33;
											end34:
												goto pass0;
										fail32:
											error(var_err2);
									fail30:
									setPos(position29);
							fail26:
							setPos(position25);
				fail6:
					error(var_err1);
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			setMatchValue(RegexToken(var_text));
			debug Stdout.format("\tparse_RegexLiteral passed: {0}",getMatchValue!(EnkiToken)).newline;
			return true;
		fail1:
			setMatchValue((EnkiToken).init);
			debug Stdout.format("\tparse_RegexLiteral failed").newline;
			return false;
	}

	/*
	StringLiteral
		= EnkiToken StringToken(String text)
		$String err1="Expected closing \""
		$String err2="Expected closing \'"
		::= ("\"" ?!(err1) (StringChar:~text)* "\"") | ("\'" ?!(err2) (StringChar:~text)* "\'");

	*/
	bool parse_StringLiteral(){
		debug Stdout("parse_StringLiteral").newline;
		String var_text;
		String var_err1 = "Expected closing \"";
		String var_err2 = "Expected closing \'";

		// OrGroup pass0
			// AndGroup
				auto position4 = getPos();
					// Terminal
					if(!match("\"")){
						goto fail5;
					}
				term6:
					// ErrorPoint
						// Iterator
						start8:
							// (terminator)
								// Terminal
								if(match("\"")){
									goto end9;
								}
							// (expression)
							expr10:
								// Production
								if(!parse_StringChar()){
									goto fail7;
								}
								smartAppend(var_text,getMatchValue!(String)());
							goto start8;
						end9:
							goto pass0;
					fail7:
						error(var_err1);
				fail5:
				setPos(position4);
		term2:
			// AndGroup
				auto position12 = getPos();
					// Terminal
					if(!match("\'")){
						goto fail13;
					}
				term14:
					// ErrorPoint
						// Iterator
						start16:
							// (terminator)
								// Terminal
								if(match("\'")){
									goto end17;
								}
							// (expression)
							expr18:
								// Production
								if(!parse_StringChar()){
									goto fail15;
								}
								smartAppend(var_text,getMatchValue!(String)());
							goto start16;
						end17:
							goto pass0;
					fail15:
						error(var_err2);
				fail13:
				setPos(position12);
				goto fail1;
		// Rule
		pass0:
			setMatchValue(StringToken(var_text));
			debug Stdout.format("\tparse_StringLiteral passed: {0}",getMatchValue!(EnkiToken)).newline;
			return true;
		fail1:
			setMatchValue((EnkiToken).init);
			debug Stdout.format("\tparse_StringLiteral failed").newline;
			return false;
	}

	/*
	CurlyLiteral
		= EnkiToken[] tokens
		$String err1="Expected closing \'}}}\'"
		::= CurlyLiteralStart:~tokens ?!(err1) CurlyLiteralContent:~tokens CurlyLiteralEnd:~tokens;

	*/
	bool parse_CurlyLiteral(){
		debug Stdout("parse_CurlyLiteral").newline;
		EnkiToken[] var_tokens;
		String var_err1 = "Expected closing \'}}}\'";

		// AndGroup
			auto position3 = getPos();
				// Production
				if(!parse_CurlyLiteralStart()){
					goto fail4;
				}
				smartAppend(var_tokens,getMatchValue!(EnkiToken)());
			term5:
				// ErrorPoint
					// AndGroup
						auto position8 = getPos();
							// Production
							if(!parse_CurlyLiteralContent()){
								goto fail9;
							}
							smartAppend(var_tokens,getMatchValue!(EnkiToken)());
						term10:
							// Production
							if(parse_CurlyLiteralEnd()){
								smartAppend(var_tokens,getMatchValue!(EnkiToken)());
								goto pass0;
							}
						fail9:
						setPos(position8);
				fail6:
					error(var_err1);
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			setMatchValue(var_tokens);
			debug Stdout.format("\tparse_CurlyLiteral passed: {0}",getMatchValue!(EnkiToken[])).newline;
			return true;
		fail1:
			setMatchValue((EnkiToken[]).init);
			debug Stdout.format("\tparse_CurlyLiteral failed").newline;
			return false;
	}

	/*
	CurlyLiteralStart
		= EnkiToken LiteralToken(String text)
		::= "{{{":text;

	*/
	bool parse_CurlyLiteralStart(){
		debug Stdout("parse_CurlyLiteralStart").newline;
		String var_text;

		// Terminal
		if(!match("{{{")){
			goto fail1;
		}
		smartAssign(var_text,getMatchValue!(String)());
		// Rule
		pass0:
			setMatchValue(LiteralToken(var_text));
			debug Stdout.format("\tparse_CurlyLiteralStart passed: {0}",getMatchValue!(EnkiToken)).newline;
			return true;
		fail1:
			setMatchValue((EnkiToken).init);
			debug Stdout.format("\tparse_CurlyLiteralStart failed").newline;
			return false;
	}

	/*
	CurlyLiteralContent
		= EnkiToken StringToken(String text)
		::= ((!"}}}"):~text)*;

	*/
	bool parse_CurlyLiteralContent(){
		debug Stdout("parse_CurlyLiteralContent").newline;
		String var_text;

		// Iterator
		start2:
			// (terminator)
			if(!hasMore()){
				goto end3;
			}
			// (expression)
			expr4:
				// Group (w/binding)
					auto position5 = getPos();
					// Negate
						// (test expr)
						auto position9 = getPos();
						// Terminal
						if(!match("}}}")){
							goto term7;
						}
						fail8:
						setPos(position9);
						goto end3;
						term7:
						parse_any();
					pass6:
					smartAppend(var_text,slice(position5,getPos()));
			goto start2;
		end3:
		// Rule
		pass0:
			setMatchValue(StringToken(var_text));
			debug Stdout.format("\tparse_CurlyLiteralContent passed: {0}",getMatchValue!(EnkiToken)).newline;
			return true;
		fail1:
			setMatchValue((EnkiToken).init);
			debug Stdout.format("\tparse_CurlyLiteralContent failed").newline;
			return false;
	}

	/*
	CurlyLiteralEnd
		= EnkiToken LiteralToken(String text)
		::= "}}}":text;

	*/
	bool parse_CurlyLiteralEnd(){
		debug Stdout("parse_CurlyLiteralEnd").newline;
		String var_text;

		// Terminal
		if(!match("}}}")){
			goto fail1;
		}
		smartAssign(var_text,getMatchValue!(String)());
		// Rule
		pass0:
			setMatchValue(LiteralToken(var_text));
			debug Stdout.format("\tparse_CurlyLiteralEnd passed: {0}",getMatchValue!(EnkiToken)).newline;
			return true;
		fail1:
			setMatchValue((EnkiToken).init);
			debug Stdout.format("\tparse_CurlyLiteralEnd failed").newline;
			return false;
	}

	/*
	StringChar
		= String ch
		::= "\\" ("n" @NEWLINE:ch | "r" @CARRAIGE_RETURN:ch | "t" @TAB:ch | "\"" @DOUBLE_QUOTE:ch | "\'" @SINGLE_QUOTE:ch | "\\" @SLASH:ch | @err!("Unexpected escape sequence")) | any:ch;

	*/
	bool parse_StringChar(){
		debug Stdout("parse_StringChar").newline;
		String var_ch;

		// OrGroup pass0
			// AndGroup
				auto position4 = getPos();
					// Terminal
					if(!match("\\")){
						goto fail5;
					}
				term6:
					// OrGroup pass0
						// AndGroup
							auto position9 = getPos();
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
							setPos(position9);
					term7:
						// AndGroup
							auto position15 = getPos();
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
							setPos(position15);
					term13:
						// AndGroup
							auto position21 = getPos();
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
							setPos(position21);
					term19:
						// AndGroup
							auto position27 = getPos();
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
							setPos(position27);
					term25:
						// AndGroup
							auto position33 = getPos();
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
							setPos(position33);
					term31:
						// AndGroup
							auto position39 = getPos();
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
							setPos(position39);
					term37:
						// Literal
							err("Unexpected escape sequence");
							goto pass0;
				fail5:
				setPos(position4);
		term2:
			// Production
			if(!parse_any()){
				goto fail1;
			}
			smartAssign(var_ch,getMatchValue!(String)());
		// Rule
		pass0:
			setMatchValue(var_ch);
			debug Stdout.format("\tparse_StringChar passed: {0}",getMatchValue!(String)).newline;
			return true;
		fail1:
			setMatchValue((String).init);
			debug Stdout.format("\tparse_StringChar failed").newline;
			return false;
	}

	/*
	Hex
		= EnkiToken HexToken(String text)
		$String err="Expected two, four or eight hex digits"
		::= "#" ?!(err) ({#30-#39 | #41-#46 | #61-#66}<2,4,8>):text;

	*/
	bool parse_Hex(){
		debug Stdout("parse_Hex").newline;
		String var_err = "Expected two, four or eight hex digits";
		String var_text;

		// AndGroup
			auto position3 = getPos();
				// Terminal
				if(!match("#")){
					goto fail4;
				}
			term5:
				// ErrorPoint
					// Group (w/binding)
						auto position7 = getPos();
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
									if(match(0x30,0x39)){
										goto increment13;
									}
								term14:
									// CharRange
									if(match(0x41,0x46)){
										goto increment13;
									}
								term15:
									// CharRange
									if(!match(0x61,0x66)){
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
									goto pass8;
								}
						pass8:
						smartAssign(var_text,slice(position7,getPos()));
						goto pass0;
				fail6:
					error(var_err);
			fail4:
			setPos(position3);
			goto fail1;
		// Rule
		pass0:
			setMatchValue(HexToken(var_text));
			debug Stdout.format("\tparse_Hex passed: {0}",getMatchValue!(EnkiToken)).newline;
			return true;
		fail1:
			setMatchValue((EnkiToken).init);
			debug Stdout.format("\tparse_Hex failed").newline;
			return false;
	}

	/*
	Number
		= EnkiToken NumberToken(String text)
		::= (#30-#39:text)+;

	*/
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
				if(!match(0x30,0x39)){
					goto end3;
				}
				smartAssign(var_text,getMatchValue!(String)());
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
			setMatchValue(NumberToken(var_text));
			debug Stdout.format("\tparse_Number passed: {0}",getMatchValue!(EnkiToken)).newline;
			return true;
		fail1:
			setMatchValue((EnkiToken).init);
			debug Stdout.format("\tparse_Number failed").newline;
			return false;
	}

	/*
	Identifier
		= EnkiToken IdentifierToken(String text)
		::= ((#41-#5A | #61-#7A | "_") (#30-#39 | #41-#5A | #61-#7A | "_")*):text;

	*/
	bool parse_Identifier(){
		debug Stdout("parse_Identifier").newline;
		String var_text;

		// Group (w/binding)
			auto position2 = getPos();
			// AndGroup
				auto position5 = getPos();
					// OrGroup term7
						// CharRange
						if(match(0x41,0x5A)){
							goto term7;
						}
					term8:
						// CharRange
						if(match(0x61,0x7A)){
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
								if(match(0x30,0x39)){
									goto start10;
								}
							term13:
								// CharRange
								if(match(0x41,0x5A)){
									goto start10;
								}
							term14:
								// CharRange
								if(match(0x61,0x7A)){
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
				setPos(position5);
				goto fail1;
			pass3:
			smartAssign(var_text,slice(position2,getPos()));
		// Rule
		pass0:
			setMatchValue(IdentifierToken(var_text));
			debug Stdout.format("\tparse_Identifier passed: {0}",getMatchValue!(EnkiToken)).newline;
			return true;
		fail1:
			setMatchValue((EnkiToken).init);
			debug Stdout.format("\tparse_Identifier failed").newline;
			return false;
	}

	/*
	SpecialToken
		= EnkiToken CreateToken(String text,EnkiToken.ValueType tok)
		::= "new":text @TOK_NEW:tok | "::=":text @TOK_RULEASSIGN:tok | "!(":text @TOK_LITERAL:tok;

	*/
	bool parse_SpecialToken(){
		debug Stdout("parse_SpecialToken").newline;
		EnkiToken.ValueType var_tok;
		String var_text;

		// OrGroup pass0
			// AndGroup
				auto position4 = getPos();
					// Terminal
					if(!match("new")){
						goto fail5;
					}
					smartAssign(var_text,getMatchValue!(String)());
				term6:
					// Literal
						auto literal7 = TOK_NEW;
						smartAssign(var_tok,literal7);
						goto pass0;
				fail5:
				setPos(position4);
		term2:
			// AndGroup
				auto position10 = getPos();
					// Terminal
					if(!match("::=")){
						goto fail11;
					}
					smartAssign(var_text,getMatchValue!(String)());
				term12:
					// Literal
						auto literal13 = TOK_RULEASSIGN;
						smartAssign(var_tok,literal13);
						goto pass0;
				fail11:
				setPos(position10);
		term8:
			// AndGroup
				auto position15 = getPos();
					// Terminal
					if(!match("!(")){
						goto fail16;
					}
					smartAssign(var_text,getMatchValue!(String)());
				term17:
					// Literal
						auto literal18 = TOK_LITERAL;
						smartAssign(var_tok,literal18);
						goto pass0;
				fail16:
				setPos(position15);
				goto fail1;
		// Rule
		pass0:
			setMatchValue(CreateToken(var_text,var_tok));
			debug Stdout.format("\tparse_SpecialToken passed: {0}",getMatchValue!(EnkiToken)).newline;
			return true;
		fail1:
			setMatchValue((EnkiToken).init);
			debug Stdout.format("\tparse_SpecialToken failed").newline;
			return false;
	}

	/*
	LiteralToken
		= EnkiToken LiteralToken(String text)
		::= (#21-#2F | #3A-#40 | #5B-#60 | #7B-#7E):text;

	*/
	bool parse_LiteralToken(){
		debug Stdout("parse_LiteralToken").newline;
		String var_text;

		// Group (w/binding)
			auto position2 = getPos();
			// OrGroup pass3
				// CharRange
				if(match(0x21,0x2F)){
					goto pass3;
				}
			term4:
				// CharRange
				if(match(0x3A,0x40)){
					goto pass3;
				}
			term5:
				// CharRange
				if(match(0x5B,0x60)){
					goto pass3;
				}
			term6:
				// CharRange
				if(!match(0x7B,0x7E)){
					goto fail1;
				}
			pass3:
			smartAssign(var_text,slice(position2,getPos()));
		// Rule
		pass0:
			setMatchValue(LiteralToken(var_text));
			debug Stdout.format("\tparse_LiteralToken passed: {0}",getMatchValue!(EnkiToken)).newline;
			return true;
		fail1:
			setMatchValue((EnkiToken).init);
			debug Stdout.format("\tparse_LiteralToken failed").newline;
			return false;
	}
}
