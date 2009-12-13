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
module enki.frontend.Frontend;

private import enki.types;
private import enki.EnkiToken;

private import enkilib.d.Parser;
private import enkilib.d.ParserException;

private import tango.io.device.File;
private import tango.io.FilePath;

debug import tango.io.Stdout;

interface Frontend{
    public char[] getHelp();
	public void initialize(FilePath path);
	public bool parse();
	public void semanticPass();
	public AttributeSet getAttributes();
	public RuleSet getRules();
	public void debugParser();
}

/**
    Base class for for all parser front-ends
**/
public abstract class FrontendBase(TokenType,LexerType) : Parser!(TokenType),Frontend{
    alias char[] String;
	protected AttributeSet attributes;
	protected RuleSet ruleSet;
        
	public this(){
		ruleSet = new RuleSet();
		
		// add implicitly defined productions from the parser
		ruleSet.addRule(new RulePrototype("nop","bool"));
		ruleSet.addRule(new RulePrototype("any","String"));
		ruleSet.addRule(new RulePrototype("eoi","bool"));
		ruleSet.addRule(new RulePrototype("err","bool"));
	}
    
    public char[] getHelp(){
        return "";
    }
    
	public AttributeSet getAttributes(){
		return attributes;
	}
	
	public RuleSet getRules(){
		return ruleSet;
	}
	
	public void addRule(Rule rule){
		ruleSet.addRule(rule);
	}

	public void addRule(String name,Param[] ruleParameters,RulePredicate pred,Param[] vars,Expression expr){
		addRule(new RuleDefinition(name,ruleParameters,pred,vars,expr));
	}

	public void setAttribute(String namespace,String name,String value){
		attributes.set(namespace,name,value);
	}

	public void addAlias(String name,String aliasRule){
		ruleSet.addRule(new RuleAlias(name,aliasRule));
	}

	public void addPrototype(String name,String returnType){
		ruleSet.addRule(new RulePrototype(name,returnType));
	}

	public void semanticPass(){
		// perform semantic pass of all rules
		ruleSet.semanticPass(attributes);
		debug Stdout("Semantic pass complete.").newline;
	}
	
	public void runDirective(String name,String[] args){
		if(name == "include"){
			foreach(arg; args){
				includeFile(arg);
			}
		}
		else{
			throw new Exception("Unknown directive '" ~ name ~ "'");
		}
	}

	protected TokenType[] getTokensFromFile(FilePath path){		
		auto inFile = new File(path.toString());
		auto lexer = new LexerType();
		lexer.initialize(cast(char[])inFile.load(),path.toString());
		
		if(!lexer.parse_Syntax()){
			throw ParserException("Lexer Fail");
		}	
		return lexer.value_Syntax;
	}
	
	/**
		Performs the lexer pass.
	*/
	void initialize(FilePath path){
		super.initialize(getTokensFromFile(path));
	}
	
	/**
		Provides support for the include directive.
		
		Implementation launches another lexer instance and inserts the lexed tokens into the stream,
		at the current position.
	*/
	void includeFile(String filename){
		debug Stdout.format("including {0}",filename).newline;
		data = data[0..pos] ~ getTokensFromFile(new FilePath(filename)) ~ data[pos..$];
		debug Stdout.format("include done").newline;
	}
	
	bool parse_Syntax();
	
	bool parse(){
		return this.parse_Syntax();
	}
	
	public void debugParser(){
		debug{
			Stdout.format("Lexer data:").newline;
			foreach(i,foo; data){
				Stdout.format("{3} {0} {1} '{2}'",i,foo.type,foo.value,foo.filename).newline;
			}

			Stdout.format("Parser data {0} rules:",ruleSet.getRules().length).newline;
			foreach(rule; ruleSet.getRules()){
				Stdout.format("{0} {1}",rule.insertOrder,rule.getName).newline;
			}
			
			Stdout.format("Attributes:").newline;
			foreach(namespace,attribSet; this.attributes.attributes){
				foreach(name,value; attribSet){
					Stdout.format("{0}-{1} = {2}",namespace,name,value).newline;
				}
			}
		}	    		
	}
}
