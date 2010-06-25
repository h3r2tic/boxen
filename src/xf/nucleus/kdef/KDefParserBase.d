module xf.nucleus.kdef.KDefParserBase;

private {
	import xf.nucleus.Param;
	import xf.nucleus.Value;
	import xf.nucleus.Code;
	import xf.nucleus.Function;
	import xf.nucleus.kdef.KDefLexer;
	import xf.nucleus.kdef.Common;
	import xf.nucleus.kernel.KernelDef;
	import xf.nucleus.kernel.KernelImplDef;
	import xf.nucleus.TypeSystem;

	import enkilib.d.Parser;
	import enkilib.d.ParserException;

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

		alias void* delegate(size_t) Allocator;
		Allocator	allocator;
	}
	

	protected {
		double parseDouble(char[] val) {
			return Float.parse(val);
		}
		
		// --------------------------------------------------------------------
		
		
		void parseSyntax(Statement[] statements) {
			this.statements = statements;
		}
		

		/+KernelDef parseKernelDef(AbstractFunction[] funcs, string[] before, string[] after, ParamDef[] attribs) {
			auto kd = new KernelDef;
			kd.functions = funcs;
			return kd;
			// TODO
			//kd.attribs = attribs;
			//kd.overrideOrdering(before.dupStringArray(), after.dupStringArray());
			//return kd;
		}+/
		
		
		VarDef parseVarDef(string name, Value value) {
			return VarDef(name.dup, value);
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
			res.name = name.dup;
			res.value = value is null ? null : value.toString.dup;
			return res;
		}

		// --------------------------------------------------------------------


		char[] concatTokens(KDefToken[] tokens){
			return KDefToken.concat(tokens);
		}
		

		override void error(char[] message) {
			auto tok = data[pos];
			throw ParserException("{} ({}): {} (got '{}' instead)", tok.filename, tok.line, message, data[pos]);
		}
		

		void semanticError(char[] fmt, ...) {
			char[512] buf;
			char[] message = Format.vprint(buf, fmt, _arguments, _argptr);
			auto tok = data[pos > 0 ? pos-1 : 0];
			throw ParserException("{} ({}): {}", tok.filename, tok.line, message);
		}



		QuarkDefValue createQuarkDefValue(string superKernel, ParamDef[] params, Code code, string[] tags) {
			auto res = new QuarkDefValue;
			res.superKernel = superKernel;
			res.params = params;
			res.code = code;
			return res;
		}


		KernelDefValue createKernelDefValue(string superKernel, ParamDef[] params, string[] tags) {
			auto res = new KernelDefValue;
			res.kernelDef = new KernelDef;
			res.kernelDef.func = createAbstractFunction(null, tags, params);
			res.kernelDef.superKernel = superKernel.dup;
			return res;
		}


		GraphDefValue createGraphDefValue(string superKernel, Statement[] stmts, string[] tags) {
			auto res = new GraphDefValue;
			assert(false, "TODO");
			return res;
	//		Stdout.formatln("GraphDefValue('{}')", label);
			/+this.graphDef = graphDef;
			this.graphDef.label = label is null ? null : label.dup;+/
		}


		GraphDefNodeValue createGraphDefNodeValue(VarDef[] vars) {
			auto res = new GraphDefNodeValue;
			assert(false, "TODO");
			return res;
			//this.node = node;
		}


		TraitDefValue createTraitDefValue(string[] values, string defaultValue) {
			auto res = new TraitDefValue;
			res.value = new TraitDef;
			res.value.values = values.dupStringArray();
			res.value.defaultValue = defaultValue.dup;
			return res;
		}


		AbstractFunction createAbstractFunction(string name, string[] tags, ParamDef[] params) {
			auto res = new AbstractFunction(name, tags, allocator);
			_createFunctionParams(params, res);
			return res;
		}
		
		Function createFunction(string name, string[] tags, ParamDef[] params, Code code) {
			auto res = new Function(name, tags, code, allocator);
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
			auto func = new Function(name, tags, code, allocator);
			_createFunctionParams(params, func);
			auto res = new ConverterDeclStatement;
			res.func = func;
			res.cost = cast(int)cost;		// HACK
			return res;
		}
	}
}
