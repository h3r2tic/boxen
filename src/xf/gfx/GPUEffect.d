module xf.gfx.GPUEffect;

private {
	import xf.Common;
	import xf.gfx.VertexBuffer;
	import xf.utils.MultiArray;
	import xf.utils.FreeList;
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
	
	
	void invalidate() {
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


enum GPUDomain {
	Vertex,
	Geometry,
	Fragment
}


cstring GPUDomainName(GPUDomain d) {
	switch (d) {
		case GPUDomain.Vertex:
			return "Vertex";
		case GPUDomain.Geometry:
			return "Geometry";
		case GPUDomain.Fragment:
			return "Fragment";
		default:
			assert (false);
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

abstract class GPUEffect {
	abstract void setArraySize(cstring name, size_t size);
	abstract void setUniformType(cstring name, cstring typeName);
	abstract GPUEffect copy();
	abstract void compile();

	
	size_t	numVertexBuffers;
	size_t	instanceDataSize;
	
	protected {
		bool _useGeometryProgram = true;
		char*[GPUDomain.max+1] _domainProgramNames = [
			"VertexProgram".ptr,
			"GeometryProgram".ptr,
			"FragmentProgram".ptr
		];

		static assert (0 == GPUDomain.Vertex);
		static assert (1 == GPUDomain.Geometry);
		static assert (2 == GPUDomain.Fragment);
		static assert (2 == GPUDomain.max);
	}
	
	public void useGeometryProgram(bool b) {
		_useGeometryProgram = b;
	}
	
	public void setDomainProgramName(GPUDomain d, char* name) {
		_domainProgramNames[d] = name;
	}

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
		bool{numVertexBuffers}			vertexBuffersDirty
		void{instanceDataSize}			uniformData
	`));
	
	
	UniformDataSlice getUniformDataSlice(cstring name) {
		foreach (i, n; uniformParams.name[0..uniformParams.length]) {
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
		auto inst = cast(GPUEffectInstance*)instanceFreeList.alloc(totalInstanceSize);
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
			cast(void*)this + _proto.getUniformDataSlice(name).offset
		) = value;
	}
	
	
	void dispose() {
		_proto.disposeInstance(this);
	}
}
