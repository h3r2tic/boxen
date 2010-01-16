module xf.gfx.Buffer;

private {
	import xf.gfx.Resource;
}


typedef ResourceHandle BufferHandle;


enum BufferAccess {
	Read			= 0b1,
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


interface IBufferMngr {
	void	mapRange(BufferHandle handle, size_t offset, size_t length, BufferAccess access, void delegate(void[]) dg);
	void	flushMappedRange(BufferHandle handle, size_t offset, size_t length);
	size_t	getApiHandle();
}


template MBuffer() {
	// This is important so the zeroed instances reference null buffers by default
	static assert (0 == Handle.init);
	
	void mapRange(size_t offset, size_t length, BufferAccess access, void delegate(void[]) dg) {
		assert (_resHandle != Handle.init);
		assert (_resMngr !is null);
		return (cast(IBufferMngr)_resMngr).mapRange(_resHandle, offset, length, access, dg);
	}
	
	void flushMappedRange(size_t offset, size_t length) {
		assert (_resHandle != Handle.init);
		assert (_resMngr !is null);
		return (cast(IBufferMngr)_resMngr).flushMappedRange(_resHandle, offset, length);
	}

	size_t getApiHandle() {
		assert (_resHandle != Handle.init);
		assert (_resMngr !is null);
		return (cast(IVertexBufferMngr)_resMngr).getApiHandle();
	}
	
	bool valid() {
		return _resHandle != Handle.init;
	}
}
