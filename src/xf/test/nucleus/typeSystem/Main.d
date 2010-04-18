module Main;

private {
	import tango.core.tools.TraceExceptions;
	
	import xf.Common;
	import xf.mem.ChunkQueue;
	import xf.nucleus.TypeSystem;

	import tango.text.convert.Format;
	import tango.io.Stdout;
}



void main() {
	ScratchFIFO mem;
	mem.initialize();

	auto sem = Semantic((uword bytes) { return mem.pushBack(bytes); });
	sem.addTrait("foo", "bar");
	sem.addTrait("ham", "spam");

	for (int i = 0; i < 10; ++i) {
		sem.addTrait(Format("key{}", i), Format("value{}", i));
	}

	foreach (k, v; sem.iterTraits) {
		Stdout.formatln("k: '{}' v: '{}'", k, v);
	}

	Stdout.formatln("Used mem: {} B", mem.countUsedBytes);
}
