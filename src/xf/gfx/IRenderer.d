module xf.gfx.IRenderer;

public {
	import
		xf.Common,
		
		xf.gfx.Window,
		xf.gfx.Buffer,
		xf.gfx.VertexArray,
		xf.gfx.VertexBuffer,
		xf.gfx.IndexBuffer,
		xf.gfx.UniformBuffer,
		xf.gfx.Texture,
		xf.gfx.Mesh,
		xf.gfx.Effect,
		xf.gfx.Framebuffer,
		xf.gfx.RenderList;
}


struct RendererStats {
	uword	numTextureChanges;
}



interface IRenderer :
	IBufferMngr,
	IVertexArrayMngr,
	IVertexBufferMngr,
	IIndexBufferMngr,
	IUniformBufferMngr,
	ITextureMngr,
	IMeshMngr,
	IEffectMngr,
	IFramebufferMngr
{
	Window	window();
	void	window(Window);
	void	initialize();
	void	swapBuffers();
	void	minimizeStateChanges();
	
	void	render(RenderList*);
	
	RenderList*	createRenderList();
	void		disposeRenderList(RenderList*);
	
	void			resetStats();
	RendererStats	getStats();
}
