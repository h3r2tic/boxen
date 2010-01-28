module xf.utils.RollingBuffer;

private {
	import xf.Common;
	import xf.utils.Error;
}



struct RollingBuffer {
	static RollingBuffer opCall(void[] data) {
		RollingBuffer res = void;
		res.length = 0;
		res.data = data;
		res.start = 0;
		res.end = 0;
		return res;
	}
	
	
	void[] opSlice(uword from, uword to) {
		assert (to >= from);
		from += start;
		to += start;
		assert (from < end);
		assert (to <= end);
		return data[from .. to];
	}
	

	u8 opIndex(uword idx) {
		idx += start;
		assert (idx < end);
		return (cast(u8*)data.ptr)[idx];
	}

	
	void[] append(int numMore) {
		if (numMore + end > data.length) {
			uword curLen = end - start;
			uword totalLen = curLen + numMore;
			if (totalLen > data.length) {
				utilsError(
					"Rolling buffer overflow. Capacity: {}, Allocated: {},"
					" trying to append {} more bytes.",
					data.length, curLen, numMore
				);
			}
			
			assert (start != 0);
			memmove(data.ptr, data.ptr + start, curLen);
			end -= start;
			start = 0;
		}

		void[] res = data[end .. end+numMore];
		end += numMore;
		length += numMore;		
		return res;
	}
	
	
	void truncateBy(int num) {
		assert (end >= num);
		end -= num;
		length -= num;
		assert (end >= start);
	}
	
	
	void append(void[] more) {
		append(more.length)[] = more;
	}
		
	
	void consume(uword num) {
		assert (num <= end - start);
		start += num;
		length -= num;
	}
	
	
	// Read only. Not a function so it's quick to access without inlining
	public {
		uword length = 0;
	}
		
	private {
		void[]	data;
		uword	start;
		uword	end;
	}
}
