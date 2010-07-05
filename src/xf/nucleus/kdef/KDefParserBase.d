module xf.nucleus.kdef.KDefParserBase;

private {
	import xf.nucleus.Param;
	import xf.nucleus.Value;
	import xf.nucleus.Code;
	import xf.nucleus.Function;
	import xf.nucleus.SurfaceDef;
	import xf.nucleus.MaterialDef;
	import xf.nucleus.SamplerDef;
	import xf.nucleus.kdef.KDefLexer;
	import xf.nucleus.kdef.Common;
	import xf.nucleus.kernel.KernelDef;
	import xf.nucleus.TypeSystem;
	import xf.nucleus.kdef.ParamUtils;

	import enkilib.d.Parser;
	import enkilib.d.ParserException;

	import xf.mem.ScratchAllocator;

	import Float = tango.text.convert.Float;
	import tango.text.convert.Format : Format;
	static import tango.stdc.math;
	
	import tango.io.Stdout;
}

public {
	import tango.core.Variant;
	alias char[] string;
}



class KDefParserBase : Parser!(KDefToken) {
	public {
		abstract bool	parse_Syntax();
		Statement[]		statements;

		DgScratchAllocator	mem;
	}
	

	protected {
		double parseDouble(char[] val) {
			return Float.parse(val);
		}
		
		// --------------------------------------------------------------------
		
		
		void parseSyntax(Statement[] statements) {
			this.statements = statements;
		}
		

		VarDef parseVarDef(string name, Value value) {
			return VarDef(mem.dupString(name), value);
		}
		

		ParamSemanticExp createParamSemanticSum(ParamSemanticExp a, ParamSemanticExp b) {
			auto res = new ParamSemanticExp(ParamSemanticExp.Type.Sum);
			res.exp1 = a;
			res.exp2 = b;
			return res;
		}

		ParamSemanticExp createParamSemanticExclusion(ParamSemanticExp a, ParamSemanticExp b) {
			auto res = new ParamSemanticExp(ParamSemanticExp.Type.Exclusion);
			res.exp1 = a;
			res.exp2 = b;
			return res;
		}
		
		ParamSemanticExp parseParamSemanticTrait(string name, Value value) {
			auto res = new ParamSemanticExp(ParamSemanticExp.Type.Trait);
			res.name = mem.dupString(name);
			res.value = value is null ? null : mem.dupString(value.toString);
			return res;
		}

		// --------------------------------------------------------------------


		char[] concatTokens(KDefToken[] tokens){
			return KDefToken.concat(tokens);
		}
		

		override void error(char[] message) {
			auto tok = data[pos < $ ? pos : ($-1)];
			throw ParserException("{} ({}): {} (got '{}' instead)", tok.filename, tok.line, message, tok);
		}
		

		void semanticError(char[] fmt, ...) {
			char[512] buf;
			char[] message = Format.vprint(buf, fmt, _arguments, _argptr);
			auto tok = data[pos > 0 ? pos-1 : 0];
			throw ParserException("{} ({}): {}", tok.filename, tok.line, message);
		}



		KernelDefValue createKernelDefValue(string superKernel, ParamDef[] params, Code code, string[] tags) {
			auto res = new KernelDefValue;
			res.kernelDef = new KernelDef;
			if (code != code.init) {
				res.kernelDef.func = createFunction(null, tags, params, code);
			} else {
				res.kernelDef.func = createAbstractFunction(null, tags, params);
			}
			res.kernelDef.superKernel = mem.dupString(superKernel);
			return res;
		}


		GraphDefValue createGraphDefValue(string superKernel, Statement[] stmts, string[] tags) {
			auto res = new GraphDefValue;
			res.graphDef = new GraphDef(stmts);
			res.graphDef.superKernel = mem.dupString(superKernel);
			res.graphDef.tags = dupStringArray(tags);
			return res;
		}


		GraphDefNodeValue createGraphDefNodeValue(VarDef[] vars) {
			auto res = new GraphDefNodeValue;
			res.node = new GraphDefNode(vars);
			return res;
		}


		TraitDefValue createTraitDefValue(string[] values, string defaultValue) {
			auto res = new TraitDefValue;
			res.value = new TraitDef;
			res.value.values = values.dupStringArray();
			res.value.defaultValue = defaultValue.dup;
			return res;
		}


		SurfaceDefValue createSurfaceDefValue(string illumKernel, VarDef[] vars) {
			auto res = new SurfaceDefValue;
			auto surf = res.surface = new SurfaceDef(illumKernel, mem._allocator);
			foreach (var; vars) {
				setParamValue(
					surf.params.add(ParamDirection.Out, var.name),
					var.value
				);
			}
			return res;
		}


		MaterialDefValue createMaterialDefValue(string pigmentKernel, VarDef[] vars) {
			auto res = new MaterialDefValue;
			auto mat = res.material = new MaterialDef(pigmentKernel, mem._allocator);
			foreach (var; vars) {
				setParamValue(
					mat.params.add(ParamDirection.Out, var.name),
					var.value
				);
			}
			return res;
		}


		SamplerDefValue createSamplerDefValue(VarDef[] vars) {
			auto res = new SamplerDefValue;
			auto meh = res.value = new SamplerDef(mem._allocator);

			// HACK until proper memory management in the parser is done
			static SamplerDef[] allSamplersHACK;
			allSamplersHACK ~= meh;
			
			foreach (var; vars) {
				setParamValue(
					meh.params.add(ParamDirection.Out, var.name),
					var.value
				);
			}
			return res;
		}


		ImportStatement createImportStatement(string path, string[] what) {
			return mem._new!(ImportStatement)(
				mem.dupString(path),
				dupStringArray(what)
			);
		}


		Code createCode(Atom[] tokens) {
			Code res;
			//char[] orig;
			writeOutTokens(tokens, (string s) {
				res.append(s, mem);
				//orig ~= s;
			});
			/+char[] neu;
			res.writeOut((string s) {
				neu ~= s;
			});
			assert (neu == orig);+/
			return res;
		}


		string[] dupStringArray(string[] arr) {
			string[] res = mem.allocArrayNoInit!(string)(arr.length);
			foreach (i, s; arr) {
				res[i] = mem.dupString(s);
			}
			return res;
		}


		AbstractFunction createAbstractFunction(string name, string[] tags, ParamDef[] params) {
			auto res = new AbstractFunction(name, tags, mem._allocator);
			_createFunctionParams(params, res);
			return res;
		}
		
		
		Function createFunction(string name, string[] tags, ParamDef[] params, Code code) {
			auto res = new Function(name, tags, code, mem._allocator);
			_createFunctionParams(params, res);
			return res;
		}


		void _createFunctionParams(
				ParamDef[] defs,
				AbstractFunction func
		) {
			foreach (d; defs) {
				final dir = ParamDirectionFromString(d.dir);

				auto p = func.params.add(
					dir,
					d.name
				);

				setParamValue(p, d.defaultValue);

				if (ParamDirection.In == dir) {
					p.hasPlainSemantic = true;
					final psem = p.semantic();

					if (d.type.length > 0) {
						p.type = d.type;
					}

					void buildSemantic(ParamSemanticExp sem) {
						if (sem is null) {
							return;
						}
						
						if (sem) {
							if (ParamSemanticExp.Type.Sum == sem.type) {
								buildSemantic(sem.exp1);
								buildSemantic(sem.exp2);
							} else if (ParamSemanticExp.Type.Trait == sem.type) {
								psem.addTrait(sem.name, sem.value);
								// TODO: check the type?
							} else {
								// TODO: err
								assert (false, "Subtractive trait used in an input param.");
							}
						}
					}
					
					buildSemantic(d.paramSemantic);
				} else {
					p.hasPlainSemantic = false;
					final psem = p.semanticExp();

					if (d.type.length > 0) {
						psem.addTrait("type", d.type, SemanticExp.TraitOp.Add);
					}

					void buildSemanticExp(ParamSemanticExp sem, bool add) {
						if (sem is null) {
							return;
						}
						
						if (sem) {
							if (ParamSemanticExp.Type.Sum == sem.type) {
								buildSemanticExp(sem.exp1, add);
								buildSemanticExp(sem.exp2, add);
							} else if (ParamSemanticExp.Type.Exclusion == sem.type) {
								buildSemanticExp(sem.exp1, add);
								buildSemanticExp(sem.exp2, !add);
							} else if (ParamSemanticExp.Type.Trait == sem.type) {
								auto opType = SemanticExp.TraitOp.Add;
								if (!add) {
									opType = SemanticExp.TraitOp.Remove;
								}
								psem.addTrait(sem.name,	sem.value, opType);
							} else {
								assert (false, "WAT");
							}
						}
					}
					
					buildSemanticExp(d.paramSemantic, true);
				}
			}
		}

		ConverterDeclStatement createConverter(string name, string[] tags, ParamDef[] params, Code code, double cost) {
			auto func = new Function(name, tags, code, mem._allocator);
			_createFunctionParams(params, func);
			auto res = new ConverterDeclStatement;
			res.func = func;
			res.cost = cast(int)cost;
			return res;
		}
	}
}
