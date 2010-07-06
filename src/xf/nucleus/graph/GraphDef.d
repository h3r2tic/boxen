module xf.nucleus.graph.GraphDef;

private {
	import xf.Common;
	import xf.nucleus.DepTracker;
}



interface IGraphDef {
	cstring		name();
	uword		numNodes();
	DepTracker* dependentOnThis();
	bool		opEquals(IGraphDef other);
}
