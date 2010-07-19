module xf.nucleus.graph.GraphDefs;

private {
	import xf.Common;
}



struct GraphNodeId {
	ushort	id = ushort.max;
	ushort	reuseCnt;

	bool valid() {
		return id != ushort.max;
	}
}


struct DataFlow {
	cstring from;
	cstring to;
	uword	userData;
}
