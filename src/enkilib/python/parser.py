#
#     Copyright (c) 2008 Eric Anderton
#
#     Permission is hereby granted, free of charge, to any person
#     obtaining a copy of this software and associated documentation
#     files (the "Software"), to deal in the Software without
#     restriction, including without limitation the rights to use,
#     copy, modify, merge, publish, distribute, sublicense, and/or
#     sell copies of the Software, and to permit persons to whom the
#     Software is furnished to do so, subject to the following
#     conditions:
#
#     The above copyright notice and this permission notice shall be
#     included in all copies or substantial portions of the Software.
#
#     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#     EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
#     OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#     NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
#     HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
#     WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
#     FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
#     OTHER DEALINGS IN THE SOFTWARE.
#

class Parser:
   def parse(self,input):
        self.input = input
        self.position = 0
        return self.parse_Syntax()
        
    def eoi(self):
        if self.position >= len(self.input):
            return True
        return False
        
    def any(self):
        if self.position >= len(self.input):
            return False
        self.position = self.position + 1
        return True
        
    def peek(self):
        if self.position >= len(self.input):
            return ""
        else:
            return self.input[self.position]
        
    def DEBUG(self,text=""):
        def inner():
            print text,self.position,self.input[self.position:]
            return True
        return inner
        
    def REQUIRED(self,text,term=None):
        def inner():
            if term != None and term():
                return True
            raise ParseException(text,self.position,self.peek())
        return inner
        
    def TERMINAL(self,value,err=None):
        def inner():    
            #print "len: ",len(self.input)," pos: ",self.position,"(",self.input[self.position:],") val: ",value
            if self.position == len(self.input):
                if err != None:
                    raise ParseException(text,self.position,self.peek())
                return False
            if self.input[self.position:].startswith(value):
                self.position += len(value);
                #print "matched: ",value," moved to: ",self.position
                return True
            return False
        return inner
        
    def RANGE(self,start,end):
        def inner():
            #print "len: ",len(self.input)," pos: ",self.position,"(",self.input[self.position:],") range: ",start,"-",end,
            if self.position == len(self.input):
                return False
            ch = self.input[self.position]
            if ch >= start[0] and ch <= end[0]:
                self.position = self.position + 1
                #print "matched: ",start,"-",end," moved to: ",self.position
                return True
            return False
        return inner
            
    def AND(self,*args):
        def inner():  
            pos = self.position
            for term in args:
                if not term():
                    self.position = pos
                    return False
            return True
        return inner
    
    def OR(self,*args):
        def inner():  
            for term in args:
                if term():
                    return True
            return False
        return inner
        
    def OPTIONAL(self,term):
        def inner():  
            term()
            return True
        return inner
        
    def NOT(self,term):
        def inner():  
            pos = self.position
            if term():
                self.position = pos
                return False
            return True
        return inner
        
    def ZEROORMORE(self,term,terminator = None,err=None): 
        def inner():  
            if terminator == None:
                while(not self.eoi() and term()):
                    pass
            else:
                while(not self.eoi() and not terminator() and term()):
                    pass
            return True
        return inner
        
    def ONEORMORE(self,term,terminator = None):
        def inner():
            pos = self.position
            if terminator and terminator():
                self.position = pos
                return False
            if not term():
                self.position = pos
                return False        
            if terminator == None:
                while(not self.eoi() and term()):
                    pass
            else:
                while(not self.eoi() and not terminator() and term()):
                    pass
            return True
        return inner