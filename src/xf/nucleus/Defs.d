module xf.nucleus.Defs;

private {
	import xf.Common;
	import xf.gfx.Defs;
}



typedef u32 RenderableId;
typedef u32 LightId;


enum Domain {
	GPU	= 0b1,
	CPU	= 0b10,
	Any	= GPU | CPU,
	Unresolved = 0b100
}


alias xf.gfx.Defs.GPUDomain GPUDomain;
