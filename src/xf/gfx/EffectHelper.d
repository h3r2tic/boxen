module xf.gfx.EffectHelper;

private {
	import xf.gfx.Effect;
	import xf.mem.MainHeap;
	import tango.stdc.string : memset;
}



void allocateDefaultUniformStorage(Effect e) {
	return allocateDefaultUniformStorage(
		e.effectUniformParams(),
		e.getUniformPtrsDataPtr()
	);
}


void allocateDefaultUniformStorage(EffectInstance e) {
	return allocateDefaultUniformStorage(
		e.getUniformParamGroup(),
		e.getUniformPtrsDataPtr()
	);
}


private void allocateDefaultUniformStorage(
		RawUniformParamGroup* pg,
		void** ptrs
) {
	final num = pg.params.length;
	
	if (0 == num) {
		return;
	}

	size_t sizeNeeded =
		pg.params.dataSlice[num-1].offset +
		pg.params.dataSlice[num-1].length;
	sizeNeeded += 15;
	sizeNeeded &= ~cast(size_t)15;

	void* data = mainHeap.allocRaw(sizeNeeded);
	memset(data, 0, sizeNeeded);

	for (size_t i = 0; i < num; ++i) {
		ptrs[i] = data + pg.params.dataSlice[i].offset;
	}
}
