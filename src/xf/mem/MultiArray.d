module xf.mem.MultiArray;

private {
	import xf.Common;
	import xf.utils.CT;
}



private pragma(ctfe) void splitTypeNameCT(cstring line, out cstring type, out cstring name) {
	int i = 0;
	for (; i < line.length; ++i) {
		if (' ' == line[i] || '\t' == line[i]) break;
	}
	type = line[0..i];
	name = striplCT(line[i..$]);

	// remove any //-style comments on the right of the name
	for (i = 0; i+1 < name.length; ++i) {
		if ('/' == name[i] && '/' == name[i+1]) {
			name = striprCT(name[0..i]);
		}
	}
}


private pragma(ctfe) struct MultiArrayField {
	cstring	type;
	cstring	name;
	cstring	chunkSizeVar;
	bool	isChunk;
}


private pragma(ctfe) MultiArrayField[] parseMultiArrayFields(cstring def) {
	cstring[] lines = splitLinesCT(def);
	MultiArrayField[] res;
	
	foreach (line; lines) {
		line = stripCT(line);
		if (line.length > 0) {
			cstring type, name;
			splitTypeNameCT(line, type, name);
			
			if (type[$-1] == '}') {
				int i = locateCT(type, '{');
				assert (i < type.length, "Expected to find a '{' in the string. Got: " ~ type);
				res ~= MultiArrayField(type[0..i], name, "_thisOuter."~type[i+1..$-1], true);
			} else {
				res ~= MultiArrayField(type, name, "1", false);
			}
		}
	}
	
	return res;
}


/**
	A helper for managing multiple arrays with the same length to ease the transition from the
	'array of structs' model to 'struct of arrays'. In addition to supporting simple fields, the items
	of the sub-arrays may be 'chunked'. This is similar to using static arrays as items, but allows
	the size to be determined at runtime. Declaring the type as 'Foo{bar}' means that the allocated
	item should be an array (chunk) of 'Foo' instances in the quantity of 'bar'.
	
	Usage:
	---
	mixin(multiArray(`uniformParams`, `
		UniformParam		param
		cstring				name
		UniformDataSlice	dataSlice
	`));
	---
	
	Generated public methods:

	void reserve(size_t num)
	void resize(size_t)
	size_t growBy(size_t)	- returns the index of the first newly added item
	size_t length()
	... TODO ...
*/

/// ditto
pragma(ctfe) cstring multiArray(
			cstring name,
			cstring def,
			cstring ExpandPolicy = `ArrayExpandPolicy.FixedAmount!(256)`,
			cstring Allocator = `ArrayAllocator.MainHeap`
) {
	auto fields = parseMultiArrayFields(def);

	cstring outerType = `_ma_`~name~`_OuterRef`;
	cstring wrapperType = `_ma_` ~ name;

	// Can't do it in the inner scope or DMD asplodes :/
	cstring res = `private import xf.mem.ArrayAllocator;`;

	// Store the outer type
	res ~= `static if (is(typeof(this))) alias typeof(this) `~outerType~`;`;

	// Create a wrapper struct for the multi-array.
	// Its name is largely irrelevant here, the struct will be accessed via its instance.
	res ~= `static struct ` ~ wrapperType ~ `{`;
	res ~= `const _ma_outerValid = is(`~outerType~`);`;
	res ~= `static if (_ma_outerValid) { alias `~outerType~` _ma_outerType; }`;

	// Fuck you, DMD
	res ~= `alias ` ~ ExpandPolicy ~ ` _ExpandPolicy; mixin _ExpandPolicy;`;

	// The allocator specified as a param must be mixed into a scope. So we create one.
	res ~= `struct _SubAllocator {
		static if (_ma_outerValid) {
			_ma_outerType _outer() {
				return cast(_ma_outerType)(
					cast(void*)this
					- _ma_outerType.init.` ~ name ~ `.offsetof
					- _ma_outerType.`~wrapperType~`.init._subAllocator.offsetof
				);
			}
		}
		mixin `~Allocator~`;
	}
	_SubAllocator _subAllocator;`;

	// Create a getter for the outer pointer. It's calculated by
	// subtracting the .offsetof of the wrapper struct instance from the thisptr.
	res ~= `
	static if (_ma_outerValid) {
		_ma_outerType _ma_outer() {
			return cast(_ma_outerType)(
				cast(void*)this
				- _ma_outerType.init.` ~ name ~ `.offsetof
			);
		}
	}`;

	// For each field in the multi-array, create a `type* name = null;` pointer.
	foreach (field; fields) {
		if (field.isChunk) {
			res ~= field.type ~ `* ` ~ field.name ~ ` = null;`\n;

			// Chunks also need a method to determine the variable size.
			res ~= `size_t ` ~ field.name ~ `_chunkSize_() {
				static if (_ma_outerValid) {
					final _thisOuter = _ma_outer();
					return `~field.chunkSizeVar~`;
				} else {
					return `~field.chunkSizeVar["_thisOuter.".length..$]~`;
				}
			}`\n;
		} else {
			res ~= field.type ~ `* ` ~ field.name ~ ` = null;`\n;
			res ~= `enum { ` ~ field.name ~ `_chunkSize_ = 1 }`\n;
		}
	}

	res ~= `
	void _reallocate() {
			assert (_capacity > 0, "multiArray._allocCapacity :: _capacity must be > 0");`;
			
			foreach (field; fields) {
				res ~= `{
				assert (`~field.name~`_chunkSize_`~` > 0, "multiArray._reallocate :: `~field.chunkSizeVar~` must be > 0");
				const _ma_itemSize = (`~field.type~`).sizeof * `~field.name~`_chunkSize_;
				`~field.name~` = cast(`~field.type~`*)
					_subAllocator._reallocate(
						`~field.name~`,
						0,
						_length * _ma_itemSize,
						_capacity * _ma_itemSize
					);
				}`;
			}
			res ~= `
	}

	void reserve(size_t num) {
		if (num > _capacity) {
			this._expand(num - _capacity);
			_reallocate();
		}
	}	
	
	void resize(size_t num) {
		if (num > 0) {
			reserve(num);
			/+if (num > _length) {
				initElements(_length, num);
			}+/
		}
		
		_length = num;
	}

	size_t growBy(size_t num) {
		size_t result = _length;
		_length += num;
		if (_length <= _capacity) {
			return result;
		} else {
			_expand(_length - _capacity);
			_reallocate();
			return result;
		}
	}
	
	size_t length() {
		return _length;
	}
	
	private {
		size_t	_length;
		size_t	_capacity;
	}
	`;

	// Finally, create the struct instance with the proper name
	res ~= `} _ma_` ~ name ~ ` ` ~ name ~ `;`;
	
	return res;
}
