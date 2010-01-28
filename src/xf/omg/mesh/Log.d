module xf.omg.mesh.Log;

private {
	import xf.utils.Log;
	import xf.utils.Error;
}


mixin(createLoggerMixin("meshLog"));
mixin(createErrorMixin("MeshException", "meshError"));
