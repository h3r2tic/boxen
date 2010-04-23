module xf.utils.IntrusiveHash;

private {
	import xf.Common;
	import xf.utils.Error : error = utilsError;
}



template MIntrusiveHash(ValueType = void) {
	public {
		typeof(this)	_intrusiveHashNext;
		hash_t			_intrusiveHashKey;

		static if (!is(ValueType == void)) {
			ValueType	_intrusiveHashValue;
		}
	}
}


uword goodHashSize(uword base) {
	const uword[] sizes = [
		53,
		97,
		193,
		389,
		769,
		1543,
		3079,
		6151,
		12289,
		24593,
		49157,
		98317,
		196613,
		393241,
		786433,
		1572869,
		3145739,
		6291469,
		12582917,
		25165843,
		50331653,
		100663319,
		201326611,
		402653189,
		805306457,
		1610612741
	];

	foreach (s; sizes) {
		if (base <= s) {
			return s;
		}
	}

	assert (false);
}


private hash_t _calcHash(T)(ref T t) {
	static if (is(typeof(T.toHash))) {
		return t.toHash();
	} else {
		return typeid(T).getHash(&t);
	}
}


struct IntrusiveHashMap(K, V) {
	static if (is(K == class)) {
		alias K KPtr;
	} else {
		alias K* KPtr;
	}

	static assert (is(typeof(K._intrusiveHashNext) == KPtr));
	static assert (is(typeof(K._intrusiveHashKey) == hash_t));
	static assert (typeof(K._intrusiveHashValue).sizeof == V.sizeof);

	KPtr[]	_buckets;


	static IntrusiveHashMap opCall(KPtr[] data) {
		IntrusiveHashMap res;
		res._buckets = data;
		res._buckets[] = null;
		return res;
	}


	void dispose() {
		foreach (ref b; _buckets) {
			KPtr list = void, next = b;
			while (next) {
				list = next;
				next = list._intrusiveHashNext;
				list._intrusiveHashNext = null;
			}
		}

		_buckets[] = null;
	}


	void opIndexAssign(V v, KPtr k) {
		if (k._intrusiveHashNext !is null) {
			error(
				"Either adding the same item to an IntrusiveHashMap again"
				", the previous IntrusiveHashMap has not been .dispose()d"
				" or the {} struct/class instance used as key contains garbage.",
				K.stringof
			);
		}
		
		hash_t hashKey = _calcHash(*k);
		k._intrusiveHashKey = hashKey;
		uword bucket = hashKey % _buckets.length;
		k._intrusiveHashNext = _buckets[bucket];
		*cast(V*)&k._intrusiveHashValue = v;
		_buckets[bucket] = k;
	}


	V* opIn_r(KPtr k) {
		hash_t hashKey = _calcHash(*k);
		uword bucket = hashKey % _buckets.length;
		for (auto list = _buckets[bucket]; list; list = list._intrusiveHashNext) {
			if (list._intrusiveHashKey is hashKey && *list == *k) {
				return cast(V*)&list._intrusiveHashValue;
			}
		}
		return null;
	}
}
