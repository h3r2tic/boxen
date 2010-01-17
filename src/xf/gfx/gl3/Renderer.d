module xf.gfx.gl3.Renderer;

public {
	import xf.gfx.Buffer;
	import xf.gfx.VertexArray;
	import xf.gfx.VertexBuffer;
}

private {
	import xf.Common;
	import xf.gfx.Log : log = gfxLog, error = gfxError;
	
	import
		xf.gfx.gl3.CgEffect,
		xf.gfx.gl3.Cg;
	
	import
		xf.gfx.Resource,
		xf.gfx.Buffer;

	import
		xf.gfx.api.gl3.OpenGL,
		xf.gfx.api.gl3.ext.ARB_map_buffer_range,
		xf.gfx.api.gl3.ext.ARB_vertex_array_object;
	
	import xf.utils.UidPool;
	import xf.mem.FreeList;
	import xf.mem.Array;
}



class Renderer : IBufferMngr {
	// at the front because otherwise DMD is a bitch about forward refs
	private {
		GL			gl;
		CgCompiler	_cgCompiler;
		
		ResourcePool!(BufferImpl, BufferHandle)
			_buffers;
			
		ResourcePool!(VertexArrayImpl, VertexArrayHandle)
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
	
	
	BufferImpl* _createBuffer(GLenum target) {
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
	
	
	private {
		VertexArray toResourceHandle(_vertexArrays.ResourceReturn resource) {
			VertexArray res = void;
			res._resHandle = resource.handle;
			res._resMngr = cast(void*)this;
			
			final acq = &acquireVertexArray;
			res._acquire = acq.funcptr;
			
			final dsp = &disposeVertexArray;
			res._dispose = dsp.funcptr;
			return res;
		}
		
		
		bool acquireVertexArray(VertexArrayHandle h) {
			if (auto res = _vertexArrays.find(h)) {
				++res.refCount;
				return true;
			} else {
				return false;
			}
		}
		
		
		void disposeVertexArray(VertexArrayHandle h) {
			if (auto res = _vertexArrays.find(h)) {
				--res.refCount;
				if (res.refCount <= 0) {
					error("TODO: free the resource");
				}
			}
		}
	}

	
	VertexArray createVertexArray() {
		return toResourceHandle(
			_vertexArrays.alloc((VertexArrayImpl* n) {
				gl.GenVertexArrays(1, &n.handle);
				n.refCount = 1;
			})
		);
	}
	
	
	VertexBuffer createVertexBuffer() {
		final buf = _createBuffer(ARRAY_BUFFER);
		/+return VertexBuffer(
			blah blah blah
		);+/
		assert (false, "TODO");
	}
}



private struct BufferImpl {
	GLenum		target;
	GLuint		handle;
	ptrdiff_t	refCount;
}


private struct VertexArrayImpl {
	GLuint		handle;
	ptrdiff_t	refCount;
}


struct ResourcePool(T, Handle) {
	static assert (Handle.sizeof <= size_t.sizeof);
	
	Array!(
		T*,
		ArrayExpandPolicy.FixedAmount!(1024)
	)					_uidMap;
	UidPool!(size_t)	_uidPool;
	FreeList!(T)		_resources;
	
	
	struct ResourceReturn {
		T*		resource;
		Handle	handle;
	}
	
	
	// darn, i want struct ctors :F
	void initialize() {
		_resources.initialize();
	}
	
	
	ResourceReturn alloc(void delegate(T*) resGen) out (res) {
		assert (res.handle != 0);
	} body {
		final uid = _uidPool.alloc();
		if (uid < _uidMap.length) {
			return ResourceReturn(
				_uidMap.ptr[uid],
				cast(Handle)(uid+1)
			);
		} else {
			assert (uid == _uidMap.length);
			final res = _resources.alloc();
			resGen(res);
			_uidMap.pushBack(res);
			return ResourceReturn(res, cast(Handle)(uid+1));
		}
	}
	
	
	T* find(Handle h) {
		if (0 == h) {
			return null;
		} else {
			final idx = cast(size_t)h-1;
			if (idx < _uidMap.length) {
				return _uidMap.ptr[idx];
			} else {
				return null;
			}			
		}
	}
}
