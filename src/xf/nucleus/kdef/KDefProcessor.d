module xf.nucleus.kdef.KDefProcessor;

private {
	import xf.core.Registry;
	
	import xf.nucleus.kdef.KDefParserBase;
	import xf.nucleus.kdef.Common;
	import xf.nucleus.kdef.model.IKDefFileParser;
	import xf.nucleus.kernel.KernelDef;
	import xf.nucleus.quark.QuarkDef;
	import xf.nucleus.SemanticTypeSystem : SemanticConverter, Semantic;
	import xf.nucleus.CommonDef;

	import xf.utils.Graph : findTopologicalOrder, CycleHandlingMode;
	import xf.utils.Memory : alloc, free, append;
	
	import tango.io.vfs.model.Vfs;
	
	import tango.io.Stdout;
	
	alias char[] string;
}




class KDefProcessor {
	this (IKDefFileParser fileParser) {
		this.fileParser = fileParser;
	}
	
	
	void processFile(string path) {
		if (auto mod = path in modules) {
			if ((*mod).processing) {
				throw new Exception("Cyclic import in kernel module '" ~ path ~ "'");
			}
		} else {
			Stdout.formatln("KDefProcessor.parseFile({})", path);
			auto mod = fileParser.parseFile(path);
			modules[path] = mod;
			mod.processing = true;
			mod.filePath = path;
			process(mod);
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
	
	
	void doSemantics() {
		doKernelSemantics();
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
	
	
	int kernels(int delegate(ref KernelDef) dg) {
		foreach (name, mod; modules) {
			foreach (kernel; mod.kernels) {
				if (auto r = dg(kernel)) {
					return r;
				}
			}
		}
		
		return 0;
	}
	
	
	int quarks(int delegate(ref QuarkDef) dg) {
		foreach (name, mod; modules) {
			foreach (impl; mod.kernelImpls) {
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
			foreach (impl; mod.kernelImpls) {
				if (auto gdef = cast(GraphDefValue)impl.impl) {
					if (auto r = dg(gdef.graphDef)) {
						return r;
					}
				}
			}
		}
		
		return 0;
	}


	int converters(int delegate(ref SemanticConverter) dg) {
		foreach (name, mod; modules) {
			foreach (conv; mod.converters) {
				if (auto r = dg(conv)) {
					return r;
				}
			}
		}
		
		return 0;
	}

	
	KernelDef getKernel(string name) {
		foreach (kernel; &kernels) {
			if (kernel.name == name) {
				return kernel;
			}
		}
		
		return null;
	}
	

	QuarkDef getQuark(string name) {
		foreach (quark; &quarks) {
			if (quark.name == name) {
				return quark;
			}
		}
		
		return null;
	}

	
	private {
		void doKernelSemantics() {
			int[KernelDef] kernelToId;
			int nextOrderGraphId = 0;
			
			void process(KernelDef k) {
				if (k in kernelToId) {
					return;
				}
				
				foreach (b; k.getKernelsBefore) {
					if (!getKernel(b)) {
						throw new Exception(Format("Unknown kernel to be rendered before '{}': '{}'", k.name, b));
					}
				}
				foreach (a; k.getKernelsAfter) {
					if (!getKernel(a)) {
						throw new Exception(Format("Unknown kernel to be rendered after '{}': '{}'", k.name, a));
					}
				}
				
				kernelToId[k] = nextOrderGraphId++;
				
				foreach (sup; k.getInheritList) {
					auto supk = getKernel(sup);
					if (supk) {
						process(supk);
						
						k.inherit(supk);
					} else {
						throw new Exception(Format("Unknown super kernel for {}: '{}'", k.name, sup));
					}
				}
			}
			
			foreach (k; &kernels) {
				process(k);
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
			}
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
		
		
		void findRenderingOrder(int[KernelDef] kernelToId, int numOrderNodes) {
			SimpleArray!(KernelDef)[] idToKernels;
			idToKernels.alloc(numOrderNodes);
			scope (exit) dispose2dArray(idToKernels);
			
			foreach (k, id; kernelToId) {
				idToKernels[id].add(k);
			}
			
			SimpleArray!(int)[] succList;
			succList.alloc(numOrderNodes);
			scope (exit) dispose2dArray(succList);
			
			foreach (ki, karr; idToKernels) {
				if (karr.length > 0) {
					final k = karr.data[0];
					foreach (bn; k.getKernelsBefore) {
						auto before = getKernel(bn);
						succList[ki].add(kernelToId[before]);
					}
					foreach (an; k.getKernelsAfter) {
						auto after = getKernel(an);
						succList[kernelToId[after]].add(ki);
					}
				}
			}
			
			int order[];
			order.alloc(numOrderNodes);
			scope (exit) order.free();
			
			int numOrdered = findTopologicalOrder(
				(void delegate(int) dg) {
					for (int i = 0; i < numOrderNodes; ++i) {
						dg(i);
					}
				},
				(int ki, void delegate(int) succ) {
					foreach (s; succList[ki].data) {
						succ(s);
					}
				},
				order,
				CycleHandlingMode.AnyOrder,
				(int clusterId, int[] cluster) {
					foreach (o; cluster) {
						foreach (k; idToKernels[o].data) {
							Stdout.formatln("\t{}: {}", clusterId, k.name);
							k.renderingOrdinal = clusterId;
						}
					}
				}
			);
			assert (numOrdered == order.length);
		}

		//
		// --------------------------------------------------------------------------------------------------------------------------------
		
		void dumpInfo(KDefModule mod) {
			Stdout.formatln("* path: {}", mod.filePath);
			Stdout.formatln("* kernel impls:");
			foreach (impl; mod.kernelImpls) {
				dumpInfo(impl);
			}
			Stdout.formatln("* kernels:");
			foreach (kernel; mod.kernels) {
				dumpInfo(kernel);
			}
		}
		
		
		void dumpInfo(ImplementStatement impl) {
			foreach (i; impl.impls) {
				Stdout.format("{}({}) ", i.name, i.score);
			}
			
			if (auto q = cast(QuarkDefValue)impl.impl) {
				dumpInfo(q.quarkDef);
			} else if (auto g = cast(GraphDefValue)impl.impl) {
				dumpInfo(g.graphDef);
			} else {
				Stdout.formatln("{}", impl.impl.classinfo.name);
			}
		}
		
		
		void dumpInfo(QuarkDef quark) {
			Stdout.formatln("quark {} {{", quark.name);
			foreach (func; quark.functions) {
				dumpInfo(func);
			}
			Stdout("}").newline;
		}
		
		
		void dumpInfo(KernelFunction func) {
			Stdout.formatln("\tfunc: {} {{", func.name);
			foreach (param; func.params) {
				Stdout.format("\t\t{} {} {} <{}>",
					param.dirStr,
					param.type,
					param.name,
					param.semantic
				);
				if (param.defaultValue) {
					Stdout.formatln(" = {}", param.defaultValue);
				}
				Stdout.newline;
			}
			if (auto qf = cast(QuarkFunction)func) {
				Stdout.formatln("{} code:", qf.code.language);
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
			Stdout.formatln("kernel {} {{", kernel.name);
			foreach (func; kernel.functions) {
				dumpInfo(func);
			}
			Stdout("}").newline;
		}
		
		
		void process(ImplementStatement implStmt) {
			if (auto qdv = cast(QuarkDefValue)implStmt.impl) {
				auto q = qdv.quarkDef;
				q.implList = implStmt.impls;
			} else if (auto gdv = cast(GraphDefValue)implStmt.impl) {
				auto g = gdv.graphDef;
				g.implList = implStmt.impls;
			} else {
				assert (false, "wtf? " ~ implStmt.impl.classinfo.name);
			}
		}
		
		
		void process(Scope sc) {
			foreach (stmt_; sc.statements) {
				if (auto stmt = cast(ImplementStatement)stmt_) {
					if (auto mod = cast(KDefModule)sc) {
						stmt.impl.doSemantics(&process);
						mod.kernelImpls ~= stmt;
						process(stmt);
					} else {
						throw new Exception("kernel implementations only allowed at top-level scope");
					}
				} else if (auto stmt = cast(ConnectStatement)stmt_) {
					if (auto graph = cast(GraphDef)sc) {
						graph.doConnect(stmt.from, stmt.to);
					} else {
						throw new Exception("connections only allowed at graph scope");
					}
				} else if (auto stmt = cast(AssignStatement)stmt_) {
					if (auto scopeValue = cast(IScopeValue)stmt.value) {
						process(scopeValue.toScope);
					}
					
					if (auto kernelValue = cast(KernelDefValue)stmt.value) {
						kernelValue.kernelDef.name = stmt.name;
						if (auto mod = cast(KDefModule)sc) {
							mod.kernels ~= kernelValue.kernelDef;
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
					processFile(path);
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
						assert (2 == stmt.params.length);		// there's also hidden context
						
						Param from = stmt.params[0];
						Param to = stmt.params[1];
						
						if ("Cg" == stmt.code.language) {
							if (!from.semantic.hasTrait!(string)("domain")) {
								from.semantic.addTrait(Trait("domain", Variant("gpu"[])));
							}

							if (!to.semantic.hasTrait!(string)("domain")) {
								to.semantic.addTrait(Trait("domain", Variant("gpu"[])));
							}
						}
						
						string name = stmt.name;
						if (name is null) {
							name = "TODO: some mangled name omglol";
						}
						
						mod.converters ~= new SemanticConverter(name, from, to, stmt.code);
					} else {
						throw new Exception("only can has converters at module scope ktnx");
					}
				} else if (auto stmt = cast(PreprocessStatement)stmt_) {
					if (auto graph = cast(GraphDef)sc) {
						graph.preprocessCmds ~= GraphDef.PreprocessCmd(stmt.processor.dup, stmt.processorFunction.dup);
					} else {
						throw new Exception("only can has preprocessors at graph scope ktnx");
					}
				} else {
					throw new Exception("Unhandled statement: " ~ stmt_.toString);
				}
			}
		}


		IKDefFileParser			fileParser;
		
		// indexed by path
		KDefModule[string]	modules;
	}
}
