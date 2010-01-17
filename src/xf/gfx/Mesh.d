module xf.gfx.Mesh;

private {
	import xf.gfx.GPUEffect;
}


struct Mesh {
	GPUEffectInstance*	effect;
	uint[]				indices;
}
