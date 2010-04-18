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

	cstring[] added;

	auto sem = Semantic((uword bytes) { return mem.pushBack(bytes); });
	sem.addTrait("zark", "barf");
	added ~= "zark";
	sem.addTrait("zomg", "lul");
	added ~= "zomg";
	sem.addTrait("foo", "bar");
	added ~= "foo";
	sem.addTrait("ham", "spam");
	added ~= "ham";
	sem.addTrait("arr", "spam");
	added ~= "arr";

	for (int i = 0; i < 10; ++i) {
		sem.addTrait(Format("key{}", 5-i), Format("value{}", i));
		added ~= Format("key{}", 5-i);
	}

	foreach (a; added) {
		assert (sem.hasTrait(a), a);
	}

	sem.removeTrait("key0");
	sem.removeTrait("ham");

	foreach (k, v; sem.iterTraits) {
		Stdout.formatln("k: '{}' v: '{}'", k, v);
	}

	Stdout.formatln("Used mem: {} B", mem.countUsedBytes);
}
