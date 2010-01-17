module xf.gfx.gl3.Renderer;

public {
	import xf.gfx.Buffer;
	import xf.gfx.VertexArray;
	import xf.gfx.VertexBuffer;
}

private {
	import
		xf.Common,

		xf.gfx.gl3.CgEffect,
		xf.gfx.gl3.Cg,
	
		xf.gfx.Resource,
		xf.gfx.Buffer,

		xf.gfx.api.gl3.OpenGL,
		xf.gfx.api.gl3.ext.ARB_map_buffer_range,
		xf.gfx.api.gl3.ext.ARB_vertex_array_object,

		xf.mem.FreeList,
		xf.mem.Array,
		
		xf.utils.ResourcePool;

	import
		xf.gfx.Log : log = gfxLog, error = gfxError;
}



class Renderer : IBufferMngr, IVertexArrayMngr {
	// at the front because otherwise DMD is a bitch about forward refs
	private {
		GL			gl;
		CgCompiler	_cgCompiler;
		
		ThreadUnsafeResourcePool!(BufferImpl, BufferHandle)
			_buffers;
			
		ThreadUnsafeResourcePool!(VertexArrayImpl, VertexArrayHandle)
			_vertexArrays;
	}


	this(GL gl) {
		_cgCompiler = new CgCompiler;
		this.gl[] = gl;
		
		_buffers.initialize();
		_vertexArrays.initialize();
	}
	
	
	GPUEffect createEffect(cstring name, EffectSource source) {
		return _cgCompiler.createEffect(name, source);
	}
	
	
	GPUEffectInstance* instantiateEffect(GPUEffect effect) {
		final inst = effect.createRawInstance();
		inst._vertexArray = createVertexArray();
		return inst;
	}
	
	
	private void _bindBuffer(GLenum target, GLuint handle) {
		assert (false, "TODO");
	}
	
	
	BufferImpl* _getBuffer(BufferHandle h) {
		assert (false, "TODO");
	}
	
	
	// implements IBufferMngr
	void mapRange(
		BufferHandle handle,
		size_t offset,
		size_t length,
		BufferAccess access,
		void delegate(void[]) dg
	) {
		final buf = _getBuffer(handle);		
		_bindBuffer(buf.target, buf.handle);
		
		final ptr = gl.MapBufferRange(
			buf.target,
			offset,
			length,
			enumToGL(access)
		);
		
		scope (exit) {
			gl.UnmapBuffer(buf.target);
		}
		
		dg(ptr[0..length]);
	}
	
	
	private static GLenum enumToGL(BufferAccess) {
		assert (false, "TODO");
	}


	// implements IBufferMngr
	void flushMappedRange(BufferHandle handle, size_t offset, size_t length) {
		final buf = _getBuffer(handle);
		_bindBuffer(buf.target, buf.handle);

		gl.FlushMappedBufferRange(
			buf.target,
			offset,
			length
		);
	}


	// implements IBufferMngr
	size_t getApiHandle(BufferHandle handle) {
		final buf = _getBuffer(handle);
		return buf.handle;
	}
	
	
	// implements IVertexArrayMngr
	void bind(VertexArrayHandle h) {
		if (auto resData = _vertexArrays.find(h)) {
			gl.BindVertexArray(resData.res.handle);
		}
	}
	
	
	// Vertex Array ----
	
	private {
		VertexArray toResourceHandle(_vertexArrays.ResourceReturn resource) {
			VertexArray res = void;
			res._resHandle = resource.handle;

			res._resMngr = cast(void*)cast(IVertexArrayMngr)this;
			res._refMngr = cast(void*)this;
			final rcnt = &resCountVertexArray;
			res._resCountAdjust = rcnt.funcptr;

			return res;
		}
		
		
		bool resCountVertexArray(VertexArrayHandle h, int cnt) {
			if (auto resData = _vertexArrays.find(h, cnt > 0)) {
				final res = resData.res;
				bool goodBefore = res.refCount > 0;
				res.refCount += cnt;
				if (res.refCount > 0) {
					return true;
				} else if (goodBefore) {
					_vertexArrays.free(resData);
				}
			}
			
			return false;
		}
	}


	VertexArray createVertexArray() {
		return toResourceHandle(
			_vertexArrays.alloc((VertexArrayImpl* n) {
				n.refCount = 1;
				gl.GenVertexArrays(1, &n.handle);
			})
		);
	}
	
	// ---- VertexBuffer

	private {
		Buffer toResourceHandle(_buffers.ResourceReturn resource) {
			Buffer res = void;
			res._resHandle = resource.handle;
			
			res._resMngr = cast(void*)cast(IBufferMngr)this;
			res._refMngr = cast(void*)this;
			final rcnt = &resCountBuffer;
			res._resCountAdjust = rcnt.funcptr;
			
			return res;
		}
		
		
		bool resCountBuffer(BufferHandle h, int cnt) {
			if (auto resData = _buffers.find(h, cnt > 0)) {
				final res = resData.res;
				bool goodBefore = res.refCount > 0;
				res.refCount += cnt;
				if (res.refCount > 0) {
					return true;
				} else if (goodBefore) {
					_buffers.free(resData);
				}
			}
			
			return false;
		}
	}

	VertexBuffer createVertexBuffer() {
		final buf = toResourceHandle(
			_buffers.alloc((BufferImpl* n) {
				n.refCount = 1;
				gl.GenBuffers(1, &n.handle);
				n.target = ARRAY_BUFFER;
			})
		);
		return *cast(VertexBuffer*)&buf;
	}
}



private struct BufferImpl {
	ptrdiff_t	refCount;
	GLuint		handle;
	GLenum		target;
}


private struct VertexArrayImpl {
	ptrdiff_t	refCount;
	GLuint		handle;
}
