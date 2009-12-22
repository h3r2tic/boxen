module xf.gfx.VertexBuffer;

private {
	import xf.gfx.Resource;
	import xf.gfx.Buffer;
}

public {
	alias xf.gfx.Buffer.BufferAccess BufferAccess;
}



interface IVertexBufferMngr : IBufferMngr {
}


struct VertexBuffer {
	typedef BufferHandle Handle;
	mixin MResource;
	mixin MBuffer;
}
