module xf.nucleus.quark.QuarkRegistry;

/+private {
	import xf.nucleus.quark.QuarkDef;
	import tango.io.Stdout;
}



abstract class QuarkRegistry {
	void printStatus() {
		foreach (q; &quarks) {
			Stdout.formatln("quark {}:", q.name);
			Stdout.formatln("\tImplements:");
			foreach (i; q.implList) {
				Stdout.formatln("\t\t{} @ {}", i.name, i.score);
			}
			Stdout.formatln("\tFunctions:");
			foreach (f; q.functions) {
				Stdout.formatln("\t\t{}:", f.name);
				foreach (p; f.params) {
					Stdout.formatln("\t\t\t{} {} {} : {}", ["in", "out", "inout"][p.direction], p.type, p.name, p.semantic);
				}
			}
		}
	}
	

	abstract QuarkDef	opIndex(char[] name);
	abstract int		quarks(int delegate(ref QuarkDef) dg);
	
	alias quarks opApply;
	
	
	/+void clear() {
		_quarks = null;
	}
	

	protected {
		QuarkDef[]	_quarks;
	}+/
}
+/
