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

	final allocator = (uword bytes) { return mem.pushBack(bytes); };

	{
		cstring[] added;

		auto sem = Semantic(allocator);
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

	{
		auto paramSem = Semantic(allocator);
		auto argSem1 = Semantic(allocator);
		auto argSem2 = Semantic(allocator);
		auto argSem3 = Semantic(allocator);
		auto argSem4 = Semantic(allocator);

		paramSem.addTrait("type", "float");
		paramSem.addTrait("unit", "true");
		
		argSem1.addTrait("type", "float");
		argSem1.addTrait("unit", "true");
		
		argSem2.addTrait("type", "float2");
		argSem1.addTrait("unit", "true");
		
		argSem3.addTrait("type", "float");

		argSem4.addTrait("type", "float");
		argSem4.addTrait("unit", "true");
		argSem4.addTrait("zomg", "noes");

		assert (canPassSemanticFor(argSem1, paramSem, true));
		assert (!canPassSemanticFor(argSem2, paramSem, true));
		assert (!canPassSemanticFor(argSem3, paramSem, true));
		assert (canPassSemanticFor(argSem4, paramSem, true));
	}

	{
		auto paramSem = Semantic(allocator);
		auto argSem1 = Semantic(allocator);
		auto argSem2 = Semantic(allocator);
		auto argSem3 = Semantic(allocator);
		auto argSem4 = Semantic(allocator);

		paramSem.addTrait("type", "float []");
		argSem1.addTrait("type", "float[]");
		argSem2.addTrait("type", "float  [ ]");
		argSem3.addTrait("type", "float[][]");
		argSem4.addTrait("type", "float");

		assert (canPassSemanticFor(argSem1, paramSem, true));
		assert (canPassSemanticFor(argSem2, paramSem, true));
		assert (!canPassSemanticFor(argSem3, paramSem, true));
		assert (!canPassSemanticFor(argSem4, paramSem, true));
	}

	Stdout.formatln("Test passed!");
}
