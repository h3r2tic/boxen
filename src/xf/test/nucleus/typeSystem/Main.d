module Main;

private {
	import tango.core.tools.TraceExceptions;
	
	import xf.Common;
	import xf.mem.ChunkQueue;
	import xf.mem.StackBuffer;
	import xf.nucleus.Code;
	import xf.nucleus.TypeSystem;
	import xf.nucleus.Param;
	import xf.nucleus.Function;
	import xf.nucleus.TypeConversion;

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
		mem.clear();
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
		mem.clear();
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
		mem.clear();
	}

	{
		SemanticConverter[] conv;
		{
			final f = new Function("normalize", null, Code.init, allocator);

			with (*f.params.add(ParamDirection.In, "input")) {
				hasPlainSemantic = true;
			}
			with (*f.params.add(ParamDirection.Out, "output")) {
				hasPlainSemantic = false;
				semanticExp.addTrait("in.input.actual", null, SemanticExp.TraitOp.Add);
				semanticExp.addTrait("unit", "true", SemanticExp.TraitOp.Add);
			}
			conv ~= SemanticConverter(
				f,
				1
			);
		}

		{
			final f = new Function("local2world", null, Code.init, allocator);

			with (*f.params.add(ParamDirection.In, "input")) {
				hasPlainSemantic = true;
				semantic.addTrait("basis", "local");
			}
			with (*f.params.add(ParamDirection.Out, "output")) {
				hasPlainSemantic = false;
				semanticExp.addTrait("in.input.actual", null, SemanticExp.TraitOp.Add);
				semanticExp.addTrait("basis", "world", SemanticExp.TraitOp.Add);
			}
			conv ~= SemanticConverter(
				f,
				1
			);
		}

		{
			final f = new Function("world2clip", null, Code.init, allocator);

			with (*f.params.add(ParamDirection.In, "input")) {
				hasPlainSemantic = true;
				semantic.addTrait("basis", "world");
			}
			with (*f.params.add(ParamDirection.Out, "output")) {
				hasPlainSemantic = false;
				semanticExp.addTrait("in.input.actual", null, SemanticExp.TraitOp.Add);
				semanticExp.addTrait("basis", "clip", SemanticExp.TraitOp.Add);
				semanticExp.addTrait("unit", null, SemanticExp.TraitOp.Remove);
			}
			conv ~= SemanticConverter(
				f,
				1
			);
		}

		int semanticConverters(int delegate(ref SemanticConverter) sink) {
			foreach (ref c; conv) {
				if (int r = sink(c)) {
					return r;
				}
			}
			return 0;
		}

		void convPrint(ConvSinkItem[] convChain) {
			foreach (ref c; convChain) {
				Stdout.formatln(
					"findConversion: use {} -> <{}>",
					c.converter.func.name,
					c.afterConversion.toString
				);
			}
		}

		// Test some basics
		// * whether traits are preserved via the use of in.*.actual
		// * whether trait value modification works
		// * whether trait addition works
		{
			auto sem1 = Semantic(allocator);
			auto sem2 = Semantic(allocator);

			sem1.addTrait("type", "float");
			sem2.addTrait("type", "float");

			sem1.addTrait("basis", "local");
			sem2.addTrait("basis", "world");

			sem2.addTrait("unit", "true");

			Stdout.formatln("\nFinding a conversion <{}> -> <{}>", sem1, sem2);

			assert (findConversion(
				sem1,
				sem2,
				&semanticConverters,
				&convPrint
			));
		}

		// Test two modifications of the same trait in a row
		{
			auto sem1 = Semantic(allocator);
			auto sem2 = Semantic(allocator);

			sem1.addTrait("basis", "local");
			sem2.addTrait("basis", "clip");

			Stdout.formatln("\nFinding a conversion <{}> -> <{}>", sem1, sem2);

			assert (findConversion(
				sem1,
				sem2,
				&semanticConverters,
				&convPrint
			));
		}

		// Test that the reverse conversion is not possible
		{
			auto sem1 = Semantic(allocator);
			auto sem2 = Semantic(allocator);

			sem1.addTrait("basis", "clip");
			sem2.addTrait("basis", "local");

			Stdout.formatln("\nFinding a conversion <{}> -> <{}>", sem1, sem2);

			assert (!findConversion(
				sem1,
				sem2,
				&semanticConverters,
				&convPrint
			));

			Stdout.formatln("Not found. Good!");
		}

		// Verify that a trait will properly be removed by a SemanticExp`s Remove Op
		{
			auto sem1 = Semantic(allocator);
			auto sem2 = Semantic(allocator);

			sem1.addTrait("basis", "local");
			sem1.addTrait("unit", "true");
			sem2.addTrait("basis", "clip");

			Stdout.formatln("\nFinding a conversion <{}> -> <{}>", sem1, sem2);

			assert (findConversion(
				sem1,
				sem2,
				&semanticConverters,
				&convPrint
			));
		}

		// Test the removal of a trait and its subsequent addition via a converter
		{
			auto sem1 = Semantic(allocator);
			auto sem2 = Semantic(allocator);

			sem1.addTrait("basis", "local");
			sem1.addTrait("unit", "true");
			sem2.addTrait("basis", "clip");
			sem2.addTrait("unit", "true");

			Stdout.formatln("\nFinding a conversion <{}> -> <{}>", sem1, sem2);

			assert (findConversion(
				sem1,
				sem2,
				&semanticConverters,
				&convPrint
			));
		}
		
		mem.clear();
	}

	assert (0 == StackBuffer.bytesUsed);

	Stdout.formatln("Test passed!");
}
