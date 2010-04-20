module xf.nucleus.quark.QuarkParser;
	
/+private {
	import xf.nucleus.quark.QuarkDef;
	import xf.nucleus.util.Tokenizer;
	import xf.nucleus.util.Parser;
	
	static import tango.text.Util;
	import tango.text.Unicode;
	import tango.util.Convert;
	import tango.io.Stdout;
	
	alias wchar[]	string;
	alias wchar	charT;
}



class QuarkParser {
	QuarkDef[] quarks;
	
	QuarkParser parse(string source) {
		this.source = source;
		
		this.tokens = (new Tokenizer(source)).tokenize().tokens;
		
		/+foreach (t; tokens) {
			Stdout.formatln("Token {} @ {} : {}", Token.str(t.type), t.line, source[t.start .. t.start+t.length]);
		}+/
		
		parseRoot();
		
		/+foreach (q; quarks) {
			Stdout.formatln("{} Quark {} @ line {}", ["gpu", "cpu"][q.type], q.name, q.sourceFirstLine);
		}+/
		
		return this;
	}
	
	
	protected {
		mixin MParserBase;
		
		
		void parseRoot() {
			while (!eof) {
				quarks ~= parseQuarkDef();
			}
		}

		
		QuarkDef parseQuarkDef() {
			auto qd = new QuarkDef;
			
			auto type = expect(Token.Type.Ident);
			switch (str(type)) {
				case "gpu":
					qd.type = QuarkDef.Type.GPU;
					break;
				case "cpu":
					qd.type = QuarkDef.Type.CPU;
					break;
				default:
					error("Unknown quark type: " ~ str(type));
					break;
			}
			advance;
			
			auto name = str(expect(Token.Type.Ident));
			advance;
			qd.name = strTo!(typeof(qd.name))(name);
			
			expect(Token.Type.Colon);
			advance;
			
			qd.implList = parseInheritList();
			
			expect(Token.Type.LBrace);
			parseQuarkBody(qd);
			
			return qd;
		}
		
		
		ImplList parseInheritList() {
			ImplList il = new ImplList;
			
			while (!eof) {
				auto name = str(expect(Token.Type.Ident));
				advance;
				
				expect(Token.Type.LParen);
				advance;
				
				auto score = to!(int)(str(expect(Token.Type.Number)));
				advance;

				expect(Token.Type.RParen);
				advance;
				
				il.add(strTo!(char[])(name), score);
				
				if (Token.Type.Comma != c.type) {
					break;
				} else {
					advance;
				}
			}
			
			return il;
		}
		
		
		Function parseQuarkFunction(QuarkDef qd, bool[char[]] quarkUtilFunctions) {
			auto func = new Function;
			
			expect(Token.Type.Ident);
			
			func.name = str8(c);
			static assert (!is(charT == char));		// otherwise would need a .dup here
			
			advance;
			
			expect(Token.Type.LParen);
			advance;
			
			func.overrideParams(parseFunctionParamList());
			
			expect(Token.Type.RParen);
			advance;

			// finding the body src
			int bodyFirstTok = this.position+1;
			int sourceFirstLine = c.line;
			int bracketLevel = 0;
			tokenIter: while (!eof) {
				switch(c.type) {
					case Token.Type.LBrace:
						++bracketLevel;
						break;
					case Token.Type.RBrace:
						--bracketLevel;
						if (0 == bracketLevel) {
							int bodyLastTok = this.position-1;
							if (QuarkDef.Type.GPU == qd.type) {
								func.bodySource = renameFunctions(quarkUtilFunctions, qd, bodyFirstTok, bodyLastTok);
							} else {
								func.bodySource = to!(typeof(func.bodySource))(this.source
											[tokens[bodyFirstTok].start .. tokens[bodyLastTok].start + tokens[bodyLastTok].length]);
								static if (!is(typeof(func.bodySource) == typeof(this.source))) {
									func.bodySource = func.bodySource.dup;
								}
							}
							func.bodySourceFirstLine = sourceFirstLine;
							advance;
							return func;
						}
						break;
						
					default: break;
				}				
				advance;
			}
		}
		
		
		void parseQuarkBody(QuarkDef qd) {
			expect(Token.Type.LBrace);
			advance;
			
			int bodyFirstTok = this.position;
			//int bodyStart = c.start;
			int sourceFirstLine = c.line;
			
			bool[char[]] quarkUtilFunctions;
			
			int bracketLevel = 1;
			tokenIter: while (!eof) {
				switch(c.type) {
					case Token.Type.Ident:
						if (isNewDecl && Token.Type.Ident == c(0).type) {
							int pos = this.position;
							/+char[] retType;
							try {
								retType = parseType;
							} catch (ParserException exc) {
								this.position = pos;
								break;
							}+/
							
							//if (Token.Type.Ident == c.type && Token.Type.LParen == c(1).type) {
							if (isNewDecl && "quark" == str(c) && Token.Type.Ident == c(1).type && Token.Type.LParen == c(2).type) {
								Stdout.formatln("candidate for func: name={}", str(c));
								//Stdout.formatln("{} {}", str(c), str(c(1)));
								advance;
								auto func = parseQuarkFunction(qd, quarkUtilFunctions);
								qd.functions ~= func;
								//func.name = renamedFuncName(qd, func.name);
								auto endPos = this.position;
								
								//if (QuarkDef.Type.CPU == qd.type) {
									// remove the function from the source so it may be pasted into quarks with the functions changed
									this.source[tokens[pos].start .. tokens[endPos].start/+ + tokens[endPos].length+/] = ' ';
								/+} else {
									this.source[tokens[pos].start .. tokens[pos].start + tokens[pos].length] = "void ";
								}+/
								
								//func.retType = retType;
								continue tokenIter;
							} else {
								char[] retType;
								
								try {
									retType = parseType;
								} catch (ParserException exc) {
									this.position = pos;
									break;
								}
								
								// utility function? we shall rename these
								if (Token.Type.Ident == c.type && Token.Type.LParen == c(1).type) {
									//Stdout.formatln(`adding {} to util funcs`, str8(c));
									quarkUtilFunctions[str8(c)] = true;
								}

								this.position = pos;
								break;
							}
						}
						break;
					
					case Token.Type.LBrace:
						++bracketLevel;
						break;
					case Token.Type.RBrace:
						--bracketLevel;
						if (0 == bracketLevel) {
							//int bodyEnd = c.start;
							
							int bodyLastTok = this.position;
							
							// remove the last '}'
							this.source[tokens[bodyLastTok].start .. tokens[bodyLastTok].start + tokens[bodyLastTok].length] = ' ';
							
							if (QuarkDef.Type.GPU == qd.type) {
								qd.source = renameFunctions(quarkUtilFunctions, qd, bodyFirstTok, bodyLastTok);
							} else {
								qd.source = to!(typeof(qd.source))(this.source
										[tokens[bodyFirstTok].start .. tokens[bodyLastTok].start + tokens[bodyLastTok].length]);
							}
							
							qd.sourceFirstLine = sourceFirstLine;
							
							advance;
							return;
						}
						break;
						
					default: break;
				}
				
				advance;
			}
		}
		
		
		char[] renameFunctions(bool[char[]] quarkUtilFunctions, QuarkDef quark, int firstTok, int lastTok) {
			int initialLength = (tokens[lastTok].start + tokens[lastTok].length) - tokens[firstTok].start;
			
			int tokIsFunc(int i) {
				i += firstTok;
				auto t = tokens[i];
				if (Token.Type.Ident == t.type && i+1 < tokens.length && Token.Type.LParen == tokens[i+1].type) {
					if (str8(t) in quarkUtilFunctions) {
						return true;
					}
				}
				return false;
			}
			
			char[] res;
			int prevEnd = 0;
			
			foreach (i, tok; tokens[firstTok .. lastTok]) {
				char[] val = null;
				if (tokIsFunc(i)) {
					//assert (false, to!(char[])(source[tokens[firstTok].start .. tokens[lastTok].start + tokens[lastTok].length]));
					val = renamedFuncName(quark, str8(tok));
					//val = "___" ~ quark.name ~ "_" ~ str8(tok);
					//assert (false, val);
				} else{
					val = str8(tok);
				}
				int src = tok.start;
				
				if (src - prevEnd > 0 && i > 0) {
					res ~= to!(char[])(source[prevEnd..src]);
				}
				
				res ~= val;
				prevEnd = src+tok.length;
			}

			int endIdx = tokens[lastTok].start + tokens[lastTok].length;
			if (prevEnd < endIdx) {
				res ~= to!(char[])(source[prevEnd..endIdx]);
			}
			
			/+Stdout(res).newline;
			Stdout.formatln("first: {} last: {}", firstTok, lastTok);
			assert (false);+/
			return res;
		}
	}
}+/
