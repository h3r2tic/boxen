module xf.nucleus.kdef.KDefRegistry;

private {
	import xf.Common;
	import xf.core.Registry;

	import xf.nucleus.Defs;
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
	import xf.nucleus.Log : log = nucleusLog, error = nucleusError;

	import xf.mem.ChunkQueue;

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
		super("*.kdef");
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

	KernelImpl getKernel(KernelImplId id) {
		return kdefProcessor.getKernel(id);
	}

	bool getKernel(string name, KernelImpl* res) {
		return kdefProcessor.getKernel(name, res);
	}

	int kernelImpls(int delegate(ref KernelImpl) dg) {
		return kdefProcessor.kernelImpls(dg);
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

		newProc.doSemantics();

		if (oldProc) {
			// for the invalidation handlers
			kdefProcessor = oldProc;

			auto invInfo = oldProc.invalidateDifferences(newProc);
			assignConsistentIds(oldProc, newProc);
			
			foreach (o; invalidationObservers) {
				o.onKDefInvalidated(invInfo);
			}

			kdefProcessor = newProc;
			//oldProc.dispose();
		} else {
			assignConsistentIds(null, newProc);
			startWatcherThread();
		}
	}


	private void assignConsistentIds(KDefProcessor op, KDefProcessor np) {
		// kernels
		{
			ChunkQueue!(KernelImplId.Type) matchingKernelIds;
			scope (exit) matchingKernelIds.dispose();

			if (op)
			foreach (modName, mod; &op.modules) {
				if (auto newMod = np.getModuleForPath(modName)) {
					foreach (name, ref o; mod.kernels) {
						if (auto o2 = name in newMod.kernels) {
							if (o.isValid) {
								if (o2.id.isValid) {
									if (o2.id != o.id) {
										assert (
											false,
											"id of a kernel in the new module is already"
											" assigned to something else than the id"
											" in the original kernel"
										);
									}
								} else {
									assert (o.id.isValid);
									o2.id = o.id;

									matchingKernelIds.pushBack(o.id.value);
								}
							}
						}
					}
				}
			}

			KernelImplId.Type _nextId = 0;

			KernelImplId.Type genId() {
				while (containsElement(matchingKernelIds, _nextId)) {
					++_nextId;
				}
				return _nextId++;
			}
			
			foreach (modName, mod; &np.modules) {
				foreach (name, ref o; mod.kernels) {
					if (!o.id.isValid) {
						o.id.value = genId();
						log.trace("Assigned id {} to kernel {}", o.id.value, o.name);
						assert (o.id.isValid);
					}
				}
			}
		}
	}
	

	private {
		IKDefFileParser	_fileParser;
		bool			_filesModified;
	}
}
