module xf.gfx.GPUEffect;

private {
	import xf.Common;
	import xf.gfx.VertexBuffer;
	import xf.utils.MultiArray;
}



struct UniformParam {}
struct VaryingParam {}


class GPUEffect {
	struct UniformDataSlice {
		size_t	offset;
		size_t	length;
	}
	
	struct UniformBuffer {
		mixin(multiArray(`params`, `
			UniformParam	param
			cstring				name
		`));
	}
	
	size_t	numVertexBuffers;
	size_t	totalUniformSize;

	/+pragma(msg, multiArray(`instances`, `
		VertexBuffer{numVertexBuffers}	vertexBuffers
		bool{numVertexBuffers}				vertexBuffersDirty
		void{totalUniformSize}					uniformData
	`));+/

	mixin(multiArray(`uniformParams`, `
		UniformParam		param
		cstring					name
		UniformDataSlice	dataSlice
	`));
	
	UniformBuffer[] uniformBuffers;	

	mixin(multiArray(`varyingParams`, `
		VaryingParam	param
		cstring				name
	`));

	mixin(multiArray(`instances`, `
		VertexBuffer{numVertexBuffers}	vertexBuffers
		bool{numVertexBuffers}				vertexBuffersDirty
		void{totalUniformSize}					uniformData
	`));
}
