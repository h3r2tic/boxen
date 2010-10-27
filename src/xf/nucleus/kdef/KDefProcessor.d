module xf.nucleus.kdef.KDefProcessor;

private {
	import tango.core.Tuple;
	
	import
		xf.nucleus.kdef.model.IKDefFileParser,
		xf.nucleus.kdef.model.KDefInvalidation,
		xf.nucleus.kdef.KDefParserBase,
		xf.nucleus.kdef.Common,
		xf.nucleus.kdef.ParamUtils;

	import
		xf.nucleus.kernel.KernelDef;

	import
		xf.nucleus.Defs,
		xf.nucleus.TypeSystem,
		xf.nucleus.TypeConversion,
		xf.nucleus.Function,
		xf.nucleus.Param,
		xf.nucleus.Value,
		xf.nucleus.KernelImpl,
		xf.nucleus.SurfaceDef,
		xf.nucleus.MaterialDef,
		Dep = xf.nucleus.DepTracker;

	import
		xf.mem.ScratchAllocator,
		xf.mem.StackBuffer,
		xf.mem.Gather;
		
	import xf.utils.Graph	: findTopologicalOrder, CycleHandlingMode;
	import xf.utils.Memory	: alloc, free, append;
	import xf.nucleus.Log	: error = nucleusError, log = nucleusLog;

	import tango.io.Stdout;		// for dumpInfo, could be moved outside, to another mod
	import tango.io.vfs.model.Vfs;
	
	alias char[] string;
}



class KDefProcessor {
	alias DgScratchAllocator Allocator;


	this (IKDefFileParser fileParser) {
		this.fileParser = fileParser;
	}


	static Allocator modAlloc(KDefModule mod) {
		return mod.mem;
	}
	
	
	void processFile(string path) {
		if (auto mod = path in _modules) {
			if ((*mod).processing) {
				throw new Exception("Cyclic import in kernel module '" ~ path ~ "'");
			}
		} else {
			log.trace("KDefProcessor.parseFile({})", path);
			auto mod = fileParser.parseFile(path);
			_modules[path] = mod;
			mod.processing = true;
			mod.filePath = path;
			process(mod, modAlloc(mod));
			mod.processing = false;
		}
	}
	
	
	KDefModule getModuleForPath(string path) {
		if (auto mod = path in _modules) {
			return *mod;
		} else {
			return null;
		}
	}
	
	
	void doSemantics() {
		doKernelSemantics();
	}
	
	
	void dispose() {
		foreach (ref mod; _modules) {
			delete mod;
		}
		// TODO(?): do more thorough cleaning
		_modules = null;
	}
	
	
	void dumpInfo() {
		Stdout.formatln("got {} modules:", _modules.keys.length);
		foreach (name, mod; _modules) {
			Stdout.formatln("mod {}:", name);
			dumpInfo(mod);
		}
	}


	struct KernelInfo {
		KernelImpl*	impl;
		KDefModule	mod;
	}
	
	KernelInfo[string]	kernels;


	int converters(int delegate(ref SemanticConverter) dg) {
		foreach (name, mod; _modules) {
			foreach (ref conv; mod.converters) {
				if (auto r = dg(conv)) {
					return r;
				}
			}
		}
		
		return 0;
	}

	
	KernelImpl getKernel(string name) {
		if (auto impl = name in this.kernels) {
			return *impl.impl;
		} else {
			error("Unknown kernel: '{}'.", name);
			assert (false);
		}
	}


	// BUG: this is slow
	KernelImpl getKernel(KernelImplId id) {
		assert (id.isValid);
		
		foreach (k, ref v; this.kernels) {
			assert (v.impl.id.isValid);
			if (v.impl.id == id) {
				return *v.impl;
			}
		}

		error("Unknown kernel id: '{}'.", id.value);
		assert (false);
	}


	bool getKernel(string name, KernelImpl* res) {
		if (auto impl = name in this.kernels) {
			*res = *impl.impl;
			return true;
		} else {
			return false;
		}
	}


	int kernelImpls(int delegate(ref KernelImpl) dg) {
		foreach (n, k; this.kernels) {
			if (int r = dg(*k.impl)) {
				return r;
			}
		}

		return 0;
	}


	int surfaces(int delegate(ref string, ref SurfaceDef) dg) {
		foreach (name, mod; _modules) {
			foreach (name, ref surf; mod.surfaces) {
				string meh = name;
				if (auto r = dg(meh, surf)) {
					return r;
				}
			}
		}
		
		return 0;
	}


	int materials(int delegate(ref string, ref MaterialDef) dg) {
		foreach (name, mod; _modules) {
			foreach (name, ref surf; mod.materials) {
				string meh = name;
				if (auto r = dg(meh, surf)) {
					return r;
				}
			}
		}
		
		return 0;
	}


	int modules(int delegate(ref string, ref KDefModule) dg) {
		foreach (name, mod; _modules) {
			if (int r = dg(name, mod)) {
				return r;
			}
		}
		
		return 0;
	}


	KDefInvalidationInfo invalidateDifferences(KDefProcessor other) {
		KDefInvalidationInfo res;

		foreach (modName, mod; other._modules) {
			if (!(modName in this._modules)) {
				if (mod.converters.length > 0) {
					res.anyConverters = true;
				}
			}
		}
		
		foreach (modName, mod; _modules) {
			if (auto otherMod = modName in other._modules) {
				foreach (name, ref o; mod.kernels) {
					if (auto o2 = name in otherMod.kernels) {
						if (o != *o2) {
							o.invalidate();
						}
					} else {
						o.invalidate();
					}
				}

				foreach (name, ref o; mod.surfaces) {
					if (auto o2 = name in otherMod.surfaces) {
						if (o != *o2) {
							o.invalidate();
						}
					} else {
						o.invalidate();
					}
				}

				foreach (name, ref o; mod.materials) {
					if (auto o2 = name in otherMod.materials) {
						if (o != *o2) {
							o.invalidate();
						}
					} else {
						o.invalidate();
					}
				}

				if (!res.anyConverters) {
					if (mod.converters.length != otherMod.converters.length) {
						res.anyConverters = true;
					} else {
						foreach (i, ref c; mod.converters) {
							if (c != otherMod.converters[i]) {
								res.anyConverters = true;
								break;
							}
						}
					}
				}
			} else {
				// If the module is missing from the other processor,
				// invalidate all of the current module's items
				
				if (mod.converters.length > 0) {
					res.anyConverters = true;
				}

				foreach (name, ref o; mod.kernels) {
					o.invalidate();
				}

				foreach (name, ref o; mod.surfaces) {
					o.invalidate();
				}

				foreach (name, ref o; mod.materials) {
					o.invalidate();
				}
			}
		}

		Dep.invalidateGraph((void delegate(Dep.DepTracker*) depSink) {
			void process(Dep.DepTracker* tr) {
				if (!tr.valid) {
					depSink(tr);
				}
			}
			
			foreach (modName, mod; _modules) {
				foreach (name, ref o; mod.kernels) {
					process(o.dependentOnThis);
				}

				foreach (name, ref o; mod.surfaces) {
					process(o.dependentOnThis);
				}

				foreach (name, ref o; mod.materials) {
					process(o.dependentOnThis);
				}
			}
		});
		
		return res;
	}

	
	private {
		enum Processed {
			Not,
			InProgress,
			Done
		}


		void doKernelSemantics() {
			Processed[KernelImpl] processed;

			foreach (name, mod; _modules) {
				foreach (kname, ref kimpl; mod.kernels) {
					if (kname in this.kernels) {
						error(
							"Multiple definitions of kernel '{}' in:\n  {}\n  and\n  {}.",
							kname,
							mod.filePath,
							this.kernels[kname].mod.filePath
						);
					} else {
						this.kernels[kname] = KernelInfo(
							&kimpl,
							mod
						);
					}

					if (KernelImpl.Type.Kernel == kimpl.type) {
						if (auto func = cast(Function)kimpl.kernel.func) {
							static assert (is(typeof(mod) == KDefModule));
							func.code._module = cast(void*)mod;
						}
						
						kimpl.kernel._module = cast(void*)mod;
					} else {
						GraphDef(kimpl.graph)._module = cast(void*)mod;
					}
				}
			}


			foreach (name, mod; _modules) {
				foreach (ref surf; mod.surfaces) {
					getKernel(surf.reflKernelName)
						.dependentOnThis.add(surf.dependentOnThis);
				}

				foreach (ref mat; mod.materials) {
					getKernel(mat.materialKernelName)
						.dependentOnThis.add(mat.dependentOnThis);
				}
			}
			

			foreach (n, ref k; kernels) {
				_curSemModule = k.mod;
				doKernelSemantics(*k.impl, modAlloc(k.mod), processed);
			}
		}

		void inheritKernel(KernelDef sub, KernelImpl supr) {
			iterKernelInputs(supr, (Param* p) {
				if (!sub.func.params.get(p.name)) {
					sub.func.params.add(*p);
				}
			});

			iterKernelOutputs(supr, (Param* p) {
				if (!sub.func.params.get(p.name)) {
					sub.func.params.add(*p);
				}
			});
		}

		void getPlainSemanticForNode(Param* par, Semantic* plainSem, KernelImpl supr) {
			findOutputSemantic(
				par,

				// getFormalParamSemantic
				(string name) {
					Semantic* res;
					
					iterKernelInputs(supr, (Param* p) {
						if (p.isInput && p.name == name) {
							res = p.semantic();
						}
					});
					
					if (res) {
						return *res;
					}
					
					error(
						"simplifyParamSemantics: output param '{}' refers to a"
						" nonexistent formal parameter '{}'.",
						par.name,
						name
					);
					assert (false);
				},

				// getActualParamSemantic
				(string name) {
					error(
						"Cannot derive node params from {}: param {} has a semantic expression.",
						supr.name,
						par.name
					);
					return Semantic.init;
				},
				
				plainSem
			);
		}

		void inheritKernelInputs(GraphDefNode node, KernelImpl supr) {
			iterKernelInputs(supr, (Param* p) {
				if (!node.params.get(p.name)) {
					assert (p.hasPlainSemantic);
					node.params.add(*p).dir = ParamDirection.Out;
				}
			});
		}

		void inheritKernelOutputs(GraphDefNode node, KernelImpl supr) {
			iterKernelOutputs(supr, (Param* p) {
				if (!node.params.get(p.name)) {
					if (!p.hasPlainSemantic) {
						auto pnew = node.params.add(ParamDirection.In, p.name);
						pnew.hasPlainSemantic = true;
						getPlainSemanticForNode(p, pnew.semantic, supr);
						pnew.copyValueFrom(p);
						pnew.annotation = p.annotation;
					} else {
						node.params.add(*p).dir = ParamDirection.In;
					}
				}
			});
		}
		

		void iterKernelParams(
				KernelImpl impl,
				bool wantInputs,
				void delegate(Param*) sink
		) {
			switch (impl.type) {
				case KernelImpl.Type.Kernel: {
					foreach (ref p; impl.kernel.func.params) {
						if (wantInputs == p.isInput) {
							sink(&p);
						}
					}
				} break;

				case KernelImpl.Type.Graph: {
					foreach (nodeName, node; GraphDef(impl.graph).nodes) {
						if ((wantInputs ? "input" : "output") == node.type) {
							foreach (ref p; node.params) {
								sink(&p);
							}
						}
					}
				} break;

				default: assert (false);
			}
		}

		void iterKernelInputs(KernelImpl impl, void delegate(Param*) sink) {
			iterKernelParams(impl, true, sink);
		}

		void iterKernelOutputs(KernelImpl impl, void delegate(Param*) sink) {
			iterKernelParams(impl, false, sink);
		}
		

		void doKernelSemantics(ref KernelDef k, Allocator allocator, ref Processed[KernelImpl] processed) {
			if (k.superKernel.length > 0) {
				auto superKernel = getKernel(k.superKernel);
				doKernelSemantics(superKernel, allocator, processed);
				inheritKernel(k, superKernel);

				superKernel.dependentOnThis.add(
					k.dependentOnThis
				);
			}
		}


		void doKernelSemantics(GraphDef graph, Allocator allocator, ref Processed[KernelImpl] processed) {
			KernelImpl superKernel;
			
			if (graph.superKernel.length > 0) {
				superKernel = getKernel(graph.superKernel);
				doKernelSemantics(superKernel, allocator, processed);

				superKernel.dependentOnThis.add(
					graph.dependentOnThis
				);
			}

			foreach (nodeName, node; graph.nodes) {
				switch (node.type) {
					case "input": {
						if (!superKernel.isNull) {
							inheritKernelInputs(node, superKernel);
						}
					} break;

					case "output": {
						if (!superKernel.isNull) {
							inheritKernelOutputs(node, superKernel);
						}
					} break;

					case "kernel": {
						auto kernelVar = node.getVar("kernel");
						if (kernelVar is null) {
							// TODO: err
							error("No kernel defined for a kernel node.");
						}
						if (auto ident = cast(IdentifierValue)kernelVar) {
							node.kernelImpl = getKernel(ident.value);
						}
						else if (auto literal = cast(KernelDefValue)kernelVar) {
							if (!cast(Function)literal.kernelDef.func) {
								// TODO: err
								error(
									"Graph nodes must use concrete kernel literals."
								);
							}
							
							doKernelSemantics(literal.kernelDef, allocator, processed);
							node.kernelImpl = KernelImpl(literal.kernelDef);
							node.kernelImpl.kernel.func.name = "literal";
							node.kernelImpl.kernel._module = cast(void*)_curSemModule;
						}
						else {
							error(
								"The 'kernel' var in a graph node must be"
								" either an identifier or a concrete kernel literal,"
								" not a '{}'", kernelVar.classinfo.name
							);
						}

						node.kernelImpl.dependentOnThis.add(
							graph.dependentOnThis
						);
					} break;

					default: break;
				}
			}
		}

		void doKernelSemantics(ref KernelImpl k, Allocator allocator, ref Processed[KernelImpl] processed) {
			if (auto p = k in processed) {
				switch (*p) {
					case Processed.InProgress: {
						char[] list;
						foreach (ki, p2; processed) {
							if (Processed.InProgress == p2) {
								list ~= "  '"~ki.name~"'\n";
							}
						}

						// TODO: keep track of the exact eval order
						error(
							"Recursive prosessing of a kernel '{}'. From:\n{}",
							k.name,
							list
						);
					} break;
					
					case Processed.Not: break;
					case Processed.Done: return;
					
					default: assert (false);
				}
			}
			
			processed[k] = Processed.InProgress;
			scope (success) processed[k] = Processed.Done;

			switch (k.type) {
				case KernelImpl.Type.Kernel: {
					doKernelSemantics(k.kernel, allocator, processed);
				} break;

				case KernelImpl.Type.Graph: {
					doKernelSemantics(GraphDef(k.graph), allocator, processed);
				} break;

				default: assert (false);
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
		
		
		//
		// --------------------------------------------------------------------------------------------------------------------------------
		
		void dumpInfo(KDefModule mod) {
			Stdout.formatln("* path: {}", mod.filePath);
			Stdout.formatln("* kernel impls:");
			
			foreach (n, impl; mod.kernels) {
				dumpInfo(impl);
			}
		}
		
		
		void dumpInfo(KernelImpl kimpl) {
			switch (kimpl.type) {
				case KernelImpl.Type.Graph:
					return dumpInfo(GraphDef(kimpl.graph));
				case KernelImpl.Type.Kernel:
					return dumpInfo(kimpl.kernel);
				default: assert (false);
			}
		}
		
		
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
				char[] code;
				qf.code.writeOut((char[] s) {
					code ~= s;
				});
				Stdout(code).newline;
				Stdout("----").newline;
			}
			Stdout("}").newline;
		}
		
		
		void dumpInfo(GraphDef graph) {
			Stdout("graph {").newline;
			Stdout.formatln("file:  {}", (cast(KDefModule)graph._module).filePath);
			Stdout.formatln("bytes: {}..{}", graph._firstByte, graph._firstByte + graph._lengthBytes);
			foreach (nodeName, _node; graph.nodes) {
				Stdout.formatln("\tnode: {}", nodeName);
			}
			/+foreach (graphName, subGraph; graph.graphs) {
				Stdout.formatln("\tsub-graph: ");
				dumpInfo(subGraph);
			}+/
			Stdout("}").newline;
		}
		
		
		void dumpInfo(KernelDef kernel) {
			dumpInfo(kernel.func);
		}
		
				
		void process(Scope sc, Allocator allocator) {
			gatherArrays!(string, Value)(sc.mem,
			(void delegate(lazy string, lazy Value) gen) {
				foreach (stmt_; sc.statements) {
					if (auto stmt = cast(AssignStatement)stmt_) {
						gen(stmt.name, stmt.value);
					}
				}
			},
			(string[] names, Value[] values) {
				sc.doAssign(names, values);
			});

			gatherArrays!(string, string)(sc.mem,
			(void delegate(lazy string, lazy string) gen) {
				foreach (stmt_; sc.statements) {
					if (auto stmt = cast(ConnectStatement)stmt_) {
						if (auto graph = cast(GraphDef)sc) {
							gen(stmt.from, stmt.to);
						} else {
							throw new Exception("connections only allowed at graph scope");
						}
					}
				}
			},
			(string[] from, string[] to) {
				(cast(GraphDef)sc).doConnect(from, to);
			});

			gatherArrays!(string)(sc.mem,
			(void delegate(lazy string) gen) {
				foreach (stmt_; sc.statements) {
					if (auto stmt = cast(NoAutoFlowStatement)stmt_) {
						if (auto graph = cast(GraphDef)sc) {
							gen(stmt.to);
						} else {
							error("Can't use noauto outside of graph definitions.");
						}
					}
				}
			},
			(string[] to) {
				(cast(GraphDef)sc).setNoAuto(to);
			});
			
			

			foreach (stmt_; sc.statements) {
				if (auto stmt = cast(ConnectStatement)stmt_) {
					// nothing
				} else if (auto stmt = cast(NoAutoFlowStatement)stmt_) {
					// nothing
				} else if (auto stmt = cast(AssignStatement)stmt_) {
					if (auto scopeValue = cast(IScopeValue)stmt.value) {
						process(scopeValue.toScope, allocator);
					}
					
					if (auto kernelValue = cast(KernelDefValue)stmt.value) {
						kernelValue.kernelDef.func.name = stmt.name;
						if (auto mod = cast(KDefModule)sc) {
							mod.kernels[stmt.name] = KernelImpl(kernelValue.kernelDef);
						}
					}
					
					if (auto graphValue = cast(GraphDefValue)stmt.value) {
						GraphDef(graphValue.graphDef)._name = stmt.name;
						if (auto mod = cast(KDefModule)sc) {
							mod.kernels[stmt.name] = KernelImpl(graphValue.graphDef);
						}
					}
					
					if (auto surfValue = cast(SurfaceDefValue)stmt.value) {
						surfValue.surface.name = stmt.name;
						if (auto mod = cast(KDefModule)sc) {
							mod.surfaces[stmt.name] = surfValue.surface;
						}
					}

					if (auto matValue = cast(MaterialDefValue)stmt.value) {
						matValue.material.name = stmt.name;
						if (auto mod = cast(KDefModule)sc) {
							mod.materials[stmt.name] = matValue.material;
						}
					}

					if (auto nodeValue = cast(GraphDefNodeValue)stmt.value) {
						auto node = nodeValue.node;

						switch (node.type) {
							case "input": 
							case "data":
							case "output": {
								node.params = ParamList(allocator._allocator);
							}
							default: break;
						}

						buildConcreteParams(node, &node.params);
					}

					if (auto traitValue = cast(TraitDefValue)stmt.value) {
						traitValue.value.name = stmt.name;
						if (auto mod = cast(KDefModule)sc) {
							mod.traitDefs ~= traitValue.value;
						}
					}
				} else if (auto stmt = cast(ImportStatement)stmt_) {
					auto path = stmt.path;
					processFile(path);
					auto names = stmt.what;
					auto mod = _modules[path];
					
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
							// Will get renamed for overloads by codegen
							name = "converter";
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
		KDefModule[string]	_modules;

		KDefModule			_curSemModule;
	}
}
