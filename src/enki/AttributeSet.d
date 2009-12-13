/+
    Copyright (c) 2006-2008 Eric Anderton

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
module enki.AttributeSet;

debug import tango.io.Stdout;

alias char[][char[]] AttributeMap;

struct AttributeSet{
	alias char[] String;	
	public AttributeMap[String] attributes;

	String get(String name){
		return get("all",name);
	}

	String get(String namespace,String name,String defaultValue=""){
		if(namespace in attributes && name in attributes[namespace]){
			//debug Stdout.format("AttributeSetT.get({0}.{1}): {2}",namespace,name,attributes[namespace][name]).newline;
			return attributes[namespace][name];
		}
		//else if("all" in attributes && name in attributes["all"]){
		//	//debug Stdout.format("AttributeSetT.get(all.{1}): {2}",namespace,name,attributes["all"][name]).newline;
		//	return attributes["all"][name];
		//}
		else return defaultValue;
	}

	void set(String namespace,String name,String value){
		if(namespace){
		    if(!(namespace in attributes)) attributes[namespace] = null;
		    attributes[namespace][name] = value;
		}
		//if(namespace != "all"){
		//	if(!("all" in attributes)) attributes["all"] = null;
		//	attributes["all"][name] = value;
		//}

		//debug Stdout.format("AttributeSetT.set({0}.{1}): {2}",namespace,name,attributes["all"][name]).newline;
	}

	void set(String name,String value){
	    if(!("all" in attributes)) attributes["all"] = null;
		attributes["all"][name] = value;
	}

	void mesh(AttributeSet otherSet){
		foreach(String namespace,AttributeMap innerAttrs; otherSet.attributes){
		    AttributeMap *map;
		    if(!(namespace in attributes)) attributes[namespace] = null;
		    map = &(attributes[namespace]);
			foreach(name,value; innerAttrs){
				(*map)[name] = value;
			}
		}
	}
}

unittest{
    AttributeSet attrs;

    attrs.set("foo","bar","hello world");
    assert(attrs.get("foo","bar") == "hello world");
    assert(attrs.get("all","bar") == "hello world");
    assert(attrs.get("bar") == "hello world");
}
