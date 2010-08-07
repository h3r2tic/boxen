module xf.nucleus.kdef.model.IKDefUtilParser;

private {
	import xf.Common;
	import xf.nucleus.Value;
	import xf.nucleus.TypeSystem;
}



interface IKDefUtilParser {
	VarDef[] parse_TemplateArgList(cstring source);
	bool parse_ParamSemantic(cstring source, void delegate(Semantic) sink);
}
