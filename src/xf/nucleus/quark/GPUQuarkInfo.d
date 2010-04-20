module xf.nucleus.quark.GPUQuarkInfo;

private {
	import xf.dog.Cg;
	import tango.stdc.stringz;
	import tango.io.Stdout;
}


private {
	CGcontext	cgContext;
}


static this() {
	initDogCg();
	cgContext = cgCreateContext;
}


void doStuff(char[] source) {
	cgGLSetDebugMode( CG_FALSE );
	cgSetParameterSettingMode(cgContext, CG_DEFERRED_PARAMETER_SETTING);
	cgGLRegisterStates(cgContext);
	cgGLSetManageTextureParameters(cgContext, CG_TRUE);

	char* sourceZ = toStringz(source);
	CGeffect effect = cgCreateEffect(cgContext, sourceZ, null);
	scope (exit) cgDestroyEffect(effect);

	CGprogram program = cgGetFirstProgram(cgContext);
	while (program) {
		Stdout.formatln("found a cg program");
		
		program = cgGetNextProgram(program);
	}
}
