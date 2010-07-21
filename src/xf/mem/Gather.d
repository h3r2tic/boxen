module xf.mem.Gather;

private {
	import xf.mem.ScratchAllocator;
	import tango.core.Tuple;
}


private template TupleOfArrays(T ...) {
	static assert (T.length >= 1);
	
	static if (1 == T.length) {
		alias Tuple!(T[0][]) TupleOfArrays;
	} else {
		alias Tuple!(T[0][], TupleOfArrays!(T[1..$])) TupleOfArrays;
	}
}

private template LazyDg(T ...) {
	static if (1 == T.length) {
		alias void delegate(lazy T[0]) LazyDg;
	} 
	else static if (2 == T.length) {
		alias void delegate(lazy T[0], lazy T[1]) LazyDg;
	} 
	else static assert (false, "Add more.");
}


/** Sample usage:

	gatherArrays!(string, Value)(sc.mem,
	(void delegate(lazy string, lazy Value) gen) {
		foreach (stmt_; sc.statements) {
			if (auto stmt = cast(AssignStatement)stmt_) {
				gen(stmt.name, stmt.value);
			}
		}
	},
	(string[] names, Value[] values) {
		sc.doAssign(names, values);
	});
*/
template gatherArrays(T...) {
	bool gatherArrays(
		DgScratchAllocator alloc,
		void delegate(LazyDg!(T)) gen,
		void delegate(TupleOfArrays!(T)) sink
	) {
		size_t num = 0;
		gen((lazy T) { ++num; });

		if (num != 0) {
			TupleOfArrays!(T) res;
			foreach (ri, _poop; res) {
				res[ri] = alloc.allocArrayNoInit!(T[ri])(num);
			}
			
			size_t i = 0;
			gen((lazy T t) {
				foreach (xi, x; t) {
					res[xi][i] = x;
				}
				++i;
			});
			assert (num == i);

			sink(res);
			return true;
		} else {
			return false;
		}
	}
}
