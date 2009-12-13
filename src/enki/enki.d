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
module enki.enki;

private import enki.frontend.all;
private import enki.generator.all;

private import tango.util.ArgParser;
private import tango.io.device.File;
private import tango.io.FilePath;
private import tango.io.Stdout;

char[] helpText =
`Enki - Frontend Parser Generator - V2.0
Copyright(c) 2006-2008 Eric Anderton

Creates a parser module based on annotated EBNF input,
for one of several supported languages.

Usage:
  enki { -switch } <source ebnf file>

  -g<name>  Selects generator <name> for the output
  -f<name>  Selects frontend grammar <name> for the input file
  -h<name>  Outputs help info for generator or frontend <name>
  -c        sends generator output to console (stdout)

The output filename depends on which generator is selected
and how the input ebnf input file is configured.
`;

static char[] defaultFrontend = "enki2";
static char[] defaultGenerator = "d";

void displayHelp(){
	Stdout(helpText).newline;
	
	Stdout("Supported code generators:").newline;
	foreach(name, gen; registeredGenerators){		
		if(name == defaultGenerator){
			Stdout("*");
		}
		Stdout.format("{0} ",name);
	}
	Stdout.newline;
	Stdout.newline;
	Stdout("Supported frontend grammars:").newline;
	foreach(name, frontend; registeredFrontends){
		if(name == defaultFrontend){
			Stdout("*");
		}
		Stdout.format("{0} ",name);
	}
	Stdout.newline;
}

int main(char[][] args){
	if(args.length == 1){
		displayHelp();
		return 0;
	}

	// set defaults
	FilePath inputFilename;
	char[] frontendName = defaultFrontend;
	char[] generatorName = defaultGenerator;
	bool testMode = false;
	bool helpMode = false;
	char[] helpName = null;

	// configure the arg parser
	ArgParser argParser = new ArgParser();

	argParser.bindDefault(delegate void(char[] value,uint ordinal){
		if(ordinal > 0) throw new Exception("Invalid argument '" ~ value ~ "'");
		inputFilename = new FilePath(value);
	});
	
	argParser.bind("-", "f",delegate void(char[] value){
		frontendName = value;
	});	

	argParser.bind("-", "g",delegate void(char[] value){
		generatorName = value;
	});
	
	argParser.bind("-", "h",delegate void(char[] value){
		if(value.length > 0){
			helpName = value;
		}
		helpMode = true;
	});
	
	argParser.bind("--", "help",delegate void(char[] value){
		if(value.length > 0){
			helpName = value;
		}
		helpMode = true;
	});	

	argParser.bind("-", "c",delegate void(){
		testMode = true;
	});
	
	// parse and resolve arguments
	try{
		argParser.parse(args[1..$]);
	}
	catch(Exception e){
		Stdout(e).newline;
		return 1;
	}
	
	if(helpMode){
		if(helpName is null){
			displayHelp();
		}
		else{
			if(helpName in registeredGenerators){
				Stdout(registeredGenerators[helpName].getHelp());
			}
			else if(helpName in registeredFrontends){
				Stdout(registeredFrontends[helpName].getHelp());
			}
			else{			
				Stdout.format("Error: Could not find help for '{0}'.",helpName).newline;
				return 1;
			}
		}
		return 0;
	}

	if(inputFilename is null || inputFilename.toString.length == 0){
		Stdout("Error: No input filename specified.").newline;
		return 1;
	}

	if(!inputFilename.exists){
		Stdout.format("Error: File '{0}' doesn't exist.",inputFilename.toString).newline;
		return 1;
	}
	
	if(!(frontendName in registeredFrontends)){
		Stdout.format("Error: Frontend '{0}' is not supported.",frontendName).newline;
		return 1;
	}	

	if(!(generatorName in registeredGenerators)){
		Stdout.format("Error: Generator '{0}' is not supported.",generatorName).newline;
		return 1;
	}

	auto parser = registeredFrontends[frontendName];
    try{	
		// init the Enki Parser - this runs the lexer pass
		parser.initialize(inputFilename);
	    
	    // perform the full parse
		if(!parser.parse()){
			throw new Exception("parser fail");
		};
			
		// perform semantic pass
		parser.semanticPass();

		// run the selected generator
	    auto generator = registeredGenerators[generatorName];
	    generator.toCode(parser,testMode);
    }
    catch(Exception e){
	    Stdout(e).newline; 
		debug parser.debugParser(); 
	    return 1;
    }
    return 0;
}
