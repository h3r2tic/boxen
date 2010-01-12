module xf.gfx.GPUEffect;

private {
	import xf.Common;
	import xf.gfx.VertexBuffer;
	import xf.utils.MultiArray;
}



struct UniformParam { size_t id; }
struct VaryingParam { size_t id; }

struct UniformDataSlice {
	size_t	offset;
	size_t	length;
}


struct UniformParamGroup {
	mixin(multiArray(`params`, `
		cstring				name
		UniformParam		param
		UniformDataSlice	dataSlice
	`));
	
	
	bool invalidate() {
		_dirty = true;
	}
	
	void validate() {
		_dirty = false;
	}
	
	cstring name() {
		return _name;
	}
	
	void overrideName(cstring n) {
		_name = n;
	}
	

	private {
		cstring	_name;
		bool	_dirty = true;
	}
}

/*
 * Q: Where do we store varying inputs finally?
 * A: In the instance. Rationale follows:
 * 
 * Storing in the instance itself means that updating them is quite cheap
 * since the data to be overwritten is right in the instance and only one
 * indirection away. Later, when rendering, all the data for an instance
 * will be available in this very block as well, making data upload to the
 * driver cheap. On the other hand, keeping a struct of arrays for the
 * varyings means that they are cheaper to process in blocks, e.g. to iter
 * through all renderables and update their varyings in bulks. Not sure whether
 * that is so positive though, as it would mean that the driver has to do the
 * VaO binding twice - once for the updates, once for rendering. In the previous
 * approach with an 'array of structs', there would be just one pass and one
 * VaO binding. This should in theory make the rendering faster.
 */


class GPUEffect {
	size_t	numVertexBuffers;
	size_t	instanceDataSize;

	mixin(multiArray(`uniformParams`, `
		cstring				name
		UniformParam		param
		UniformDataSlice	dataSlice
	`));
	
	UniformParamGroup[] uniformBuffers;

	mixin(multiArray(`varyingParams`, `
		cstring			name
		VaryingParam	param
	`));

	mixin(multiArray(`instances`, `
		VertexBuffer{numVertexBuffers}	curVertexBuffers
		VertexBuffer{numVertexBuffers}	nextVertexBuffers
		boolnumVertexBuffers}			vertexBuffersDirty
		void{instanceDataSize}			uniformData
	`));
	
	
	UniformDataSlice getUniformDataSlice(cstring name) {
		foreach (i, n; uniformParams.name) {
			if (n == name) {
				return uniformParams.dataSlice[i];
			}
		}
		
		throw new Exception("shit hit the fan (TODO: better error lul)");
	}
	
	final size_t totalInstanceSize() {
		return instanceDataSize + GPUEffectInstance.sizeof;
	}
	
	GPUEffectInstance* instantiate() {
		GPUEffectInstance* inst = instanceFreeList.alloc(totalInstanceSize);
		*inst = GPUEffectInstance.init;
		void* unifData = cast(void*)(inst+1);
		memset(unifData, 0, instanceDataSize);
		return inst;
	}
	
	
	void disposeInstance(GPUEffectInstance* inst) {
		instanceFreeList.free(inst);
	}
	
	
	UntypedFreeList instanceFreeList;
}


/* 
 * Allocated in bulks by the GPUEffect. The total allocated size for one
 * instance is GPUEffectInstance.sizeof + instanceDataSize, thus the uniform
 * data is right after the this pointer of the struct
 */
struct GPUEffectInstance {
	GPUEffect	_proto;
	
	void setUniform(T)(cstring name, T value) {
		*cast(T*)(
			cast(void*)this + _proto.getUniformDataSlice(name).offset;
		) = value;
	}
	
	
	void dispose() {
		_proto.disposeInstance(this);
	}
}
