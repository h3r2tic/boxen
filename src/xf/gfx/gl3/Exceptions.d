module xf.gfx.gl3.Exceptions;

private {
	import tango.stdc.stringz;
	import tango.text.convert.Format;
}



void handleMissingProc(char* name) {
	throw new Exception(`Proc not found: '` ~ fromStringz(name) ~ `'`);
}



void handleInvalidLib(char* name) {
	throw new Exception("Invalid library: " ~ fromStringz(name));
}



void handleLibNotFound(char[][] libNames, char[][] searchPaths) {
	char[][] quote(char[][] a) {
		char[][] res;
		foreach (ref x; a) {
			res ~= '"' ~ x ~ '"';
		}
		return res;
	}

	//scope s = new Sprint!(char);
	throw new Exception(Format("OpenGL library not found. Tried {} in {}", quote(libNames), quote(searchPaths)));
}
