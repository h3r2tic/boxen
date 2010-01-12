module xf.gfx.api.gl3.LoaderCommon;


package {
	char[][] libSearchPaths;
	char[][] libNames;
	char[][] gluLibNames;
}



void prependLibSearchPaths(char[][] paths ...) {
	libSearchPaths = paths ~ libSearchPaths;
}

void appendLibSearchPaths(char[][] paths ...) {
	libSearchPaths ~= paths;
}


void prependLibNames(char[][] names ...) {
	libNames = names ~ libNames;
}

void appendLibNames(char[][] names ...) {
	libNames ~= names;
}


void prependGluLibNames(char[][] names ...) {
	gluLibNames = names ~ gluLibNames;
}

void appendGluLibNames(char[][] names ...) {
	gluLibNames ~= names;
}