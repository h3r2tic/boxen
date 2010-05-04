module Main;

private {
	import tango.core.tools.TraceExceptions;
	
	import xf.Common;
	import xf.mem.ChunkQueue;
	import xf.nucleus.TypeSystem;
	import xf.nucleus.Param;
	import xf.nucleus.Function;
	
	import xf.nucleus.kdef.KDefLexer;
	import xf.nucleus.kdef.KDefParser;

	import tango.text.convert.Format;
	import tango.io.Stdout;
	import tango.io.device.File;
}



void main() {
	{
		ScratchFIFO mem;
		mem.initialize();

		final allocator = (uword bytes) { return mem.pushBack(bytes); };

		cstring source = cast(cstring)File.get("sample.kdef");
		
		auto lexer = new KDefLexer;
		auto parser = new KDefParser;
		parser.allocator = allocator;

		lexer.initialize(source, "(memory)");
		
		if (!lexer.parse_Syntax()) {
			throw new Exception("lexer fail");
		}

		Stdout.formatln("lexed ok");
		
		assert (lexer.value_Syntax.length > 0);
		parser.initialize(lexer.value_Syntax);
		Stdout.formatln("parser initialized ok");
		
		if (!parser.parse_Syntax()) {
			throw new Exception("parser fail");
		}

		Stdout.formatln("parsed ok");
	}

	Stdout.formatln("Test passed!");
}
