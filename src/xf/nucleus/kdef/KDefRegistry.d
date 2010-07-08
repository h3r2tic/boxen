module xf.nucleus.kdef.KDefRegistry;

private {
	import xf.core.Registry;
	
	import xf.nucleus.kdef.model.IKDefRegistry;
	import xf.nucleus.kdef.model.KDefInvalidation;
	import xf.nucleus.kdef.Common;
	import xf.nucleus.kdef.KDefProcessor;
	import xf.nucleus.kernel.KernelDef;
	import xf.nucleus.kdef.model.IKDefFileParser;
	import xf.nucleus.TypeConversion;
	import xf.nucleus.KernelImpl;
	import xf.nucleus.SurfaceDef;
	import xf.nucleus.MaterialDef;
	import xf.nucleus.Log : log = nucleusLog;

	import tango.core.Thread;
	import tango.core.Runtime;
	import Path = tango.io.Path;
	
	import tango.text.convert.Format;
	import tango.io.Stdout;
	
	alias char[] string;
}




class KDefRegistry : IKDefRegistry {
	mixin(Implements("IKDefRegistry"));
	
	private {
		KDefProcessor kdefProcessor;
		IKDefInvalidationObserver[]	invalidationObservers;
	}


	this() {
		kdefProcessor = new KDefProcessor(_fileParser = create!(IKDefFileParser)());
		super("*.kdef");
		startWatcherThread();
	}


	override void registerObserver(IKDefInvalidationObserver o) {
		invalidationObservers ~= o;
	}


	private void startWatcherThread() {
		(new Thread(&watcherThreadFunc)).start();
	}


	private void watcherThreadFunc() {
		try {
			Thread.sleep(2);

			while (!Runtime.isHalting) {
				bool anyMods = false;

				size_t i = 0;
				foreach (path; &iterAllFiles) {
					if (	path != _allFiles[i].path
						||	Path.modified(path).ticks != _allFiles[i].timeModified
					) {
						anyMods = true;
						break;
					}
					++i;

					Thread.yield();
				}

				if (anyMods) {
					_filesModified = true;
				}

				Thread.sleep(0.1);
			}
		} catch (Exception e) {
			char[] msg;
			e.writeOut((char[] x) { msg ~= x; });
			log.error("KDef change watcher thread crashed.");
			log.error("{}", msg);
		}
	}
	
	
	void dumpInfo() {
		kdefProcessor.dumpInfo;
	}
	
	
	KernelImpl getKernel(string name) {
		return kdefProcessor.getKernel(name);
	}
	
	IKDefFileParser kdefFileParser() {
		return _fileParser;
	}
	
	
	KDefModule getModuleForPath(string path) {
		return kdefProcessor.getModuleForPath(path);
	}
	

	override void processFile(string path) {
		_fileParser.setVFS(_vfs);
		kdefProcessor.processFile(path);
	}


	int converters(int delegate(ref SemanticConverter) dg) {
		return kdefProcessor.converters(dg);
	}


	int surfaces(int delegate(ref string, ref SurfaceDef) dg) {
		return kdefProcessor.surfaces(dg);
	}


	int materials(int delegate(ref string, ref MaterialDef) dg) {
		return kdefProcessor.materials(dg);
	}

	
	void doSemantics() {
		kdefProcessor.doSemantics();
	}


	bool invalidated() {
		return _filesModified;
	}


	override void reload() {
		_filesModified = false;
		
		log.info("Changes detected. Invalidating the old KDefProcessor data.");
		
		auto oldProc = kdefProcessor;
		auto newProc = kdefProcessor = new KDefProcessor(_fileParser = create!(IKDefFileParser)());
		_allFiles = _allFiles[0..0];
		processRegistrations();

		if (oldProc) {
			// for the invalidation handlers
			kdefProcessor = oldProc;

			auto invInfo = oldProc.invalidateDifferences(newProc);
			foreach (o; invalidationObservers) {
				o.onKDefInvalidated(invInfo);
			}

			kdefProcessor = newProc;
			//oldProc.dispose();
		}

		doSemantics();
	}
	

	private {
		IKDefFileParser	_fileParser;
		bool			_filesModified;
	}
}
