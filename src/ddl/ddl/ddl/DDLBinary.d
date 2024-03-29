/+
	Copyright (c) 2005 Eric Anderton
        
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
module ddl.ddl.DDLBinary;

private import ddl.FileBuffer;
private import ddl.DDLReader;
private import ddl.DDLWriter;
private import ddl.Utils;

debug private import tango.io.Stdout;

/**
	Provides support for loading and saving DDL files.
*/
class DDLBinary{
	protected static const char[] MagicBytes = "DDL!";
	protected static const uint DDLVersion = 0x00010001;
	protected static const uint BufferSize = 4096;
	
	public char[] binaryType;
	public char[] processorArch;
	public char[][] definedNamespaces;
	public char[][] importedModules;
	public char[][char[]] attributes;
	public ubyte[] binaryData;
	
	public this(){
		// do nothing
	}
	
	/**
		Loads the entire file, and buffers the attached binary file
	*/	
	public void load(FileBuffer fileBuffer){
		DDLReader reader = new DDLReader(fileBuffer);
		
		ubyte[] magic;
		reader.get(magic,4);
		if(magic != cast(ubyte[])MagicBytes){
			throw new Exception("File is not a DDL library");
		}
		
		uint ver;
		reader.get(ver);
		if(ver != DDLVersion){
			throw new Exception("DDL library is the wrong version");
		}
			
		uint binaryStart;
		reader.get(binaryStart);
		reader.get(binaryType);
		reader.get(processorArch);
						
		debug debugLog("binaryStart: {0:X8} type: '{0}' arch: '{1}'",binaryStart,binaryType,processorArch);
		
		uint count;
		char[] name;
		char[] value;
		
		reader.get(count);
		debug debugLog("namespaces: {0}",count);
		
		for(int i=0; i<count; i++){
			reader.get(name);
			definedNamespaces ~= name;
			debug debugLog("\t{0}",name);
		}
		
		reader.get(count);
		debug debugLog("modules: {0}",count);
		
		for(int i=0; i<count; i++){
			reader.get(name);
			importedModules ~= name;
			debug debugLog("\t{0}",name);
		}	
			
		reader.get(count);
		debug debugLog("attributes: {0}",count);
		
		for(int i=0; i<count; i++){
			reader.get(name);
			reader.get(value);
			attributes[name] = value;
			debug debugLog("\t{0}",name);
		} 
		//TODO: problem here - seek is not working correctly, yielding an empty buffer on getAll();
		reader.seek(binaryStart,ddl.DDLReader.Anchor.Begin);
		
		void[] data;
		reader.getAll(data);
		binaryData = cast(ubyte[])data;
	}
			
	public ubyte[] getBinaryData(){
		return binaryData;
	}
	
	/**
		Saves a DDL module to disk.  
		Assumes that the binaryData is already populated with the embedded file data.
	*/
	public void save(FileBuffer fileBuffer){		
		DDLWriter writer = new DDLWriter(fileBuffer);
			
		writer.putAll(cast(void[])MagicBytes);
		writer.put(DDLVersion);
		writer.put(cast(uint)0); // dummy write for binary start
		writer.put(binaryType);
		writer.put(processorArch);
				
		writer.put(definedNamespaces.length);
		foreach(char[] str; definedNamespaces){
			writer.put(str);
		}
				
		writer.put(importedModules.length);
		foreach(char[] str; importedModules){
			writer.put(str);
		}
				
		writer.put(attributes.length);
		if(attributes.length > 0){ //HACK: workaround for empty AA bug
			foreach(char[] name,char[] value; attributes){
				writer.put(name);
				writer.put(value);
			}
		}
				
		uint binaryStart = writer.getPosition();
		
		debug debugLog("binaryStart: {0} {1:X8}",binaryStart,binaryStart);
		
		writer.putAll(cast(void[])binaryData);
		
		writer.seek(8,ddl.DDLWriter.Anchor.Begin); // offset for binary start
		writer.put(binaryStart);

		writer.seek(0,ddl.DDLWriter.Anchor.End); // be polite, and park at the end of the stream
	}
}

/+
ddlfile ::= header embeddedFile	EOF
header ::= magic version binaryOffset binaryType processorArch definedNamespaces importedModules attributes
magic ::= 'D' 'D' 'L' '!'
version ::= 0x00010001

binaryOffset ::= uint
binaryType ::= string
processorArch ::= string
definedNamespaces ::= count string(count)
importedModules ::= count string(count)

attributes ::= count attrib(count)
attrib ::= name value
name ::= string
value ::= string

string ::= count char(count)
count ::= uint

embeddedFile ::= ubyte(*)
+/
