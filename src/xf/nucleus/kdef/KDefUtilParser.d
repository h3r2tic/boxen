module xf.nucleus.kdef.KDefUtilParser;

private {
	import xf.core.Registry;
	
	import xf.nucleus.Code;
	import xf.nucleus.Value;
	import xf.nucleus.Log;
	import xf.nucleus.TypeSystem;
	import xf.nucleus.kdef.ParamUtils;
	import xf.nucleus.kdef.Common;
	import xf.nucleus.kdef.KDefLexer;
	import xf.nucleus.kdef.KDefParser;
	import xf.nucleus.kdef.model.IKDefUtilParser;

	import enkilib.d.ParserException;
	
	import xf.mem.ChunkQueue;
	import xf.mem.ScratchAllocator;

	alias char[] string;
}



class KDefUtilParser : IKDefUtilParser {
	mixin(Implements("IKDefUtilParser"));
	
	
	VarDef[] parse_TemplateArgList(string source) {
		/+auto parser = lex(source);
		if (!parser.parse_TemplateArgList()) {
			throw new Exception("parser fail");
		} else {
			assert (parser.value_TemplateArgList.length > 0, source);
			return parser.value_TemplateArgList;
		}+/
		assert (false);
	}


	bool parse_ParamSemantic(string source, void delegate(Semantic) sink) {
		assert (sink !is null);
		
		ScratchFIFO mem;
		mem.initialize();
		scope (exit) mem.dispose();

		final alloc = DgScratchAllocator(&mem.pushBack);

		KDefParser parser;
		scope (exit) delete parser;

		try {
			parser = lexAndParse(source, alloc);
		} catch (CParserException) {
			return false;
		}

		if (parser is null) {
			return false;
		} else if (!parser.parse_ParamSemantic()) {
			return false;
		} else {
			assert (parser.value_ParamSemantic !is null, source);

			final res = Semantic(&mem.pushBack);

			try {
				buildPlainSemantic(parser.value_ParamSemantic, &res);
			} catch (NucleusException) {
				return false;
			}

			sink(res);
			
			return true;
		}
	}
	
	
	private {
		KDefParser lexAndParse(string source, DgScratchAllocator mem) {
			auto lexer = new KDefLexer;
			auto parser = new KDefParser;
			parser.mem = mem;

			lexer.initialize(source, "(memory)");
			
			if (!lexer.parse_Syntax()) {
				return null;
			}
			
			assert (lexer.value_Syntax.length > 0);
			parser.initialize(lexer.value_Syntax);
			delete lexer;
			return parser;
		}
	}
}
