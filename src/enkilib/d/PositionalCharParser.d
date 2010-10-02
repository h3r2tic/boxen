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
module enkilib.d.PositionalCharParser;

import enkilib.d.Parser;
import enkilib.d.ParserException;

struct Position{
	uint line,col,byteNr;
}

// character lexeme stream with line/col support
class PositionalCharParser : Parser!(char){
	uint newlines[];
	char[] filename;
		
	void initialize(char[] data,char[] filename){
		super.initialize(data);
		
		this.filename = filename;
		
		// scan through data to find all of the newline positions
		foreach(i,ch; data){
			if(ch == '\n'){
				newlines ~= i;
			}
		}
	}
	
	Position getPosition(int offset){
		Position position;
		position.byteNr = pos+offset;
		
		// no newlines in file
		if(newlines.length == 0){
			position.line = 1;
			position.col = pos+offset+1;
			return position;
		}
		
		// get the first newline position that follows the current position
		foreach(i,newlinePos; newlines){		
			if(newlinePos > pos+offset){
				position.line = i+1;
				if(i==0){
					position.col = pos+offset+1;
				}
				else{
					position.col = pos+offset - newlines[i-1]+1;
				}
				return position;
			}
		}
		//must be somewhere between the last newline and eoi
		position.line = newlines.length+1;
		position.col = pos+offset - newlines[newlines.length-1]+1;
		return position;
	}
			
	void error(char[] message){
		auto position = getPosition(0);
		if(pos < data.length){
			throw ParserException("{} ({},{}): {} (got '{}' instead)",filename,position.line,position.col,message,data[pos]);
		}
		else{
			throw ParserException("{}({},{}): {} (got EOF instead)",filename,position.line,position.col,message);			
		}
	}
}
