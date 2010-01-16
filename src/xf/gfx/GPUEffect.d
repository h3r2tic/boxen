module xf.gfx.GPUEffect;

private {
	import xf.Common;

	import xf.gfx.VertexBuffer;
	import xf.gfx.VertexArray;
	
	import xf.gfx.Log : log = gfxLog, error = gfxError;

	import xf.utils.MultiArray;
	import xf.utils.FreeList;
}



typedef void* UniformParam;
typedef void* VaryingParam;

struct UniformDataSlice {
	size_t offset;
	size_t length;
}

struct VaryingParamData {
	VertexBuffer currentBuffer;
	VertexBuffer newBuffer;
	VertexAttrib currentAttrib;
	VertexAttrib newAttrib;
}


enum ParamBaseType : ushort {
	Float,
	Int
}


struct UniformParamGroup {
	// name data allocated using osHeap
	// names null-terminated at [$]  ( thus safe with both C and D )
	mixin(multiArray(`params`, `
		cstring				name
		UniformParam		param
		ushort				numFields
		ParamBaseType		baseType
		TypeInfo			typeInfo
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
	abstract void bind();
	
	size_t	instanceDataSize;
	size_t	varyingParamsOffset;
	size_t	varyingParamsDirtyOffset;
 	
	protected {
		bool _compiled = false;

		void copyToNew(GPUEffect ef) {
			assert (!_compiled);
			ef._useGeometryProgram = _useGeometryProgram;
			ef._domainProgramNames[] = _domainProgramNames;
			// TODO: any more?
		}
		

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
	
	public char* getDomainProgramName(GPUDomain d) {
		return _domainProgramNames[d];
	}
	
	public void setDomainProgramName(GPUDomain d, char* name) {
		_domainProgramNames[d] = name;
	}

	// name data allocated using osHeap
	// names null-terminated at [$]  ( thus safe with both C and D )
	mixin(multiArray(`uniformParams`, `
		cstring				name
		UniformParam		param
		ushort				numFields
		ParamBaseType		baseType
		TypeInfo			typeInfo
		UniformDataSlice	dataSlice
	`));
	
	UniformParamGroup[] uniformBuffers;

	// name data allocated using osHeap
	// names null-terminated at [$]  ( thus safe with both C and D )
	mixin(multiArray(`varyingParams`, `
		cstring			name
		VaryingParam	param
	`));

	
	size_t getUniformIndex(cstring name) {
		foreach (i, n; uniformParams.name[0..uniformParams.length]) {
			if (n == name) {
				return i;
			}
		}
		
		error("Uniform named '{}' doesn't exist.", name);
		assert(false);
	}
	
	size_t getVaryingIndex(cstring name) {
		foreach (i, n; varyingParams.name[0..varyingParams.length]) {
			if (n == name) {
				return i;
			}
		}
		
		error("Varying named '{}' doesn't exist.", name);
		assert(false);
	}

	final size_t totalInstanceSize() {
		return instanceDataSize + GPUEffectInstance.sizeof;
	}
	
	GPUEffectInstance* createRawInstance() {
		auto inst = cast(GPUEffectInstance*)instanceFreeList.alloc();
		*inst = GPUEffectInstance.init;
		void* unifData = cast(void*)(inst+1);
		memset(unifData, 0, instanceDataSize);
		inst._proto = this;
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
 * 
 * Layout:
 * [0]									GPUEffectInstance struct
 * [GPUEffectInstance.sizeof]			uniforms ( raw data )
 * [_proto.varyingParamsOffset]			varyings ( VaryingParamData[] )
 *										pad to size_t.sizeof
 * [_proto.varyingParamsDirtyOffset]	varyings dirty flags ( size_t[] )
 */
struct GPUEffectInstance {
	GPUEffect	_proto;
	VertexArray	_vertexArray;
	
	void setUniform(T)(cstring name, T value) {
		final i = _proto.getUniformIndex(name);
		final up = &_proto.uniformParams;
		
		if (typeid(T) !is up.typeInfo[i]) {
			error(
				"TypeInfo mismatch. Param type is {}, got {}.",
				up.typeInfo[i],
				typeid(T)
			);
		}
		
		*cast(T*)(
			getUniformsDataPtr() + up.dataSlice[i].offset
		) = value;
	}
	
	
	/// Returns true if the buffer could be acquired and was successfully set
	bool setVarying(cstring name, VertexBuffer buf, VertexAttrib vattr) {
		final i = _proto.getVaryingIndex(name);
		final vp = &_proto.varyingParams;
		
		final data = getVaryingParamData(i);
		
		// mark the buffer as dirty
		auto flags = getVaryingParamDirtyFlagsPtr();
		flags += i / (size_t.sizeof * 8);

		auto curFlag = *flags;
		
		final thisFlag = cast(size_t)1 << (i % (size_t.sizeof * 8));
		
		// whether the specific varying param is already set to be
		// replaced with a new vertex buffer
		final bool thisAlreadySet = (curFlag & thisFlag) != 0;
		
		// the currently set buffer is the same as what we're trying to reset it to
		if (data.currentBuffer.GUID is buf.GUID
			&& data.currentAttrib == vattr
		) {
			// some buffer has already been set for this varying before rendering
			// thus we will have to release it and clear the flag
			if (thisAlreadySet) {
				curFlag -= thisFlag;
				if (data.newBuffer.valid) {
					data.newBuffer.dispose();
				}
			} else {
				// we tried setting the varying to what it's already set to
				// and didn't try changing it to anything else before that
				// thus it's already acquired and there's nothing to do
				return true;
			}
		} else {
			// the currently set buffer is something else than the param
			
			// ... but we already told the effect instance to use it
			if (data.newBuffer.GUID is buf.GUID
				&& data.newAttrib == vattr) {
				if (thisAlreadySet) {
					// looks like a redudant call
					return true;
				} else {
					// this may happen if we set the buffer to something new
					// then reset it to what it was originally before calling
					// any rendering functions which would flush the flags.
					// That operation has released the buffer, so we need to
					// acquire it once again
					
					if (buf.acquire()) {
						// the buffer is already set to be replaced with our
						// current func param. We only need to update the flag
						curFlag |= thisFlag;
					} else {
						return false;
					}
				}
			} else {
				// an entirely new buffer different from the 'current' and
				// 'new' ones, thus we dispose the 'new' if it's valid, acquire
				// the parameter's buffer, put int into 'new' and set the flag
				
				if (buf.acquire()) {
					if (data.newBuffer.valid) {
						data.newBuffer.dispose();
					}
					
					data.newBuffer = buf;
					data.newAttrib = vattr;
					curFlag |= thisFlag;
				} else {
					return false;
				}
			}
		}
		
		// write back the flag
		*flags = curFlag;
		return true;
	}
	
	
	void* getUniformsDataPtr() {
		return cast(void*)this + GPUEffectInstance.sizeof;
	}
	
	
	VaryingParamData* getVaryingParamDataPtr() {
		return cast(VaryingParamData*)(
			cast(void*)this + GPUEffectInstance.sizeof + _proto.varyingParamsOffset
		);
	}
	
	
	VaryingParamData* getVaryingParamData(int i) {
		return getVaryingParamDataPtr() + i;
	}
	
	
	size_t* getVaryingParamDirtyFlagsPtr() {
		return cast(size_t*)(
			cast(void*)this + GPUEffectInstance.sizeof + _proto.varyingParamsDirtyOffset
		);
	}
	
	
	void dispose() {
		_proto.disposeInstance(this);
	}
}
