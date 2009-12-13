module xf.omg.mesh.Logging;

private {
	import xf.utils.log.Log;
}

public {
	mixin LibraryLog!("meshLog", "MeshLog", LogLevel.Trace, LogLevel.Info, "Msg", LogLevel.Warn, LogLevel.Error, LogLevel.Fatal);
}
