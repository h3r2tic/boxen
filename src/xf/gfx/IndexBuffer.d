module xf.gfx.IndexBuffer;

private {
	import xf.Common;
	import xf.gfx.Resource;
	import xf.gfx.Buffer;
}

public {
	alias xf.gfx.Buffer.BufferAccess BufferAccess;
}



enum IndexType {
	U16,
	U32
}


interface IIndexBufferMngr : IBufferMngr {
	IndexBuffer createIndexBuffer(BufferUsage usage, u32[] data);
	IndexBuffer createIndexBuffer(BufferUsage usage, u16[] data);
	IndexBuffer createIndexBuffer(BufferUsage usage, int size, void* data, IndexType it);
}


struct IndexBuffer {
	typedef BufferHandle Handle;
	mixin MResource;
	mixin MBuffer;
	
	static IndexBuffer fromBuffer(ref Buffer buf, IndexType it) {
		IndexBuffer ib = void;
		*cast(Buffer*)&ib = buf;
		ib.indexType = it;
		return ib;
	}
	
	IndexType indexType;
}
