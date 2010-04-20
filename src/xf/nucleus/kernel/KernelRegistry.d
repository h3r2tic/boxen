module xf.nucleus.kernel.KernelRegistry;

private {
	import xf.nucleus.CommonDef : domainToString;
	import xf.nucleus.kernel.KernelDef;
	import tango.io.Stdout;
}



abstract class KernelRegistry {
	void printStatus() {
		foreach (q; &kernels) {
			Stdout.formatln("{} kernel {}:", domainToString(q.domain), q.name);
			Stdout.formatln("\tInherits:");
			foreach (i; q.getInheritList) {
				Stdout.formatln("\t\t{}", i);
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
	
	
	abstract KernelDef	opIndex(char[] name);
	abstract int			kernels(int delegate(ref KernelDef) dg);
}
