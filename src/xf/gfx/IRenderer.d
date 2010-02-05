module xf.gfx.IRenderer;

private {
	import
		xf.gfx.Buffer,
		xf.gfx.VertexArray,
		xf.gfx.VertexBuffer,
		xf.gfx.IndexBuffer,
		xf.gfx.UniformBuffer,
		xf.gfx.Texture,
		xf.gfx.Mesh,
		xf.gfx.GPUEffect;
}



interface IRenderer :
	IBufferMngr,
	IVertexArrayMngr,
	IVertexBufferMngr,
	IIndexBufferMngr,
	IUniformBufferMngr,
	ITextureMngr,
	IMeshMngr,
	IEffectMngr
{}
