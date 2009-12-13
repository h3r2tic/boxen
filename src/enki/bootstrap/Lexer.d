module enki.bootstrap.Lexer;
private import enki.bootstrap.bootstrap;
class Lexer : Bootstrap{
    public char[] getHelp(){ return ""; }
    void runBootstrap(){

		setAttribute("all","copyright","
	Copyright (c) 2008 Eric Anderton
	
	Permission is hereby granted, free of charge, to any person
	obtaining a copy of this software and associated documentation
	files (the \"Software\"), to deal in the Software without
	restriction, including without limitation the rights to use,
	copy, modify, merge, publish, distribute, sublicense, and/or
	sell copies of the Software, and to permit persons to whom the
	Software is furnished to do so, subject to the following
	conditions:
	
	The above copyright notice and this permission notice shall be
	included in all copies or substantial portions of the Software.
	
	THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND,
	EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
	OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
	NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
	HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
	WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
	FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
	OTHER DEALINGS IN THE SOFTWARE.
");
		setAttribute("d","header","module enki.frontend.Enki2Lexer;
import enki.EnkiToken;
import enki.frontend.EnkiLexerBase;
");
		setAttribute("d","baseclass","EnkiLexerBase");
		setAttribute("d","filename","./enki/frontend/Enki2Lexer.d");
		setAttribute("d","classname","Enki2Lexer");
		setAttribute("bootstrap","modulename","./enki.bootstrap.Lexer");
		setAttribute("bootstrap","filename","./enki/bootstrap/Lexer.d");
		setAttribute("bootstrap","classname","Lexer");		
		setAttribute("bnf","filename","enki/frontend/Enki2Lexer.bnf");
		
		addRule("Syntax",
			new BindingPredicate(new Param("EnkiToken[]","tokens")),
			Iterator.create(
				/*expr*/new OrGroup(
					new Production("Whitespace"),
					new Production("SlashStarComment"),
					new Production("SlashSlashComment"),
					new Production("NestingComment"),
					new Production("RegexLiteral",CatBinding("tokens")),
					new Production("StringLiteral",CatBinding("tokens")),
					new Production("Number",CatBinding("tokens")),
					new Production("Hex",CatBinding("tokens")),
					new Production("SpecialToken",CatBinding("tokens")),
					new Production("Identifier",CatBinding("tokens")),
					new Production("LiteralToken",CatBinding("tokens")),
					new Literal("err",
						new StringProductionArg("Unexpected char")
					)
				),
				/*delimeter*/null,
				/*terminator*/new Production("eoi"),
				/*ranges*/rangeList(Range.ZeroOrMore())
			)
		);

		addRule("Whitespace",
			Iterator.create(
				/*expr*/new OrGroup(
					new Terminal(" "),
					new Terminal("\t"),
					new Terminal("\r"),
					new Terminal("\n")
				),
				/*delimeter*/null,
				/*terminator*/null,
				/*ranges*/rangeList(Range.OneOrMoreAlias())
			)
		);

		addRule("SlashStarComment",
			paramList(
				new Param("String","err","Expected closing */")
			),
			new AndGroup(
				new Terminal("/*"),
				new ErrorPoint(new BindingProductionArg("err"),
					Iterator.create(
						/*expr*/new Production("any"),
						/*delimeter*/null,
						/*terminator*/new Terminal("*/"),
						/*ranges*/rangeList(Range.ZeroOrMore())
					)
				)
			)
		);

		addRule("SlashSlashComment",
			paramList(
				new Param("String","err","Expected terminating newline")
			),
			new AndGroup(
				new Terminal("//"),
				new ErrorPoint(new BindingProductionArg("err"),
					Iterator.create(
						/*expr*/new Production("any"),
						/*delimeter*/null,
						/*terminator*/new OrGroup(
							new Terminal("\n"),
							new Production("eoi")
						),
						/*ranges*/rangeList(Range.ZeroOrMore())
					)
				)
			)
		);

		addRule("NestingComment",
			paramList(
				new Param("String","err","Expected closing +/")
			),
			new AndGroup(
				new Terminal("/+"),
				new ErrorPoint(new BindingProductionArg("err"),
					Iterator.create(
						/*expr*/new OrGroup(
							new Production("NestingComment"),
							new Production("any")
						),
						/*delimeter*/null,
						/*terminator*/new Terminal("+/"),
						/*ranges*/rangeList(Range.ZeroOrMore())
					)
				)
			)
		);

		addRule("RegexLiteral",
			new FunctionPredicate(new Param("EnkiToken","RegexToken"),
				new Param("String","text")
			),
			paramList(
				new Param("String","err","Expected closing `")
			),
			new AndGroup(
				new Terminal("`"),
				new ErrorPoint(new BindingProductionArg("err"),
					Iterator.create(
						/*expr*/new Production("any",new Binding("text")),
						/*delimeter*/null,
						/*terminator*/new Terminal("`"),
						/*ranges*/rangeList(Range.ZeroOrMore())
					)
				)
			)
		);

		addRule("StringLiteral",
			new FunctionPredicate(new Param("EnkiToken","StringToken"),
				new Param("String","text")
			),
			paramList(
				new Param("String","err1","Expected closing \"\"\""),
				new Param("String","err2","Expected closing \""),
				new Param("String","err3","Expected closing \'")
			),
			new OrGroup(
				new Group(
					new AndGroup(
						new Terminal("\"\"\""),
						new ErrorPoint(new BindingProductionArg("err1"),
							Iterator.create(
								/*expr*/new Production("any",CatBinding("text")),
								/*delimeter*/null,
								/*terminator*/new Terminal("\"\"\""),
								/*ranges*/rangeList(Range.ZeroOrMore())
							)
						)
					)
				),
				new Group(
					new AndGroup(
						new Terminal("\""),
						new ErrorPoint(new BindingProductionArg("err2"),
							Iterator.create(
								/*expr*/new Production("StringChar",CatBinding("text")),
								/*delimeter*/null,
								/*terminator*/new Terminal("\""),
								/*ranges*/rangeList(Range.ZeroOrMore())
							)
						)
					)
				),
				new Group(
					new AndGroup(
						new Terminal("\'"),
						new ErrorPoint(new BindingProductionArg("err2"),
							Iterator.create(
								/*expr*/new Production("StringChar",CatBinding("text")),
								/*delimeter*/null,
								/*terminator*/new Terminal("\'"),
								/*ranges*/rangeList(Range.ZeroOrMore())
							)
						)
					)
				)				
			)
		);
		
		addRule("StringChar",
			new BindingPredicate(new Param("String","ch")),
			new OrGroup(
				new AndGroup(
					new Terminal("\\"),
					new Group(
						new OrGroup(
							new AndGroup(
								new Terminal("n"),
								new Literal("NEWLINE",new Binding("ch"))
							),
							new AndGroup(
								new Terminal("r"),
								new Literal("CARRAIGE_RETURN",new Binding("ch"))
							),
							new AndGroup(
								new Terminal("t"),
								new Literal("TAB",new Binding("ch"))
							),												
							new AndGroup(
								new Terminal("\""),
								new Literal("DOUBLE_QUOTE",new Binding("ch"))
							),
							new AndGroup(
								new Terminal("\'"),
								new Literal("SINGLE_QUOTE",new Binding("ch"))
							),
							new AndGroup(
								new Terminal("\\"),
								new Literal("SLASH",new Binding("ch"))
							),
							new Literal("err",
								new StringProductionArg("Unexpected escape sequence")
							)
						)
					)
				),
				new Production("any",new Binding("ch"))
			)
		);

		addRule("Hex",
			new FunctionPredicate(new Param("EnkiToken","HexToken"),
				new Param("String","text")
			),
			paramList(
				new Param("String","err","Expected two, four or eight hex digits")
			),
			new AndGroup(
				new Terminal("#"),
				new ErrorPoint(new BindingProductionArg("err"),
					new Group(
						Iterator.create(
							/*expr*/new OrGroup(
								new CharRange(0x30,0x39),
								new CharRange(0x41,0x46),
								new CharRange(0x61,0x66)
							),
							/*delimeter*/null,
							/*terminator*/null,
							/*ranges*/rangeList(Range.OneOrMoreAlias(),Range(2,2),Range(4,4),Range(8,8))
						),
						new Binding("text")
					)
				)
			)
		);

		addRule("Number",
			new FunctionPredicate(new Param("EnkiToken","NumberToken"),
				new Param("String","text")
			),
			Iterator.create(
				/*expr*/new CharRange(0x30,0x39,CatBinding("text")),
				/*delimeter*/null,
				/*terminator*/null,
				/*ranges*/rangeList(Range.OneOrMore())
			)
		);

		addRule("Identifier",
			new FunctionPredicate(new Param("EnkiToken","IdentifierToken"),
				new Param("String","text")
			),
			new Group(
				new AndGroup(
					new Group(
						new OrGroup(
							new CharRange(0x41,0x5A),
							new CharRange(0x61,0x7A),
							new Terminal("_")
						)
					),
					Iterator.create(
						/*expr*/new OrGroup(
							new CharRange(0x30,0x39),
							new CharRange(0x41,0x5A),
							new CharRange(0x61,0x7A),
							new Terminal("_")
						),
						/*delimeter*/null,
						/*terminator*/null,
						/*ranges*/rangeList(Range.ZeroOrMore())
					)
				),
				new Binding("text")
			)
		);
		
		addRule("SpecialToken",
			new FunctionPredicate(new Param("EnkiToken","CreateToken"),
				new Param("String","text"),
				new Param("uint","tok")
			),
			new OrGroup(
				new AndGroup(
					new Terminal("new"),
					new Literal("TOK_NEW",new Binding("tok"))
				),
				new AndGroup(
					new Terminal("::="),
					new Literal("TOK_RULEASSIGN",new Binding("tok"))
				),
				new AndGroup(
					new Terminal("?!"),
					new Literal("TOK_ERRORPOINT",new Binding("tok"))
				),
				new AndGroup(
					new Terminal(".."),
					new Literal("TOK_RANGE",new Binding("tok"))
				)
			)
		);

		addRule("LiteralToken",
			new FunctionPredicate(new Param("EnkiToken","LiteralToken"),
				new Param("String","text")
			),
			new Group(
				new OrGroup(
					new CharRange(0x21,0x2F),
					new CharRange(0x3A,0x40),
					new CharRange(0x5B,0x60),
					new CharRange(0x7B,0x7E)
				),
				new Binding("text")
			)
		);
	}
}
