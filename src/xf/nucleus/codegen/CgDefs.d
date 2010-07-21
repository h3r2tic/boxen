module xf.nucleus.codegen.CgDefs;

private {
	import
		xf.Common;
		
	import
		xf.nucleus.Param,
		xf.nucleus.codegen.Defs,
		xf.nucleus.graph.GraphDefs;
		
	import Integer = tango.text.convert.Integer;
}



package struct BindingSemantic {
	cstring	name;
	uint	index;

	static BindingSemantic parse(cstring str) {
		int i = void;
		for (i = str.length-1; i > 0 && str[i] >= '0' && str[i] <= '9'; ++i) {
			// nothing
		}

		++i;
		if (i != str.length) {
			return BindingSemantic(str[0..i], cast(uint)Integer.parse(str[i..$]));
		} else {
			return BindingSemantic(str, 0);
		}
	}

	void writeOut(CodeSink sink) {
		if (index != 0) {
			sink(name)(index);
		} else {
			sink(name);
		}
	}
}


package struct CgParam {
	GraphNodeId		node;
	Param*			param;
	GraphNodeId		dstNode;
	cstring			dstName;
	BindingSemantic	bindingSemantic;
}
