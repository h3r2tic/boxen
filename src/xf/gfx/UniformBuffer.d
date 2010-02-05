module xf.gfx.UniformBuffer;

private {
	import xf.gfx.Resource;
	import xf.gfx.Buffer;
}

public {
	alias xf.gfx.Buffer.BufferAccess BufferAccess;
}



interface IUniformBufferMngr : IBufferMngr {
	UniformBuffer createUniformBuffer(BufferUsage usage, void[] data);
	UniformBuffer createUniformBuffer(BufferUsage usage, int size, void* data);
}


struct UniformBuffer {
	typedef BufferHandle Handle;
	mixin MResource;
	mixin MBuffer;
}
