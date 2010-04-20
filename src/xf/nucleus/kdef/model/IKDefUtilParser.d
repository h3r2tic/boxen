module xf.nucleus.kdef.model.IKDefUtilParser;

private {
	import xf.Common;
	import xf.nucleus.Value;
}



interface IKDefUtilParser {
	VarDef[] parse_TemplateArgList(cstring source);
}
