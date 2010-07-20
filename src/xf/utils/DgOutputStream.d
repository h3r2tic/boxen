module xf.utils.DgOutputStream;

private {
	import tango.io.model.IConduit;
}



final class DgOutputStream : OutputStream {
	private {
		void delegate(void[]) dg;
	}
	
	
	this(void delegate(void[]) dg) {
		this.dg = dg;
	}


	// OutputStream

	size_t write (void[] src) {
		dg(src);
		return src.length;
	}
	
	OutputStream copy (InputStream src, size_t max = -1) {
		assert (false, "Not implemented");
	}

	OutputStream output () {
		return this;
	}


	// IOStream

	long seek (long offset, Anchor anchor = Anchor.Begin) {
		assert (false, "Not implemented");
	}

	IConduit conduit () {
		assert (false, "Not implemented");
	}

	IOStream flush () {
		// nothing
		return this;
	}
	
	void close () {
		// nothing
	}
}
