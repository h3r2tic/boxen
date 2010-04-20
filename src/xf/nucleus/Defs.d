module xf.nucleus.Defs;

private {
	import xf.Common;
}



typedef u32 RenderableId;


enum Domain {
	GPU	= 0b1,
	CPU	= 0b10,
	Any	= GPU | CPU,
	Unresolved = 0b100
}
