module xf.gfx.Mesh;

private {
	import xf.gfx.GPUEffect;
}


struct Mesh {
	GPUEffectInstance*	effect;
	uint[]				indices;
	size_t				numInstances = 1;
}
