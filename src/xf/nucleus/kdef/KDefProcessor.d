module xf.nucleus.kdef.KDefProcessor;

private {
	import xf.core.Registry;
	
	import xf.nucleus.kdef.KDefParserBase;
	import xf.nucleus.kdef.Common;
	import xf.nucleus.kdef.model.IKDefFileParser;
	import xf.nucleus.kernel.KernelDef;
	import xf.nucleus.quark.QuarkDef;

	import xf.nucleus.TypeConversion;
	import xf.nucleus.Function;
	//import xf.nucleus.SemanticTypeSystem : SemanticConverter, Semantic;
	//import xf.nucleus.CommonDef;

	import xf.utils.Graph : findTopologicalOrder, CycleHandlingMode;
	import xf.utils.Memory : alloc, free, append;
	
	import tango.io.vfs.model.Vfs;
	
	import tango.io.Stdout;
	
	alias char[] string;
}



class KDefProcessor {
	alias void* delegate(size_t) Allocator;


	this (IKDefFileParser fileParser) {
		this.fileParser = fileParser;
	}
	
	
	void processFile(string path, Allocator allocator) {
		if (auto mod = path in modules) {
			if ((*mod).processing) {
				throw new Exception("Cyclic import in kernel module '" ~ path ~ "'");
			}
		} else {
			Stdout.formatln("KDefProcessor.parseFile({})", path);
			auto mod = fileParser.parseFile(path, allocator);
			modules[path] = mod;
			mod.processing = true;
			mod.filePath = path;
			process(mod, allocator);
			mod.processing = false;
		}
	}
	
	
	KDefModule getModuleForPath(string path) {
		if (auto mod = path in modules) {
			return *mod;
		} else {
			return null;
		}
	}
	
	
	void doSemantics(Allocator allocator) {
		doKernelSemantics(allocator);
	}
	
	
	void clear() {
		// TODO(?): do more thorough cleaning
		modules = null;
	}
	
	
	void dumpInfo() {
		Stdout.formatln("got {} modules:", modules.keys.length);
		foreach (name, mod; modules) {
			Stdout.formatln("mod {}:", name);
			dumpInfo(mod);
		}
	}
	
	
	/+int kernels(int delegate(ref KernelDef) dg) {
		foreach (name, mod; modules) {
			foreach (ref kernel; mod.kernels) {
				if (auto r = dg(kernel)) {
					return r;
				}
			}
		}
		
		return 0;
	}
	
	
	int quarks(int delegate(ref QuarkDef) dg) {
		foreach (name, mod; modules) {
			foreach (ref impl; mod.kernelImpls) {
				if (auto qdef = cast(QuarkDefValue)impl.impl) {
					if (auto r = dg(qdef.quarkDef)) {
						return r;
					}
				}
			}
		}
		
		return 0;
	}
	

	int graphs(int delegate(ref GraphDef) dg) {
		foreach (name, mod; modules) {
			foreach (ref impl; mod.kernelImpls) {
				if (auto gdef = cast(GraphDefValue)impl.impl) {
					if (auto r = dg(gdef.graphDef)) {
						return r;
					}
				}
			}

			foreach (ref gdef; mod.graphDefs) {
				if (auto r = dg(gdef)) {
					return r;
				}
			}
		}
		
		return 0;
	}+/


	int converters(int delegate(ref SemanticConverter) dg) {
		foreach (name, mod; modules) {
			foreach (ref conv; mod.converters) {
				if (auto r = dg(conv)) {
					return r;
				}
			}
		}
		
		return 0;
	}

	
	KernelDef getKernel(string name) {
		assert (false, "TODO");
		/+foreach (kernel; &kernels) {
			if (kernel.name == name) {
				return kernel;
			}
		}
		
		return null;+/
	}
	

	/+QuarkDef getQuark(string name) {
		foreach (quark; &quarks) {
			if (quark.name == name) {
				return quark;
			}
		}
		
		return null;
	}+/

	
	private {
		void doKernelSemantics(Allocator allocator) {
			int[KernelDef] kernelToId;
			int nextOrderGraphId = 0;
			
			void process(KernelDef k, Allocator allocator) {
				if (k in kernelToId) {
					return;
				}
				
				kernelToId[k] = nextOrderGraphId++;

				assert (false, "TODO");
				/+foreach (sup; k.getInheritList) {
					auto supk = getKernel(sup);
					if (supk) {
						process(supk, allocator);
						
						k.inherit(supk);
					} else {
						throw new Exception(Format("Unknown super kernel for {}: '{}'", k.name, sup));
					}
				}+/
			}

			assert (false, "TODO");
			/+foreach (k; &kernels) {
				process(k, allocator);
			}

			foreach (k; &kernels) {
				if (auto ord = k in kernelToId) {
					if (-1 == *ord) {
						*ord = 0;
						if (0 == nextOrderGraphId) {
							nextOrderGraphId = 1;
						}
					}
				}
			}
			
			if (nextOrderGraphId > 0) {
				findRenderingOrder(kernelToId, nextOrderGraphId);
			}+/
		}
		
		// --------------------------------------------------------------------------------------------------------------------------------
		//

		struct SimpleArray(T) {
			private {
				T[]		_arr;
				size_t	_len;
			}
			
			
			size_t length() {
				return _len;
			}
			
			T[] data() {
				return _arr[0.._len];
			}
			
			void add(T t) {
				_arr.append(t, &_len);
			}
			
			void dispose() {
				_arr.free();
			}
		}
		
		
		void dispose2dArray(T)(ref SimpleArray!(T)[] arr) {
			foreach (ref item; arr) {
				item.dispose();
			}
			arr.free();
		}
		
		
		//
		// --------------------------------------------------------------------------------------------------------------------------------
		
		void dumpInfo(KDefModule mod) {
			Stdout.formatln("* path: {}", mod.filePath);
			Stdout.formatln("* kernel impls:");
			
			assert (false, "TODO");
			/+foreach (impl; mod.kernelImpls) {
				dumpInfo(impl);
			}
			Stdout.formatln("* kernels:");
			foreach (kernel; mod.kernels) {
				dumpInfo(kernel);
			}+/
		}
		
		
		/+void dumpInfo(QuarkDef quark) {
			Stdout.formatln("quark {} {{", quark.name);
			foreach (func; quark.functions) {
				dumpInfo(func);
			}
			Stdout("}").newline;
		}+/
		
		
		void dumpInfo(AbstractFunction func) {
			Stdout.formatln("\tfunc: {} {{", func.name);
			foreach (param; func.params) {
				Stdout.format("\t\t{}", param);
				/+if (param.defaultValue) {
					Stdout.formatln(" = {}", param.defaultValue);
				}+/
				Stdout.newline;
			}
			if (auto qf = cast(Function)func) {
				//Stdout.formatln("{} code:", qf.code.language);
				Stdout("----").newline;
				Stdout(qf.code.toString).newline;
				Stdout("----").newline;
			}
			Stdout("}").newline;
		}
		
		
		void dumpInfo(GraphDef graph) {
			Stdout("graph {").newline;
			foreach (nodeName, _node; graph.nodes) {
				Stdout.formatln("\tnode: {}", nodeName);
			}
			foreach (graphName, subGraph; graph.graphs) {
				Stdout.formatln("\tsub-graph: ");
				dumpInfo(subGraph);
			}
			Stdout("}").newline;
		}
		
		
		void dumpInfo(KernelDef kernel) {
			assert (false, "TODO");
			/+Stdout.formatln("kernel {} {{", kernel.name);
			foreach (func; kernel.functions) {
				dumpInfo(func);
			}
			Stdout("}").newline;+/
		}
		
				
		void process(Scope sc, Allocator allocator) {
			foreach (stmt_; sc.statements) {
				if (auto stmt = cast(ConnectStatement)stmt_) {
					if (auto graph = cast(GraphDef)sc) {
						graph.doConnect(stmt.from, stmt.to);
					} else {
						throw new Exception("connections only allowed at graph scope");
					}
				} else if (auto stmt = cast(AssignStatement)stmt_) {
					if (auto scopeValue = cast(IScopeValue)stmt.value) {
						process(scopeValue.toScope, allocator);
					}
					
					if (auto kernelValue = cast(KernelDefValue)stmt.value) {
						kernelValue.kernelDef.func.name = stmt.name;
						if (auto mod = cast(KDefModule)sc) {
							assert (false, "TODO");
							//mod.kernels ~= kernelValue.kernelDef;
						}
					}
					
					if (auto graphValue = cast(GraphDefValue)stmt.value) {
						graphValue.graphDef.name = stmt.name;
						if (auto mod = cast(KDefModule)sc) {
							assert (false, "TODO");
							//mod.graphDefs ~= graphValue.graphDef;
						}
					}
					
					if (auto traitValue = cast(TraitDefValue)stmt.value) {
						traitValue.value.name = stmt.name;
						if (auto mod = cast(KDefModule)sc) {
							mod.traitDefs ~= traitValue.value;
						}
					}

					sc.doAssign(stmt.name, stmt.value);
				} else if (auto stmt = cast(ImportStatement)stmt_) {
					auto path = stmt.path;
					processFile(path, allocator);
					auto names = stmt.what;
					auto mod = modules[path];
					
					if (names !is null) {
						assert (false, "TODO: selective imports");
					} else {
						sc.doImport((void delegate(Statement) dg) {
							foreach (st; mod.statements) {
								dg(st);
							}
						});
					}
				} else if (auto stmt = cast(ConverterDeclStatement)stmt_) {
					if (auto mod = cast(KDefModule)sc) {
						assert (2 == stmt.func.params.length);		// there's also hidden context
						
						auto from = stmt.func.params[0];
						auto to = stmt.func.params[1];
						
						/+if ("Cg" == stmt.func.code.language) {
							if (!from.semantic.hasTrait("domain")) {
								from.semantic.addTrait("domain", "gpu");
							}

							if (!to.semantic.hasTrait("domain")) {
								to.semantic.addTrait("domain", "gpu");
							}
						}+/
						
						string name = stmt.func.name;
						if (name is null) {
							name = "TODO: some mangled name omglol";
						}
						
						mod.converters ~= SemanticConverter(stmt.func, stmt.cost);
					} else {
						throw new Exception("only can has converters at module scope ktnx");
					}
				} else {
					throw new Exception("Unhandled statement: " ~ stmt_.toString);
				}
			}
		}


		IKDefFileParser		fileParser;
		
		// indexed by path
		KDefModule[string]	modules;
	}
}
