module xf.gfx.gl3.Renderer;

public {
	import xf.gfx.Buffer;
	import xf.gfx.VertexArray;
	import xf.gfx.VertexBuffer;
}

private {
	import xf.Common;
	
	import xf.gfx.Log : log = gfxLog, error = gfxError;
	import xf.gfx.gl3.CgEffect;
	import xf.gfx.gl3.Cg;
	
	import xf.gfx.api.gl3.OpenGL;
	import xf.gfx.api.gl3.ext.ARB_map_buffer_range;
}



private struct BufferData {
	GLenum	target;
	GLuint	handle;
	size_t	refCount;
}


class Renderer : IBufferMngr {
	this(GL gl) {
		_cgCompiler = new CgCompiler;
		this.gl[] = gl;
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
	
	
	BufferData* _getBuffer(BufferHandle h) {
		assert (false, "TODO");
	}
	
	
	BufferData* _createBuffer(GLenum target) {
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

	
	VertexArray createVertexArray() {
		error("TODO: createVertexArray");
		return VertexArray.init;
	}
	
	
	VertexBuffer createVertexBuffer() {
		final buf = _createBuffer(ARRAY_BUFFER);
		/+return VertexBuffer(
			blah blah blah
		);+/
		assert (false, "TODO");
	}
	
	
	GL				gl;
	CgCompiler		_cgCompiler;	
	BufferData[]	_buffers;
}
