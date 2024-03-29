module xf.gfx.Effect;

private {
	import xf.Common;

	import
		xf.gfx.Defs,
		xf.gfx.Buffer,
		xf.gfx.VertexBuffer,
		xf.gfx.VertexArray,
		xf.gfx.Resource,
		xf.gfx.Texture;
	
	import xf.gfx.Log : log = gfxLog, error = gfxError;

	import
		xf.mem.MainHeap,
		xf.mem.MultiArray,
		xf.mem.FreeList;
}



typedef void*	UniformParam;
typedef void*	VaryingParam;
typedef word	UniformParamIndex = -1;

struct UniformDataSlice {
	size_t offset;
	size_t length;
}

struct VaryingParamData {
/+	VertexBuffer currentBuffer;
	VertexBuffer newBuffer;
	VertexAttrib currentAttrib;
	VertexAttrib newAttrib;+/
	VertexBuffer*	buffer;
	VertexAttrib*	attrib;
}


enum ParamBaseType : ushort {
	Float,
	Int
}


enum GeomProgramInput {
	Invalid,
	Point,
	Line,
	LineAdj,
	Triangle,
	TriangleAdj
}


enum GeomProgramOutput {
	Invalid,
	Point,
	Line,
	Triangle
}


struct EffectCompilationOptions {
	bool				useGeometryProgram = false;
	GeomProgramInput	geomProgramInput;
	GeomProgramOutput	geomProgramOutput;
	bool				useNVExtensions = false;
}




// name data allocated using osHeap
// names null-terminated at [$]  ( thus safe with both C and D )
const cstring uniformParamMix = `
	cstring				name
	UniformParam		param
	ushort				numFields
	ParamBaseType		baseType
	TypeInfo			typeInfo
	UniformDataSlice	dataSlice
`;


template MParamGroupUtils() {
	UniformParamIndex getUniformIndex(cstring name) {
		foreach (i, n; params.name[0..params.length]) {
			if (n == name) {
				return cast(UniformParamIndex)i;
			}
		}
		
		return -1;
	}


	bool isUniformStorageAllocated(void** ptrs) {
		uword num = params.length;
		while (num--) {
			if (null == *ptrs++) {
				return false;
			}
		}
		return true;
	}
}


struct RawUniformParamGroup {
	mixin(multiArray(`params`, uniformParamMix));
	mixin MParamGroupUtils;
}


struct UniformParamGroup {
	mixin(multiArray(`params`, uniformParamMix));
	
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
	
	size_t totalSize() {
		return _totalSize;
	}
	
	void overrideTotalSize(size_t s) {
		_totalSize = s;
	}

	mixin MParamGroupUtils;

	private {
		cstring	_name;
		size_t	_totalSize;
		bool	_dirty = true;
	}
}


template MUniformParamGroupInstance() {
	void** getUniformPtrPtr(UniformParamIndex i) {
		final up = getUniformParamGroup();

		if (-1 != i) {
			return getUniformPtrsDataPtr() + i;
		} else {
			return null;
		}
	}


	void** getUniformPtrPtr(cstring name) {
		final up = getUniformParamGroup();
		return getUniformPtrPtr(up.getUniformIndex(name));
	}
	
	
	bool setUniform(T)(UniformParamIndex i, T value) {
		final up = getUniformParamGroup();

		if (-1 != i) {
			if (typeid(T) !is up.params.typeInfo[i]) {
				error(
					"TypeInfo mismatch. Param type is {}, got {}.",
					up.params.typeInfo[i],
					typeid(T)
				);
			}
			
			*cast(T*)(
				getUniformPtrsDataPtr()[i]
			) = value;
			
			return true;
		} else {
			return false;
		}
	}


	bool setUniform(T)(cstring name, T value) {
		final up = getUniformParamGroup();
		final i = up.getUniformIndex(name);
		if (!setUniform!(T)(i, value)) {
			// TODO: say where :S
			log.error("No uniform named '{}'.", name);
			return false;
		} else {
			return true;
		}
	}
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

abstract class Effect {
	abstract void setArraySize(cstring name, size_t size);
	abstract void setUniformType(cstring name, cstring typeName);
	abstract Effect copy();
	abstract void compile();
	abstract void bind();
	abstract void unbind();
	abstract void bindUniformBuffer(int, Buffer);
	
	size_t	uniformPtrsDataSize;
	size_t	instanceDataSize;
	size_t	varyingParamsOffset;
	size_t	varyingParamsDirtyOffset;
	u32		renderOrdinal;

	struct SortingKey {
		u16	index;
		i16	offset;
	}
	
	// Each sorting key is a uword.
	// Allocated via mainHeap; TODO: free it somewhere
	SortingKey[] instanceSortingKeys;
	
	invariant {
		assert (uniformPtrsDataSize <= instanceDataSize);
	}
 	
	protected {
		void copyToNew(Effect ef) {
			assert (!_compiled);
			ef._useGeometryProgram = _useGeometryProgram;
			ef._domainProgramNames[] = _domainProgramNames;
			// TODO: any more?
		}
		
		
		void findInstanceSortingKeys() {
			final unif = &_uniformParams;
			final len = unif.length;
			
			uword numKeys = 0;			
			for (uword i = 0; i < len; ++i) {
				if (unif.typeInfo[i] is typeid(Texture)) {
					++numKeys;
				}
			}

			final keyData = mainHeap.allocRaw(SortingKey.sizeof * numKeys);
			
			instanceSortingKeys = (cast(SortingKey*)keyData)[0..numKeys];

			uword keyI = 0;
			for (uword i = 0; i < len; ++i) {
				if (unif.typeInfo[i] is typeid(Texture)) {
					assert (i <= u16.max);
					ptrdiff_t off = 
						//unif.dataSlice[i].offset +
						Texture.init._resHandle.offsetof +
						ResourceHandle.init.id.offsetof;
					assert (off >= i16.min && off <= i16.max);
					
					instanceSortingKeys[keyI] =
						SortingKey(
							cast(u16)i,
							cast(i16)off
						);
					++keyI;
				}
			}
			assert (numKeys == keyI);
			
			log.info("Effect has {} sorting keys.", numKeys);
		}
		

		char*[GPUDomain.Last+1] _domainProgramNames = [
			"VertexProgram".ptr,
			"GeometryProgram".ptr,
			"FragmentProgram".ptr
		];

		static assert (0 == GPUDomain.Vertex);
		static assert (1 == GPUDomain.Geometry);
		static assert (2 == GPUDomain.Fragment);
		static assert (2 == GPUDomain.Last);

		mixin(multiArray(`_uniformParams`, uniformParamMix));
		mixin(multiArray(`_effectUniformParams`, uniformParamMix));
		mixin(multiArray(`_objectInstanceUniformParams`, uniformParamMix));
	}

	final size_t totalInstanceSize() {
		return instanceDataSize + EffectInstanceImpl.sizeof;
	}
	
	// ----
	
	public void useGeometryProgram(bool b) {
		_useGeometryProgram = b;
	}
	
	public char* getDomainProgramName(GPUDomain d) {
		return _domainProgramNames[d];
	}
	
	public void setDomainProgramName(GPUDomain d, char* name) {
		_domainProgramNames[d] = name;
	}

	// ----
	
	final RawUniformParamGroup* uniformParams() {
		return cast(RawUniformParamGroup*)&_uniformParams;
	}
	
	final RawUniformParamGroup* effectUniformParams() {
		return cast(RawUniformParamGroup*)&_effectUniformParams;
	}

	/**
	 * TODO: Needs a better name.
	 * These are special per object-instance uniform params automatically set
	 * by the renderer, e.g. model<->world transformation matrices.
	 * 
	 * Note that there's a distinction between objects and object instances:
	 * objects might be rendered multiple times in a single frame, e.g. when
	 * using planar reflections. As such, it doesn't make sense to keep these
	 * parameters in the regular uniform group.
	 */
	final RawUniformParamGroup* objectInstanceUniformParams() {
		return cast(RawUniformParamGroup*)&_objectInstanceUniformParams;
	}

	// ---- uniform param group instance

	alias effectUniformParams getUniformParamGroup;

	void** uniformPtrsData;
	void** getUniformPtrsDataPtr() {
		return uniformPtrsData;
	}
	
	mixin MUniformParamGroupInstance;
	
	// ----

	UniformParamGroup[] uniformBuffers;

	// ----

	// name data allocated using osHeap
	// names null-terminated at [$]  ( thus safe with both C and D )
	mixin(multiArray(`varyingParams`, `
		cstring			name
		VaryingParam	param
	`));

	
	size_t getVaryingIndex(cstring name) {
		foreach (i, n; varyingParams.name[0..varyingParams.length]) {
			if (n == name) {
				return i;
			}
		}
		
		error("Varying named '{}' doesn't exist.", name);
		assert(false);
	}


	bool hasVaryingParam(cstring name, size_t* idx = null) {
		foreach (i, n; varyingParams.name[0..varyingParams.length]) {
			if (n == name) {
				if (idx) {
					*idx = i;
				}
				
				return true;
			}
		}
		return false;
	}


	bool isUniformStorageAllocated() {
		return effectUniformParams.isUniformStorageAllocated(uniformPtrsData);
	}
	
	
	public {
		// reserved for use in a Renderer
		u32	_idxInRenderer;
	}
	
	protected {
		bool _compiled = false;
		bool _useGeometryProgram = true;
	}
}


/* 
 * Allocated in bulks by the Effect. The total allocated size for one
 * instance is EffectInstanceImpl.sizeof + instanceDataSize, thus the uniform
 * data is right after the this pointer of the struct
 * 
 * Layout:
 * [0]									EffectInstanceImpl struct
 * [EffectInstanceImpl.sizeof]				uniforms ( raw data )
 * [_proto.varyingParamsOffset]			varyings ( VaryingParamData[] )
 *										pad to size_t.sizeof
 * [_proto.varyingParamsDirtyOffset]	varyings dirty flags ( size_t[] )
 */
struct EffectInstanceImpl {
	/**
	 * The effect from which this instance came to be
	 */
	Effect	_proto;
	
	/**
	 * A vertex array that caches all VBO bindings so they only need to
	 * be re-bound when they are actually reset by the user.
	 */
	VertexArray	_vertexArray;

	bool _varyingParamsDirty = true;
	
	
	// for the uniform param group instance ----
	
	RawUniformParamGroup* getUniformParamGroup() {
		return _proto.uniformParams();
	}

	void** getUniformPtrsDataPtr() {
		return cast(void**)(cast(void*)this + EffectInstanceImpl.sizeof);
	}

	bool isUniformStorageAllocated() {
		return _proto.uniformParams.isUniformStorageAllocated(getUniformPtrsDataPtr);
	}
	
	mixin MUniformParamGroupInstance;

	u32 renderOrdinal;

	// ----
	
	
	
	/+/// Returns true if the buffer could be acquired and was successfully set
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
	}+/
	
	
	VaryingParamData* getVaryingParamDataPtr() {
		return cast(VaryingParamData*)(
			cast(void*)this + EffectInstanceImpl.sizeof + _proto.varyingParamsOffset
		);
	}

	/+VaryingParamData* getVaryingParamData(int i) {
		return getVaryingParamDataPtr() + i;
	}
	
	size_t* getVaryingParamDirtyFlagsPtr() {
		return cast(size_t*)(
			cast(void*)this + EffectInstanceImpl.sizeof + _proto.varyingParamsDirtyOffset
		);
	}+/
}



typedef ResourceHandle EffectInstanceHandle;


struct EffectSource {
	enum Type {
		FilePath,
		String
	}
	
	static EffectSource filePath(cstring path) {
		return EffectSource(path, null, Type.FilePath);
	}
	
	static EffectSource string(cstring s) {
		return EffectSource(s, null, Type.String);
	}

	static EffectSource stringz(char* s) {
		return EffectSource(fromStringz(s), s, Type.String);
	}

	cstring dataString() {
		assert (_data !is null);
		return _data;
	}

	char* dataStringz() {
		if (_dataStringz is null) {
			_dataStringz = toStringz(_data);
		}
		return _dataStringz;
	}

	private	cstring _data;
	private	char*	_dataStringz;
	public	Type	_type;
}


interface IEffectMngr {
	Effect createEffect(cstring name, EffectSource source, EffectCompilationOptions opts = EffectCompilationOptions.init);
	EffectInstance instantiateEffect(Effect effect);
	void disposeEffect(Effect);
	Effect getEffect(EffectInstanceHandle);
	//bool setVarying(EffectInstanceHandle, cstring name, VertexBuffer buf, VertexAttrib vattr);
	void** getUniformPtrsDataPtr(EffectInstanceHandle);
	VaryingParamData* getVaryingParamDataPtr(EffectInstanceHandle);
	void setVaryingParamsDirty(EffectInstanceHandle);
	//size_t* getVaryingParamDirtyFlagsPtr(EffectInstanceHandle);
	u32 renderOrdinal(EffectInstanceHandle);
}


struct EffectInstance {
	alias EffectInstanceHandle Handle;
	mixin MResource;

	// for the uniform param group instance ----
	
	RawUniformParamGroup* getUniformParamGroup() {
		return getEffect().uniformParams();
	}

	void** getUniformPtrsDataPtr() {
		assert (_resHandle !is Handle.init);
		assert (_resMngr !is null);
		return (cast(IEffectMngr)_resMngr).getUniformPtrsDataPtr(_resHandle);
	}
	
	mixin MUniformParamGroupInstance;

	// ----
	
	Effect getEffect() {
		assert (_resHandle !is Handle.init, "Invalid EffectInstance");
		assert (_resMngr !is null);
		return (cast(IEffectMngr)_resMngr).getEffect(_resHandle);
	}
	
	/+bool setVarying(cstring name, VertexBuffer buf, VertexAttrib vattr) {
		assert (_resHandle !is Handle.init);
		assert (_resMngr !is null);
		return (cast(IEffectMngr)_resMngr).setVarying(_resHandle, name, buf, vattr);
	}+/

	// ----

	VaryingParamData* getVaryingParamDataPtr() {
		assert (_resHandle !is Handle.init);
		assert (_resMngr !is null);
		return (cast(IEffectMngr)_resMngr).getVaryingParamDataPtr(_resHandle);
	}

	VaryingParamData* getVaryingParamData(int i) {
		return getVaryingParamDataPtr() + i;
	}

	VaryingParamData* getVaryingParamData(cstring name) {
		final i = getEffect.getVaryingIndex(name);
		return getVaryingParamDataPtr() + i;
	}

	void setVaryingParamsDirty() {
		assert (_resHandle !is Handle.init);
		assert (_resMngr !is null);
		return (cast(IEffectMngr)_resMngr).setVaryingParamsDirty(_resHandle);
	}
	
	/+size_t* getVaryingParamDirtyFlagsPtr() {
		assert (_resHandle !is Handle.init);
		assert (_resMngr !is null);
		return (cast(IEffectMngr)_resMngr).getVaryingParamDirtyFlagsPtr(_resHandle);
	}+/
	
	u32 renderOrdinal() {
		assert (_resHandle !is Handle.init);
		assert (_resMngr !is null);
		return (cast(IEffectMngr)_resMngr).renderOrdinal(_resHandle);
	}
}
