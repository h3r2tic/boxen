module xf.utils.MultiArray;

private {
	import xf.Common;
	import xf.utils.CT;
}



pragma(ctfe) private void splitTypeNameCT(cstring line, out cstring type, out cstring name) {
	int i = 0;
	for (; i < line.length; ++i) {
		if (' ' == line[i] || '\t' == line[i]) break;
	}
	type = line[0..i];
	name = striplCT(line[i..$]);
}


private struct MultiArrayField {
	cstring	type;
	cstring	name;
	cstring	chunkSizeVar;
	bool		isChunk;
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
		cstring					name
		UniformDataSlice	dataSlice
	`));
	---
	
	Generated public methods:
	
	void resize(size_t)
	size_t growBy(size_t)	- returns the index of the first newly added item
	size_t length()
	... TODO ...
*/
pragma(ctfe) cstring multiArray(cstring name, cstring def) {
	return multiArray(name, 256, def);
}


/// ditto
pragma(ctfe) cstring multiArray(cstring name, int _growBy, cstring def) {
	assert (_growBy > 1);
	
	auto fields = parseMultiArrayFields(def);
	cstring growBy = intToStringCT(_growBy);
	cstring res;
	res ~= `private static import xf.mem.OSHeap;`;
	res ~= `static if (!is(_ma__OuterRef)) alias typeof(this) _ma__OuterRef;`;
	res ~= `static struct _ma_` ~ name ~ `{`;
		res ~= `_ma__OuterRef _this() { return cast(_ma__OuterRef)(cast(void*)this - _ma__OuterRef.init.` ~ name ~ `.offsetof); }`;
		foreach (field; fields) {
			if (field.isChunk) {
				res ~= field.type ~ `* ` ~ field.name ~ ` = null;`\n;
				res ~= `size_t ` ~ field.name ~ `_chunkSize_() { auto _thisOuter = _this(); return `~field.chunkSizeVar~`; }`\n;
			} else {
				res ~= field.type ~ `* ` ~ field.name ~ ` = null;`\n;
			}
		}
		res ~= `
		void resize(size_t newLen) {
			_capacity = _length = newLen;
			_allocCapacity();
		}
		
		size_t growBy(size_t num) {
			size_t result = _length;
			_length += num;
			if (_length <= _capacity) {
				return result;
			} else {
				_capacity = _length + `~growBy~` - 1;
				_capacity -= _capacity % `~growBy~`;
				_allocCapacity();
				return result;
			}
		}
		
		size_t length() {
			return _length;
		}
		
		private {
			void _allocCapacity() {
				assert (_capacity > 0, "multiArray._allocCapacity :: _capacity must be > 0");
				alias xf.mem.OSHeap.osHeap _heap;
				auto _thisOuter = _this();
				`;
				foreach (field; fields) {
					res ~= `assert (`~field.chunkSizeVar~` > 0, "multiArray._allocCapacity :: `~field.chunkSizeVar~` must be > 0");`;
					res ~= field.name~` = cast(`~field.type~`*)_heap.reallocRaw(`~field.name~`, _capacity * (`~field.type~`).sizeof * `~field.chunkSizeVar~`);`\n;
				}
				res ~=
			`}
			
			size_t	_length;
			size_t	_capacity;
		}
		`;
	res ~= `} _ma_` ~ name ~ ` ` ~ name ~ `;`;
	return res;
}
