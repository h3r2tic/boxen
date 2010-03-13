module xf.net.BudgetWriter;

private {
	import xf.utils.BitStream;
}



struct BudgetWriter {
	BitStreamWriter	bsw;

	// In bits.
	size_t	budget;
	size_t	budgetInc;
	size_t	budgetMax = size_t.max;



	bool canWriteMore() {
		return cast(size_t)bsw.writeOffset < budget;
	}


	void reset() {
		budget = 0;
		bsw.reset();
	}


	void flush(void delegate(ubyte[]) sink) {
		bsw.flush();
		final bytes = bsw.asBytes();
		sink(bytes);
		budget -= bytes.length * 8;
		budget += budgetInc;
		if (budget > budgetMax) {
			budget = budgetMax;
		}
		bsw.reset();
	}
}
