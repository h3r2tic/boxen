module xf.nucleus.kdef.KDefParserBase;

private {
	import xf.Common : startsWith;
	
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
	import xf.nucleus.kdef.KDefToken;

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
		

		VarDef parseVarDef(string name, Value value, Annotation[] annots) {
			return VarDef(mem.dupString(name), value, mem.dupArray(annots).ptr);
		}
		

		ParamSemanticExp createParamSemanticSum(ParamSemanticExp a, ParamSemanticExp b) {
			auto res = mem._new!(ParamSemanticExp)(ParamSemanticExp.Type.Sum);
			res.exp1 = a;
			res.exp2 = b;
			return res;
		}

		ParamSemanticExp createParamSemanticExclusion(ParamSemanticExp a, ParamSemanticExp b) {
			auto res = mem._new!(ParamSemanticExp)(ParamSemanticExp.Type.Exclusion);
			res.exp1 = a;
			res.exp2 = b;
			return res;
		}
		
		ParamSemanticExp parseParamSemanticTrait(string name, Value value) {
			auto res = mem._new!(ParamSemanticExp)(ParamSemanticExp.Type.Trait);
			res.name = mem.dupString(name);
			res.value = value is null ? null : mem.dupString(value.toString);
			return res;
		}

		// --------------------------------------------------------------------


		char[] concatTokens(KDefToken[] tokens){
			return KDefToken.concat(tokens, mem);
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


		ConnectStatement createConnectStatement(string from, string to) {
			return mem._new!(ConnectStatement)(mem.dupString(from), mem.dupString(to));
		}

		NoAutoFlowStatement createNoAutoFlowStatement(string to) {
			return mem._new!(NoAutoFlowStatement)(mem.dupString(to));
		}

		AssignStatement createAssignStatement(string name, Value value) {
			return mem._new!(AssignStatement)(mem.dupString(name), value);
		}
		
		ParamDef createParamDef(
			string dir,
			string type,
			ParamSemanticExp semantic,
			string name,
			Value defaultValue,
			Annotation[] annotations,
		) {
			return mem._new!(ParamDef)(
				mem.dupString(dir),
				mem.dupString(type),
				semantic,
				mem.dupString(name),
				defaultValue,
				mem.dupArray(annotations)
			);
		}
		
		BooleanValue createBooleanValue(string value) {
			return mem._new!(BooleanValue)(value);
		}
		
		IdentifierValue createIdentifierValue(string value) {
			return mem._new!(IdentifierValue)(mem.dupString(value));
		}
		
		NumberValue createNumberValue(double value) {
			return mem._new!(NumberValue)(value);
		}
		
		Vector2Value createVector2Value(double x, double y) {
			return mem._new!(Vector2Value)(x, y);
		}
		
		Vector3Value createVector3Value(double x, double y, double z) {
			return mem._new!(Vector3Value)(x, y, z);
		}
		
		Vector4Value createVector4Value(double x, double y, double z, double w) {
			return mem._new!(Vector4Value)(x, y, z, w);
		}
		
		StringValue createStringValue(char[] value) {
			return mem._new!(StringValue)(mem.dupString(value));
		}
		
		ParamListValue createParamListValue(ParamDef[] params) {
			return mem._new!(ParamListValue)(mem.dupArray(params));
		}


		// no need to dup params, as they're immediately converted
		// tags and name dup'd by the Function
		KernelDefValue createKernelDefValue(string superKernel, ParamDef[] params, Code code, string[] tags) {
			auto res = mem._new!(KernelDefValue)();
			res.kernelDef = mem._new!(KernelDef)(mem._allocator);
			
			if (code != code.init) {
				final func = createFunction(null, tags, params, code);
				res.kernelDef.func = func;
				func.kernelDef = cast(void*)res.kernelDef;
			} else {
				res.kernelDef.func = createAbstractFunction(null, tags, params);
			}

			res.kernelDef.superKernel = mem.dupString(superKernel);
			return res;
		}


		GraphDefValue createGraphDefValue(string superKernel, Statement[] stmts/+, string[] tags+/) {
			auto res = mem._new!(GraphDefValue)();
			res.graphDef = mem._new!(GraphDef)(mem.dupArray(stmts), mem._allocator);
			res.graphDef.superKernel = mem.dupString(superKernel);
			//res.graphDef.tags = dupStringArray(tags);
			return res;
		}


		GraphDefNodeValue createGraphDefNodeValue(VarDef[] vars) {
			auto res = mem._new!(GraphDefNodeValue)();
			res.node = mem._new!(GraphDefNode)(mem.dupArray(vars), mem._allocator);
			return res;
		}


		TraitDefValue createTraitDefValue(string[] values, string defaultValue) {
			auto res = mem._new!(TraitDefValue)();
			res.value = mem._new!(TraitDef)();
			res.value.values = values.dupStringArray();
			res.value.defaultValue = mem.dupString(defaultValue);
			return res;
		}


		SurfaceDefValue createSurfaceDefValue(string reflKernel, VarDef[] vars) {
			auto res = mem._new!(SurfaceDefValue)();
			auto surf = res.surface = mem._new!(SurfaceDef)(mem.dupString(reflKernel), mem._allocator);
			foreach (var; vars) {
				setParamValue(
					surf.params.add(ParamDirection.Out, var.name),
					var.value
				);
			}
			return res;
		}


		MaterialDefValue createMaterialDefValue(string materialKernel, VarDef[] vars) {
			auto res = mem._new!(MaterialDefValue)();
			auto mat = res.material = mem._new!(MaterialDef)(mem.dupString(materialKernel), mem._allocator);
			foreach (var; vars) {
				final par = mat.params.add(ParamDirection.Out, var.name);
				setParamValue(
					par,
					var.value
				);
				par.annotation = var.annotation;
			}
			return res;
		}


		SamplerDefValue createSamplerDefValue(VarDef[] vars) {
			auto res = mem._new!(SamplerDefValue)();
			auto meh = res.value = mem._new!(SamplerDef)(mem._allocator);

			foreach (var; vars) {
				final par = meh.params.add(ParamDirection.Out, var.name);
				setParamValue(
					par,
					var.value
				);
				par.annotation = var.annotation;
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
			writeOutTokens(tokens, (string s) {
				res.append(s, mem);
			});
			if (tokens.length > 0) {
				res._firstByte = tokens[0].byteNr;
				
				res._lengthBytes = tokens[$-1].byteNr + tokens[$-1].toString.length;
				res._lengthBytes -= res._firstByte;
			} else {
				res._lengthBytes = 0;
			}
			return res;
		}


		string[] dupStringArray(string[] arr) {
			string[] res = mem.allocArrayNoInit!(string)(arr.length);
			foreach (i, s; arr) {
				res[i] = mem.dupString(s);
			}
			return res;
		}


		// no need to dup params, as they're immediately converted
		// tags and name dup'd by the Function
		AbstractFunction createAbstractFunction(string name, string[] tags, ParamDef[] params) {
			auto res = mem._new!(AbstractFunction)(name, tags, mem._allocator);
			_createFunctionParams(params, res);
			return res;
		}
		
		
		// no need to dup params, as they're immediately converted
		// tags and name dup'd by the Function
		Function createFunction(string name, string[] tags, ParamDef[] params, Code code) {
			auto res = mem._new!(Function)(name, tags, code, mem._allocator);
			_createFunctionParams(params, res);
			return res;
		}


		// no need to dup params, as they're immediately converted
		// tags and name dup'd by the Function
		ConverterDeclStatement createConverter(string name, string[] tags, ParamDef[] params, Code code, double cost) {
			auto func = mem._new!(Function)(name, tags, code, mem._allocator);
			_createFunctionParams(params, func);
			auto res = mem._new!(ConverterDeclStatement)();
			res.func = func;
			res.cost = cast(int)cost;
			return res;
		}


		Annotation createAnnotation(string name, VarDef[] vars) {
			Annotation res;
			res.name = mem.dupString(name);
			res.vars = mem.dupArray(vars);
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

				if (d.annotations.length > 0) {
					p.annotation = &d.annotations;
				}

				bool hasPlainSemantic = true;
				void checkPlainSemantic(ParamSemanticExp sem) {
					if (sem is null) {
						return;
					}
					
					if (sem) {
						if (ParamSemanticExp.Type.Sum == sem.type) {
							checkPlainSemantic(sem.exp1);
							checkPlainSemantic(sem.exp2);
						} else if (ParamSemanticExp.Type.Trait == sem.type) {
							// TODO: resolve formal in. references
							if (startsWith(sem.name, "in.")) {
								hasPlainSemantic = false;
							}
						} else {
							hasPlainSemantic = false;
						}
					}
				}
				checkPlainSemantic(d.paramSemantic);

				if (ParamDirection.In == dir || hasPlainSemantic) {
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
	}
}
