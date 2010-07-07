module Main;

private {
	import tango.core.tools.TraceExceptions;
	
	import xf.Common;

	import xf.nucleus.kdef.Common;
	import xf.nucleus.kdef.KDefFileParser;
	import xf.nucleus.kdef.KDefProcessor;
	import xf.nucleus.KernelImpl;

	import xf.nucleus.graph.KernelGraph;
	import xf.nucleus.kdef.KDefGraphBuilder;

	import tango.text.convert.Format;
	import tango.io.Stdout;
	import tango.io.device.File;
	import Path = tango.io.Path;

	import tango.io.vfs.FileFolder;
}



void main() {
	{
		final vfs = new FileFolder(".");

		final fparser = new KDefFileParser;
		fparser.setVFS(vfs);

		final processor1 = new KDefProcessor(fparser);
		final processor2 = new KDefProcessor(fparser);
		final processor3 = new KDefProcessor(fparser);

		Path.copy("sample1.kdef", "sample_tmp.kdef");

		processor1.processFile("sample_tmp.kdef");
		processor1.doSemantics();

		processor2.processFile("sample_tmp.kdef");
		processor2.doSemantics();

		Path.copy("sample2.kdef", "sample_tmp.kdef");

		processor3.processFile("sample_tmp.kdef");
		processor3.doSemantics();

		Path.remove("sample_tmp.kdef");

		foreach (kname, impl1; processor1.kernels) {
			auto impl2 = processor2.getKernel(kname);

			if (impl1.impl != impl2) {
				Stdout.formatln(
					"Onoz, kernel {} differs between processor1 and processor2.",
					kname
				);
				assert (false);
			} else {
				Stdout.formatln(
					"Yay, kernel {} is the same in processor1 and processor2.",
					kname
				);
			}
		}

		Stdout.newline;

		foreach (kname, impl2; processor2.kernels) {
			auto impl3 = processor3.getKernel(kname);

			if (impl2.impl != impl3) {
				Stdout.formatln(
					"kernel {} DIFFERS between processor2 and processor3.",
					kname
				);
			} else {
				Stdout.formatln(
					"kernel {} is the same in processor2 and processor3.",
					kname
				);
			}
		}

		Stdout.newline;

		auto invRes = processor1.invalidateDifferences(processor3);

		foreach (name, o; processor1.kernels) {
			if (!o.impl.isValid) {
				Stdout.formatln("Kernel {} is invalidated.", name);
			}
		}
		foreach (name, o; &processor1.materials) {
			if (!o.isValid) {
				Stdout.formatln("Material {} is invalidated.", name);
			}
		}
		foreach (name, o; &processor1.surfaces) {
			if (!o.isValid) {
				Stdout.formatln("Surface {} is invalidated.", name);
			}
		}

		if (invRes.anyConverters) {
			Stdout.formatln("Converters were modified.");
		}
	}

	Stdout.formatln("Test passed!");
}
