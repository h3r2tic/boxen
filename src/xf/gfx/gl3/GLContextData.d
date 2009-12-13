module xf.gfx.gl3.GLContextData;

private {
	import xf.gfx.gl3.Common;
}



struct GLContextData {
}


void setGLContextData(GL gl, GLContextData* data) {
	*cast(GLContextData**)&gl = data;
}


bool isGLContextDataSet(GL gl) {
	return cast(void*)&gl !is null;
}
