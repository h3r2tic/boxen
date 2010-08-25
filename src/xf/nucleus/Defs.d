module xf.nucleus.Defs;

private {
	import xf.Common;
	import xf.gfx.Defs;
}


private struct _Id(store) {
	typedef store Type;
	
	Type value = Type.max;

	const _Id invalid = { value : Type.max };

	bool isValid() {
		return value != Type.max;
	}
}


// TODO: use the _Id template
typedef u32	RenderableId;
typedef u32	LightId;
typedef u8	SurfaceId;
typedef u16	MaterialId;		// the indices should be kept low (reused)

alias _Id!(u32)	KernelImplId;


enum Domain {
	GPU	= 0b1,
	CPU	= 0b10,
	Any	= GPU | CPU,
	Unresolved = 0b100
}


alias xf.gfx.Defs.GPUDomain GPUDomain;
