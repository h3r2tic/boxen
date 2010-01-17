module xf.gfx.VertexBuffer;

private {
	import xf.gfx.Resource;
	import xf.gfx.Buffer;
}

public {
	alias xf.gfx.Buffer.BufferAccess BufferAccess;
}


struct VertexAttrib {
	enum Type : ushort {
		Float,
		Vec2,
		Vec3,
		Vec4,
		Mat4
		// TODO: moar
	}
	
	size_t	offset;
	ushort	stride;
	Type	type;
}


struct VertexBuffer {
	typedef BufferHandle Handle;
	mixin MResource;
	mixin MBuffer;
}
