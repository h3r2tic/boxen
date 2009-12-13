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
module enkilib.d.AST;

import tango.core.Variant;

debug import tango.io.Stdout;

/**
	Generic AST implementation.  Each node contains a slice of the input set, the name of
	the generating production, the value from the rule predicate (if applicable), and the 
	child AST nodes and all declared bindings.
	
	Be sure to compose your grammar with ".d-useast=true;" in order to enable this support.
	
	After the parse is complete, use getASTResult() to fetch the root AST node.
*/
class ASTParserT(ParserBase) : ParserBase{
	alias ASTNode[] ASTArray;
	
	public class ASTNode{
		public String name;
		public Variant value;
		public ASTArray children;
		public String slice;
		public uint start;
		
		public this(String name){
			this.name = name;
		}
				
		public void create(String name){
			this.name = name;
			this.children.length = 0;
			this.start = pos;
		}
	}
	
	private ASTNode freeNode;
	private ASTNode resultAST;
	
	public ASTNode createASTNode(String name){
		ASTNode thisNode;
		if(freeNode){
			thisNode = freeNode;
			freeNode = null;
			thisNode.create(name);
		}
		else{
			thisNode = new ASTNode(name);
		}
		
		return thisNode;
	}
	
	public void addASTChild(ASTNode node,String name,ASTNode child){
		node.children ~= child;
	}
	
	public void addASTChildValue(T)(ASTNode node,String name,T value){
		if(node is null) return;
		ASTNode valueNode = new ASTNode(name);
		valueNode.value = value;
		node.children ~= valueNode;
	}	
	
	public void setASTResult(ASTNode node){
		node.value = matchValue;
		node.slice = data[node.start..pos];
		debug Stdout("AST:'")(node.slice)("'").newline;
		resultAST = node;
	}
	
	public void clearASTResult(ASTNode node){
		if(node !is null){
			freeNode = node;
		}
		resultAST = null;
	}
	
	public ASTNode getASTResult(){
		return resultAST;
	}
		
	// override the parse_any primitive to set an AST node
	bool parse_nop(){
		setMatchValue(true);
		setASTResult(null);
		return true;
	}

	// override the parse_any primitive to set an AST node
	bool parse_any(){
		ASTNode __astNode = createASTNode("any");
		if(!hasMore()) return false;
		setMatchValue(data[pos..pos+1]);
		next();
		setASTResult(__astNode);
		return true;
	}
	
	// override the parse_eoi primitive to clear the AST node result
	bool parse_eoi(){
		bool result = !hasMore();
		setMatchValue(result);
		setASTResult(null);
		return result;
	}	
}
