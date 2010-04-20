module xf.nucleus.kdef.KDefUtilParser;

private {
	import xf.core.Registry;
	
	import xf.nucleus.kdef.Common;
	import xf.nucleus.kdef.KDefLexer;
	import xf.nucleus.kdef.KDefParser;
	import xf.nucleus.kdef.KDefToken;
	import xf.nucleus.kdef.model.IKDefUtilParser;
	import xf.nucleus.CommonDef;
	alias char[] string;
}



class KDefUtilParser : IKDefUtilParser {
	mixin(Implements("IKDefUtilParser"));
	
	
	VarDef[] parse_TemplateArgList(string source) {
		auto parser = lex(source);
		if (!parser.parse_TemplateArgList()) {
			throw new Exception("parser fail");
		} else {
			assert (parser.value_TemplateArgList.length > 0, source);
			return parser.value_TemplateArgList;
		}
	}
	
	
	private {
		KDefParser lex(string source) {
			auto lexer = new KDefLexer;
			auto parser = new KDefParser;

			lexer.initialize(source, "(memory)");
			
			if (!lexer.parse_Syntax()) {
				throw new Exception("lexer fail");
			}
			
			assert (lexer.value_Syntax.length > 0);
			parser.initialize(lexer.value_Syntax);
			return parser;
		}
	}
}
