module xf.hybrid.ConfigLinker;

private {
	import xf.hybrid.Config;
	import xf.hybrid.WidgetConfig;
	import xf.hybrid.Context;
	import tango.io.FilePath;
	import tango.util.log.Trace;
}



/**
	Load the config specified in [_path]. Imprted configs are recursively loaded using DFS. Cycles are safe
	
	gui.vfs is used for locating and loading the specified files.
*/
Config loadHybridConfig(char[] _path) {
	Config[char[]] loaded;
	
	Config loadWorker(char[] path) {
		if (auto c = path in loaded) {
			return *c;
		}
		
		Config cfg;
		{
			auto file = gui.vfs.file(path);
			if (file.exists) {
				auto stream = file.input();
				
				if (stream) {
					scope (exit) stream.close();
					cfg = parseWidgetConfig(stream, path);
				}
			}
		}
		
		if (cfg !is null) {
			loaded[path] = cfg;
			
			foreach (im; cfg.imports) {
				loadWorker(im);
			}
		} else {
			Trace.formatln("Could not load '{}'", path);
		}		
		
		return cfg;
	}
	
	auto cfg = loadWorker(_path);
	if (cfg !is null) {
		foreach (im; loaded) {
			if (im !is cfg) {
				cfg.widgetSpecs ~= im.widgetSpecs;
				cfg.widgetTypeSpecs ~= im.widgetTypeSpecs;
			}
		}
	}
	
	return cfg;
}
