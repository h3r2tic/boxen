module enki.bootstrap.Parser;
private import enki.bootstrap.bootstrap;
class Parser: Bootstrap{
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
		setAttribute("d","header","module enki.frontend.Enki2Parser;
private import enki.frontend.Frontend;
private import enki.frontend.Enki2ParserBase;
private import enki.EnkiToken;
private import enki.Binding;
private import enki.Expression;
private import enki.Param;
private import enki.ProductionArg;
private import enki.Rule;
private import enki.RulePredicate;
");		
		setAttribute("d","baseclass","Enki2ParserBase");
		setAttribute("d","filename","enki/frontend/Enki2Parser.d");
		setAttribute("d","classname","Enki2Parser");
		setAttribute("bootstrap","modulename","enki.bootstrap.Parser");
		setAttribute("bootstrap","filename","enki/bootstrap/Parser.d");
		setAttribute("bootstrap","classname","Parser");
		setAttribute("bnf","filename","enki/frontend/Enki2Parser.bnf");
		addRule("Syntax",
			Iterator.create(
				/*expr*/new OrGroup(
					new Production("Prototype"),
					new Production("Alias"),
					new Production("Rule"),
					new Production("Directive"),
					new Production("Attribute")
				),
				/*delimeter*/null,
				/*terminator*/new Production("eoi"),
				/*ranges*/rangeList(Range.ZeroOrMore())
			)
		);

		addRule("Prototype",
			new FunctionPredicate(new Param("void","addPrototype"),
				new Param("String","name"),
				new Param("String","returnType")
			),
			new AndGroup(
				new Production("Identifier",new Binding("name")),
				new Terminal("="),
				new Production("Identifier",new Binding("returnType")),
				new Terminal(";")
			)
		);

		addRule("Alias",
			new FunctionPredicate(new Param("void","addAlias"),
				new Param("String","aliasName"),
				new Param("String","ruleName")
			),
			new AndGroup(
				new Production("Identifier",new Binding("aliasName")),
				new CustomTerminal("TOK_RULEASSIGN"),
				new Production("Identifier",new Binding("ruleName")),
				new Terminal(";")
			)
		);

		addRule("Rule",
			new FunctionPredicate(new Param("void","addRule"),
				new Param("String","name"),
				new Param("Param[]","decl"),
				new Param("RulePredicate","pred"),
				new Param("Param[]","vars"),
				new Param("Expression","expr")
			),
			paramList(
				new Param("String","err1","Missing ';'"),
				new Param("String","err2","Expected '::='")
			),
			new AndGroup(
				new Production("Identifier",new Binding("name")),
				new Optional(
					new Production("RuleDecl",new Binding("decl"))
				),
				new Optional(
					new Production("RulePredicate",new Binding("pred"))
				),
				new ErrorPoint(
					new BindingProductionArg("err2"),
					Iterator.create(
						/*expr*/new Production("RuleVar",CatBinding("vars")),
						/*delimeter*/null,
						/*terminator*/new CustomTerminal("TOK_RULEASSIGN"),
						/*ranges*/rangeList(Range.ZeroOrMore())
					)
				),			
				new Production("Expression",CatBinding("expr")),
				new ErrorPoint(new BindingProductionArg("err1"),
					new Terminal(";")
				)
			)
		);

		addRule("RuleDecl",
			new BindingPredicate(new Param("Param[]","params")),
			new Production("ParamsExpr",new Binding("params"))
		);

		addRule("RulePredicate",
			new BindingPredicate(new Param("RulePredicate","pred")),
			new AndGroup(
				new Terminal("="),
				new Group(
					new OrGroup(
						new Production("ClassPredicate",new Binding("pred")),
						new Production("FunctionPredicate",new Binding("pred")),
						new Production("BindingPredicate",new Binding("pred")),
						new Literal("err",
							new StringProductionArg("Expected Rule Predicate.")
						)
					)
				)
			)
		);

		addRule("ClassPredicate",
			new ClassPredicate("ClassPredicate",
				new Param("String","name"),
				new Param("Param[]","params")
			),
			new AndGroup(
				new CustomTerminal("TOK_NEW"),
				new Production("Identifier",new Binding("name")),
				new Production("ParamsExpr",new Binding("params"))
			)
		);

		addRule("FunctionPredicate",
			new ClassPredicate("FunctionPredicate",
				new Param("Param","decl"),
				new Param("Param[]","params")
			),
			new AndGroup(
				new Production("ExplicitParam",new Binding("decl")),
				new Production("ParamsExpr",new Binding("params"))
			)
		);

		addRule("BindingPredicate",
			new ClassPredicate("BindingPredicate",
				new Param("Param","param")
			),
			new Production("Param",new Binding("param"))
		);

		addRule("RuleVar",
			new BindingPredicate(new Param("Param","var")),
			new AndGroup(
				new Terminal("$"),
				new Production("Param",new Binding("var"))
			)
		);

		addRule("ParamsExpr",
			new BindingPredicate(new Param("Param[]","params")),
			new AndGroup(
				new Terminal("("),
				Iterator.create(
					/*expr*/new Production("Param",CatBinding("params")),
					/*delimeter*/new Terminal(","),
					/*terminator*/new Terminal(")"),
					/*ranges*/rangeList(Range.ZeroOrMore())
				)
			)
		);

		addRule("Param",
			new BindingPredicate(new Param("Param","param")),
			new OrGroup(
				new Production("ExplicitParam",new Binding("param")),
				new Production("WeakParam",new Binding("param"))
			)
		);

		addRule("WeakParam",
			new ClassPredicate("Param",
				new Param("String","type"),
				new Param("String","name"),
				new Param("String","value")
			),
			new AndGroup(
				new Production("Identifier",new Binding("name")),
				new Optional(
					new AndGroup(
						new Terminal("="),
						new CustomTerminal("TOK_STRING",new Binding("value"))
					)
				)
			)
		);

		addRule("ExplicitParam",
			new ClassPredicate("Param",
				new Param("String","type"),
				new Param("String","name"),
				new Param("String","value")
			),
			new AndGroup(
				new Production("ParamType",new Binding("type")),
				new Production("Identifier",new Binding("name")),
				new Optional(
					new AndGroup(
						new Terminal("="),
						new CustomTerminal("TOK_STRING",new Binding("value"))
					)
				)
			)
		);

		addRule("ParamType",
			new AndGroup(
				new Production("Identifier"),
				new Optional(
					new AndGroup(
						new Terminal("["),
						new Optional(
							new Production("ParamType")
						),
						new Terminal("]")
					)
				)
			)
		);

		addAlias("Expression","OrGroup");

		addRule("OrGroup",
			new ClassPredicate("OrGroup",
				new Param("Expression[]","exprs")
			),
			Iterator.create(
				/*expr*/new Production("AndGroup",CatBinding("exprs")),
				/*delimeter*/new Terminal("|"),
				/*terminator*/null,
				/*ranges*/rangeList(Range.OneOrMoreAlias())
			)
		);

		addRule("AndGroup",
			new ClassPredicate("AndGroup",
				new Param("Expression[]","exprs")
			),
			Iterator.create(
				/*expr*/new Production("SubExpression",CatBinding("exprs")),
				/*delimeter*/null,
				/*terminator*/null,
				/*ranges*/rangeList(Range.OneOrMoreAlias())
			)
		);

		addRule("SubExpression",
			new BindingPredicate(new Param("Expression","expr")),
			new AndGroup(
				new Group(
					new OrGroup(
						new Production("Production",new Binding("expr")),
						new Production("Substitution",new Binding("expr")),
						new Production("Terminal",new Binding("expr")),
						new Production("CharacterRange",new Binding("expr")),
						new Production("Regexp",new Binding("expr")),
						new Production("GroupExpr",new Binding("expr")),
						new Production("OneOrMoreExpr",new Binding("expr")),
						new Production("OptionalExpr",new Binding("expr")),
						new Production("NegateExpr",new Binding("expr")),
						new Production("TestExpr",new Binding("expr")),
						new Production("LiteralExpr",new Binding("expr")),
						new Production("CustomTerminal",new Binding("expr")),
						new Production("ErrorPoint",new Binding("expr"))
					)
				),
				new Optional(
					new Production("IteratorExpr",new Binding("expr"),
						new BindingProductionArg("expr")
					)
				)
			)
		);

		addRule("Production",
			new ClassPredicate("Production",
				new Param("String","name"),
				new Param("Binding","binding"),
				new Param("ProductionArg[]","args")
			),
			new AndGroup(
				new Production("Identifier",new Binding("name")),
				new Optional(
					new AndGroup(
						new Terminal("!"),
						new Terminal("("),
						Iterator.create(
							/*expr*/new Production("ProductionArg",CatBinding("args")),
							/*delimeter*/new Terminal(","),
							/*terminator*/new Terminal(")"),
							/*ranges*/rangeList(Range.ZeroOrMore())
						)
					)
				),
				new Optional(
					new Production("Binding",new Binding("binding"))
				)
			)
		);

		addRule("ProductionArg",
			new BindingPredicate(new Param("ProductionArg","arg")),
			new OrGroup(
				new Production("StringProductionArg",new Binding("arg")),
				new Production("BindingProductionArg",new Binding("arg"))
			)
		);

		addRule("StringProductionArg",
			new ClassPredicate("StringProductionArg",
				new Param("String","value")
			),
			new CustomTerminal("TOK_STRING",new Binding("value"))
		);

		addRule("BindingProductionArg",
			new ClassPredicate("BindingProductionArg",
				new Param("String","value")
			),
			new Production("Identifier",new Binding("value"))
		);

		addRule("Substitution",
			new ClassPredicate("Substitution",
				new Param("String","name"),
				new Param("Binding","binding")
			),
			new AndGroup(
				new Terminal("."),
				new Production("Identifier",CatBinding("name")),
				new Optional(
					new Production("Binding",new Binding("binding"))
				)
			)
		);

		addRule("GroupExpr",
			new ClassPredicate("Group",
				new Param("Expression","expr"),
				new Param("Binding","binding")
			),
			new AndGroup(
				new Terminal("("),
				new Production("Expression",new Binding("expr")),
				new Terminal(")"),
				new Optional(
					new Production("Binding",new Binding("binding"))
				)
			)
		);

		addRule("OneOrMoreExpr",
			new ClassPredicate("OneOrMoreExpr",
				new Param("Expression","expr"),
				new Param("Binding","binding")
			),
			new AndGroup(
				new Terminal("{"),
				new Production("Expression",new Binding("expr")),
				new Terminal("}"),
				new Optional(
					new Production("Binding",new Binding("binding"))
				)
			)
		);

		addRule("IteratorExpr",
			paramList(
				new Param("Expression","expr")
			),
			new FunctionPredicate(new Param("Expression","Iterator.create"),
				new Param("Expression","expr"),
				new Param("Expression","delim"),
				new Param("Expression","term"),
				new Param("Range[]","ranges")
			),
			new AndGroup(
				new Group(
					new OrGroup(
						new AndGroup(
							new Production("RangeSetExpr",new Binding("ranges")),
							new Optional(
								new AndGroup(
									new Terminal("%"),
									new Production("SubExpression",new Binding("delim"))
								)
							)
						),
						new AndGroup(
							new Terminal("%"),
							new Production("SubExpression",new Binding("delim"))
						)
					)
				),
				new Optional(
					new Production("SubExpression",new Binding("term"))
				)
			)
		);

		addRule("RangeSetExpr",
			new BindingPredicate(new Param("Range[]","ranges")),
			new OrGroup(
				new Production("ZeroOrMoreRange",CatBinding("ranges")),
				new Production("OneOrMoreRange",CatBinding("ranges")),
				new Production("OptionalRange",CatBinding("ranges")),
				new AndGroup(
					new Terminal("<"),
					Iterator.create(
						/*expr*/new Production("IteratorRangeExpr",CatBinding("ranges")),
						/*delimeter*/new Terminal(","),
						/*terminator*/new Terminal(">"),
						/*ranges*/rangeList(Range.OneOrMoreAlias())
					)
				)
			)
		);

		addRule("ZeroOrMoreRange",
			new FunctionPredicate(new Param("Range","Range.ZeroOrMore")),
			new Terminal("*")
		);

		addRule("OneOrMoreRange",
			new FunctionPredicate(new Param("Range","Range.OneOrMore")),
			new Terminal("+")
		);

		addRule("OptionalRange",
			new FunctionPredicate(new Param("Range","Range.Optional")),
			new Terminal("?")
		);

		addRule("IteratorRangeExpr",
			new FunctionPredicate(new Param("Range","Range"),
				new Param("int","start"),
				new Param("int","end")
			),
			new OrGroup(
				new AndGroup(
					new CustomTerminal("TOK_RANGE"),
					new CustomTerminal("TOK_NUMBER",new Binding("end"))
				),
				new AndGroup(
					new Test(
						new CustomTerminal("TOK_NUMBER",new Binding("start"))
					),
					new CustomTerminal("TOK_NUMBER",new Binding("end")),
					new Optional(
						new AndGroup(
							new CustomTerminal("TOK_RANGE"),
							new CustomTerminal("TOK_NUMBER",new Binding("end"))
						)
					)
				)
			)
		);

		addRule("OptionalExpr",
			new ClassPredicate("Optional",
				new Param("Expression","expr"),
				new Param("Binding","binding")
			),
			paramList(
				new Param("String","err1","Expected Expression"),
				new Param("String","err2","Expected Closing ']'")
			),
			new AndGroup(
				new Terminal("["),
				new ErrorPoint(new BindingProductionArg("err1"),
					new Production("Expression",new Binding("expr"))
				),
				new ErrorPoint(new BindingProductionArg("err2"),
					new Terminal("]")
				),
				new Optional(
					new Production("Binding",new Binding("binding"))
				)
			)
		);

		addRule("Terminal",
			new ClassPredicate("Terminal",
				new Param("String","text"),
				new Param("Binding","binding")
			),
			new AndGroup(
				new CustomTerminal("TOK_STRING",new Binding("text")),
				new Optional(
					new Production("Binding",new Binding("binding"))
				)
			)
		);

		addRule("CharacterRange",
			new ClassPredicate("CharRange",
				new Param("String","start"),
				new Param("String","end"),
				new Param("Binding","binding")
			),
			new AndGroup(
				new Test(
					new CustomTerminal("TOK_HEX",new Binding("end"))
				),
				new CustomTerminal("TOK_HEX",new Binding("start")),
				new Optional(
					new AndGroup(
						new Terminal("-"),
						new CustomTerminal("TOK_HEX",new Binding("end"))
					)
				),
				new Optional(
					new Production("Binding",new Binding("binding"))
				)
			)
		);

		addRule("Regexp",
			new ClassPredicate("RegularExpression",
				new Param("String","text"),
				new Param("Binding","binding")
			),
			new AndGroup(
				new CustomTerminal("TOK_REGEX",new Binding("text")),
				new Optional(
					new Production("Binding",new Binding("binding"))
				)
			)
		);

		addRule("NegateExpr",
			new ClassPredicate("Negate",
				new Param("Expression","expr")
			),
			new AndGroup(
				new Terminal("^"),
				new Production("SubExpression",new Binding("expr"))
			)
		);

		addRule("TestExpr",
			new ClassPredicate("Test",
				new Param("Expression","expr")
			),
			new AndGroup(
				new Terminal("/"),
				new Production("SubExpression",new Binding("expr"))
			)
		);

		addRule("LiteralExpr",
			new ClassPredicate("Literal",
				new Param("String","name"),
				new Param("Binding","binding"),
				new Param("ProductionArg[]","args")
			),
			new AndGroup(
				new Terminal("@"),
				new Production("Identifier",new Binding("name")),
				new Optional(
					new AndGroup(
						new Terminal("!"),
						new Terminal("("),
						Iterator.create(
							/*expr*/new Production("ProductionArg",CatBinding("args")),
							/*delimeter*/new Terminal(","),
							/*terminator*/new Terminal(")"),
							/*ranges*/rangeList(Range.ZeroOrMore())
						)
					)
				),
				new Optional(
					new Production("Binding",new Binding("binding"))
				)
			)
		);

		addRule("CustomTerminal",
			new ClassPredicate("CustomTerminal",
				new Param("String","name"),
				new Param("Binding","binding")
			),
			new AndGroup(
				new Terminal("&"),
				new Production("Identifier",new Binding("name")),
				new Optional(
					new Production("Binding",new Binding("binding"))
				)
			)
		);

		addRule("ErrorPoint",
			new ClassPredicate("ErrorPoint",
				new Param("ProductionArg","arg"),
				new Param("Expression","expr")
			),
			new AndGroup(
				new CustomTerminal("TOK_ERRORPOINT"),
				new Terminal("("),
				new Production("ProductionArg",new Binding("arg")),
				new Terminal(")"),
				new Production("SubExpression",new Binding("expr"))
			)
		);

		addRule("Binding",
			new ClassPredicate("Binding",
				new Param("String","name"),
				new Param("bool","isConcat")
			),
			new AndGroup(
				new Terminal(":"),
				new Optional(
					new AndGroup(
						new Terminal("~"),
						new Literal("true",new Binding("isConcat"))
					)
				),
				new Production("Identifier",new Binding("name"))
			)
		);

		addRule("Identifier",
			new FunctionPredicate(new Param("String","concatTokens"),
                new Param("Atom[]","value")
            ),
			new Group(
				Iterator.create(
					/*expr*/new CustomTerminal("TOK_IDENT"),
					/*delimeter*/new Terminal("."),
					/*terminator*/null,
					/*ranges*/rangeList(Range.OneOrMoreAlias())
				),
				new Binding("value")
			)
		);

		addRule("Directive",
			new FunctionPredicate(new Param("void","runDirective"),
				new Param("String","name"),
				new Param("String[]","args")
			),
			paramList(
				new Param("String","err1","Expected directive name"),
				new Param("String","err2","Expected ';'")
			),			
			new AndGroup(
				new Terminal("@"),
				new ErrorPoint(new BindingProductionArg("err1"),
					new Production("Identifier",new Binding("name"))
				),
				new Optional(
					new AndGroup(
						new Terminal("("),
						Iterator.create(
							/*expr*/new OrGroup(
								new Production("Identifier",CatBinding("args")),
								new CustomTerminal("TOK_STRING",CatBinding("args"))
							),
							/*delimeter*/new Terminal(","),
							/*terminator*/new Terminal(")"),
							/*ranges*/rangeList(Range.ZeroOrMore())
						)
					)
				),						
				new ErrorPoint(new BindingProductionArg("err2"),
					new Terminal(";")
				)
			)
		);

		addRule("Attribute",
			new FunctionPredicate(new Param("void","setAttribute"),
				new Param("String","namespace"),
				new Param("String","name"),
				new Param("String","value")
			),
			paramList(
				new Param("String","err1","Expected '='"),
				new Param("String","err1","Expected ';'")
			),
			new AndGroup(
				new Terminal("."),
				new Optional(
					new AndGroup(
						new CustomTerminal("TOK_IDENT",new Binding("namespace")),
						new Terminal("-")
					)
				),
				new CustomTerminal("TOK_IDENT",new Binding("name")),
				new ErrorPoint(new BindingProductionArg("err1"),
					new Terminal("=")
				),
				new Group(
					new OrGroup(
						new Production("Identifier",new Binding("value")),
						new CustomTerminal("TOK_STRING",new Binding("value"))
					)
				),
				new ErrorPoint(new StringProductionArg("err2"),
					new Terminal(";")
				)
			)
		);
	}
}
