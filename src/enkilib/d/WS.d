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
	Whitespace culling decorator for a character parser.
	
	Modifies the cursor behavior to set the match position to be the next
	non-whitespace character after the physical position.
*/
class WS(ParserBase) : ParserBase{	
	uint nextPos;
	
	uint getPos(){
		return pos;
	}
	
	uint getNextPos(){
		if(nextPos <= pos){
			for(nextPos=pos; nextPos < data.length && data[nextPos]<=32; nextPos++){
				//do nothing
			}
		}
		return nextPos;
	}
	
	void setPos(uint pos){
		pos = pos;
		nextPos = pos;
	}
	
	void next(uint amount=1){
		pos = nextPos+amount;
	}
}
