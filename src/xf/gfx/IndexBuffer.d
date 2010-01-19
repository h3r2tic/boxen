module xf.gfx.IndexBuffer;

private {
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
