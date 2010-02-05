module xf.gfx.VertexBuffer;

private {
	import xf.gfx.Resource;
	import xf.gfx.Buffer;
}

public {
	alias xf.gfx.Buffer.BufferAccess BufferAccess;
}


interface IVertexBufferMngr : IBufferMngr {
	VertexBuffer createVertexBuffer(BufferUsage usage, void[] data);
	VertexBuffer createVertexBuffer(BufferUsage usage, int size, void* data);
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
	
	enum ScalarType {
		Float
	}
	
	size_t	offset;
	ushort	stride;
	Type	type;
	
	
	int numFields() {
		switch (type) {
			case Type.Float:	return 1;
			case Type.Vec2:		return 2;
			case Type.Vec3:		return 3;
			case Type.Vec4:		return 4;
			case Type.Mat4:		return 16;
			default: assert (false);
		}
	}
	
	ScalarType scalarType() {
		return ScalarType.Float;
	}
}


struct VertexBuffer {
	typedef BufferHandle Handle;
	mixin MResource;
	mixin MBuffer;
}
