module xf.nucleus.kdef.model.IKDefUtilParser;

private {
	//import xf.nucleus.kdef.Common;
	import xf.nucleus.CommonDef;
	alias char[] string;
}



interface IKDefUtilParser {
	VarDef[] parse_TemplateArgList(string source);
}
