module xf.nucleus.kdef.KDefFileParser;

private {
	import xf.core.Registry;

	import xf.mem.ChunkQueue;		// for ScratchFIFO
	import xf.mem.ScratchAllocator;
	
	import xf.nucleus.kdef.Common;
	import xf.nucleus.kdef.KDefLexer;
	import xf.nucleus.kdef.KDefParser;
	import xf.nucleus.kdef.model.IKDefFileParser;
	import tango.io.vfs.model.Vfs;
	alias char[] string;
}



class KDefFileParser : IKDefFileParser {
	mixin(Implements("IKDefFileParser"));
	
	
	void setVFS(VfsFolder host) {
		_vfs = host;
	}
	
	
	KDefModule parseFile(
		string sourcePath
	) {
		auto input = _vfs.file(sourcePath).input();
		scope(exit) input.close;
		string data = cast(string)input.load();

		scope lexer = new KDefLexer;
		scope parser = new KDefParser;

		auto res = new KDefModule();

		auto allocator = res.mem;
		parser.mem = allocator;

		scope (failure) {
			delete res;
		}

		lexer.initialize(data, sourcePath);
		
		if (!lexer.parse_Syntax()) {
			throw new Exception("lexer fail");
		}
		
		parser.initialize(lexer.value_Syntax);
		if (!parser.parse_Syntax()) {
			throw new Exception("parser fail");
		}
		
		res.filePath = sourcePath;
		res.statements = parser.statements;
		return res;
	}
	
	
	private {
		VfsFolder	_vfs;
	}
}
