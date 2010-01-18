module xf.gfx.UniformBuffer;

private {
	import xf.gfx.Resource;
	import xf.gfx.Buffer;
}

public {
	alias xf.gfx.Buffer.BufferAccess BufferAccess;
}


struct UniformBuffer {
	typedef BufferHandle Handle;
	mixin MResource;
	mixin MBuffer;
}
