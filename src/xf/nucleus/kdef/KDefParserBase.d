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



class KDefParserBase : Parser!(KDefToken){
	public {
		abstract bool	parse_Syntax();
		Statement[]	statements;
	}
	

	protected {
		double parseDouble(char[] val) {
			return Float.parse(val);
		}
		
		// --------------------------------------------------------------------
		
		
		void parseSyntax(Statement[] statements) {
			this.statements = statements;
		}
		

		KernelImplDef parseKernelImpl(string name, double score) {
			double frac = tango.stdc.math.fmod(score, 1.0);
			if (frac != 0) {
				semanticError("Kernel implementation score must be integral. Got: {}", score);
			}			
			return KernelImplDef(name.dup, cast(int)score);
		}
		
		
		KernelDef parseKernelDef(AbstractFunction[] funcs, string[] before, string[] after, ParamDef[] attribs) {
			auto kd = new KernelDef;
			kd.functions = funcs;
			// TODO
			assert (false);
			//kd.attribs = attribs;
			//kd.overrideOrdering(before.dupStringArray(), after.dupStringArray());
			//return kd;
		}
		
		
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
			res.value = value.toString.dup;
			return res;
		}


		AbstractFunction createAbstractFunction(string name, ParamDef[] params) {
			return AbstractFunction(name, _createFunctionParams(params));
		}
		
		Function createFunction(string name, ParamDef[] params, Code code) {
			return Function(name, _createFunctionParams(params), code);
		}

		private void _createFunctionParams(ParamDef[] defs) {
			// TODO: mem
			Param[] res = new Param[defs.length];
			foreach (i, d; defs) {
				auto r = &res[i];
				r.dir = ParamDirectionFromString(d.dir);
				r.type = d.type;
				r.name = d.name;

			}
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
	}
}
