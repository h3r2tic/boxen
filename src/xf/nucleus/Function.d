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
	Code code;
	
	this (cstring name, cstring[] tags, Code code, void* delegate(uword) allocator) {
		super (name, tags, allocator);
		this.code = code;
	}
}
