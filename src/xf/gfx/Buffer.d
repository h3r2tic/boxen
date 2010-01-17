module xf.gfx.Buffer;

private {
	import xf.gfx.Resource;
}


typedef ResourceHandle BufferHandle;


enum BufferAccess {
	Read		= 0b1,
	Write		= 0b10,
	ReadWrite	= Read | Write,
	
	/**
		MAP_INVALIDATE_RANGE_BIT indicates that the previous contents of the
		speciﬁed range may be discarded. Data within this range are undeﬁned with
		the exception of subsequently written data. No GL error is generated if sub-
		sequent GL operations access unwritten data, but the result is undeﬁned and
		system errors (possibly including program termination) may occur. This ﬂag
		may not be used in combination with MAP_READ_BIT.
	*/	
	InvalidateRange	= 0b100,
	
	/**
		MAP_INVALIDATE_BUFFER_BIT indicates that the previous contents of the
		entire buffer may be discarded. Data within the entire buffer are undeﬁned
		with the exception of subsequently written data. No GL error is generated if
		subsequent GL operations access unwritten data, but the result is undeﬁned
		and system errors (possibly including program termination) may occur. This
		ﬂag may not be used in combination with MAP_READ_BIT.
	*/	
	InvalidateBuffer	= 0b1000,
	
	/**
		MAP_FLUSH_EXPLICIT_BIT indicates that one or more discrete subranges
		of the mapping may be modiﬁed. When this ﬂag is set, modiﬁcations to
		each subrange must be explicitly ﬂushed by calling FlushMappedBuffer-
		Range. No GL error is set if a subrange of the mapping is modiﬁed and
		not ﬂushed, but data within the corresponding subrange of the buffer are un-
		deﬁned. This ﬂag may only be used in conjunction with MAP_WRITE_BIT.
		When this option is selected, ﬂushing is strictly limited to regions that are
		explicitly indicated with calls to FlushMappedBufferRange prior to un-
		map; if this option is not selected UnmapBuffer will automatically ﬂush the
		entire mapped range when called.
	*/	
	FlushExplicit		= 0b10000,
	
	/**
		MAP_UNSYNCHRONIZED_BIT indicates that the GL should not attempt to
		synchronize pending operations on the buffer prior to returning from Map-
		BufferRange. No GL error is generated if pending operations which source
		or modify the buffer overlap the mapped region, but the result of such previ-
		ous and any subsequent operations is undeﬁned.
	*/
	Unsynchronized	= 0b100000
}


/**
	Allows hinting the vertex buffer manager about the pattern in which a buffer will be used. Performance will be greatly influenced by this
	choice, so make an *educated* guess.
*/
enum BufferUsage {
	/// The data store contents will be specified once by the application, and used at most a few times as the source of a GL (drawing) command.
	StreamDraw = 0,
	
	/// The data store contents will be specified once by reading data from the GL, and queried at most a few times by the application.
	StreamRead,
	
	/// The data store contents will be specified once by reading data from the GL, and used at most a few times as the source of a GL (drawing) command.
	StreamCopy,
	
	/// The data store contents will be specified once by the application, and used many times as the source for GL (drawing) commands.
	StaticDraw,
	
	/// The data store contents will be specified once by reading data from the GL, and queried many times by the application.
	StaticRead,
	
	/// The data store contents will be specified once by reading data from the GL, and used many times as the source for GL (drawing) commands.
	StaticCopy,
	
	/// The data store contents will be respecified repeatedly by the application, and used many times as the source for GL (drawing) commands.
	DynamicDraw,
	
	/// The data store contents will be respecified repeatedly by reading data from the GL, and queried many times by the application
	DynamicRead,
	
	/// The data store contents will be respecified repeatedly by reading data from the GL, and used many times as the source for GL (drawing) commands.
	DynamicCopy
}



interface IBufferMngr {
	void	mapRange(BufferHandle handle, size_t offset, size_t length, BufferAccess access, void delegate(void[]) dg);
	void	setData(BufferHandle handle, size_t length, void* data, BufferUsage usage);
	void	setSubData(BufferHandle handle, ptrdiff_t offset, size_t length, void* data);
	void	flushMappedRange(BufferHandle handle, size_t offset, size_t length);
	size_t	getApiHandle(BufferHandle handle);
	void	bind(BufferHandle handle);
}


template MBuffer() {
	void mapRange(size_t offset, size_t length, BufferAccess access, void delegate(void[]) dg) {
		assert (_resHandle !is Handle.init);
		assert (_resMngr !is null);
		return (cast(IBufferMngr)_resMngr).mapRange(_resHandle, offset, length, access, dg);
	}
	
	void setData(size_t length, void* data, BufferUsage usage) {
		assert (_resHandle !is Handle.init);
		assert (_resMngr !is null);
		return (cast(IBufferMngr)_resMngr).setData(_resHandle, length, data, usage);
	}
	
	void setSubData(ptrdiff_t offset, size_t length, void* data) {
		assert (_resHandle !is Handle.init);
		assert (_resMngr !is null);
		return (cast(IBufferMngr)_resMngr).setSubData(_resHandle, offset, length, data);
	}

	void flushMappedRange(size_t offset, size_t length) {
		assert (_resHandle !is Handle.init);
		assert (_resMngr !is null);
		return (cast(IBufferMngr)_resMngr).flushMappedRange(_resHandle, offset, length);
	}
	
	void bind() {
		assert (_resHandle !is Handle.init);
		assert (_resMngr !is null);
		return (cast(IBufferMngr)_resMngr).bind(_resHandle);
	}

	size_t getApiHandle() {
		assert (_resHandle !is Handle.init);
		assert (_resMngr !is null);
		return (cast(IBufferMngr)_resMngr).getApiHandle(_resHandle);
	}
	
	bool valid() {
		return _resHandle !is Handle.init;
	}
}


struct Buffer {
	alias BufferHandle Handle;
	mixin MResource;
	mixin MBuffer;
}
