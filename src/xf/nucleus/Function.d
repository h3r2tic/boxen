module xf.nucleus.Function;

private {
	import xf.Common;
	import xf.nucleus.Code;
	import xf.nucleus.Param;
	import xf.nucleus.TypeSystem;
}



class AbstractFunction {
	cstring name;
	
	union {
		private void* delegate(uword) _allocator;
		ParamList		params;
	}

	private {
		cstring[] _tags;
	}

	cstring[] tags() {
		return _tags;
	}

	bool hasTag(cstring tag) {
		foreach (t; _tags) {
			if (t == tag) {
				return true;
			}
		}

		return false;
	}

	bool opEquals(AbstractFunction other) {
		if (cast(Function)other) {
			return false;
		} else {
			if (name != other.name) {
				return false;
			}
			
			// TODO: is it comparing string contents or ptrs?
			if (_tags != other._tags) {
				return false;
			}
			
			if (params != other.params) {
				return false;
			}

			return true;
		}
	}
	
	this (cstring name, cstring[] tags, void* delegate(uword) allocator) {
		_allocator = allocator;
		if (name.length > 0) {
			this.name = ((cast(char*)allocator(name.length))[0..name.length] = name);
		}
		if (tags.length > 0) {
			_tags = (cast(cstring*)allocator(tags.length * cstring.sizeof))[0..tags.length];
			foreach (i, ref dt; _tags) {
				final st = tags[i];
				assert (st.length > 0);
				dt = (cast(char*)allocator(st.length))[0..st.length];
				dt[] = st;
			}
		}
	}
}


class Function : AbstractFunction {
	Code	code;
	void*	kernelDef;		// KernelDef
	
	this (cstring name, cstring[] tags, Code code, void* delegate(uword) allocator) {
		super (name, tags, allocator);
		this.code = code;
	}

	override bool opEquals(AbstractFunction other_) {
		if (auto other = cast(Function)other_) {
			if (name != other.name) {
				return false;
			}
			
			// TODO: is it comparing string contents or ptrs?
			if (_tags != other._tags) {
				return false;
			}
			
			if (params != other.params) {
				return false;
			}

			if (code != other.code) {
				return false;
			}

			return true;
		} else {
			return false;
		}
	}
}
