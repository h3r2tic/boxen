module xf.gfx.VertexArray;

private {
	import xf.gfx.Resource;
	import xf.gfx.VertexBuffer;
}


typedef ResourceHandle VertexArrayHandle;


interface IVertexArrayMngr {
	void bind(VertexArrayHandle handle);
}


struct VertexArray {
	alias VertexArrayHandle Handle;
	mixin MResource;
	
	void bind() {
		assert (_resHandle !is Handle.init);
		assert (_resMngr !is null);
		return (cast(IVertexArrayMngr)_resMngr).bind(_resHandle);
	}
}
