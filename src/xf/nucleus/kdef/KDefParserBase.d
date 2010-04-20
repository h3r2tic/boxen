module xf.nucleus.kdef.KDefParserBase;

private {
	import xf.nucleus.kdef.KDefLexer;
	import xf.nucleus.kdef.KDefToken;
	import xf.nucleus.kdef.Common;
	import xf.nucleus.kernel.KernelDef;
	import xf.nucleus.CommonDef;
	import xf.nucleus.SemanticTypeSystem;

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
		
		
		KernelDef parseKernelDef(KernelFunction[] funcs, string[] before, string[] after, Param[] attribs) {
			auto kd = new KernelDef;
			kd.functions = funcs;
			kd.attribs = attribs;
			kd.overrideOrdering(before.dupStringArray(), after.dupStringArray());
			return kd;
		}
		
		
		VarDef parseVarDef(string name, Value value) {
			return VarDef(name.dup, value);
		}
		
		
		Param createParam(string dir_, string type, ParamSemantic paramSemantic, string name, Value defaultValue) {
			alias Param.Direction Direction;
			auto dir = (["in"[] : Direction.In, "out" : Direction.Out, "inout" : Direction.InOut, "own" : Direction.Own])[dir_];
			
			Semantic		semantic;
			Value[string]	annotations;
			
			if (paramSemantic !is null) {
				foreach (traitName, traitValue; paramSemantic.traits) {
					semantic.addTrait(Trait(traitName, traitValue.toVariant));
				}
				
				foreach (ann; paramSemantic.annotations) {
					annotations[ann.name] = ann.value;
				}
			}
			
			auto res = Param(dir, type.dup, name.dup, semantic, defaultValue, annotations);
			res.dataProvider = new DataProviderRef;
			
			// TODO: create the provider
			
			return res;
		}
		
		
		ParamSemantic createParamSemantic(VarDef[] vars) {
			auto r = new ParamSemantic;
			
			foreach (var; vars) {
				if ('@' == var.name[0]) {
					r.traits[var.name[1..$]] = var.value;
				} else {
					r.annotations ~= var;
				}
			}
			
			return r;
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
