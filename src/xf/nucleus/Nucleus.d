module xf.nucleus.Nucleus;

private {
	import xf.Common;
	import xf.nucleus.Renderer;
	import xf.nucleus.kdef.model.IKDefRegistry;
	import xf.gfx.IRenderer : RendererBackend = IRenderer;
}



Renderer createRenderer(cstring name, RendererBackend back, IKDefRegistry reg) {
	return _rendererFactories[name](back, reg);
}


void registerRenderer(T)(cstring name) {
	_rendererFactories[name] = function Renderer(
			RendererBackend backend,
			IKDefRegistry registry
	) {
		return new T(backend, registry);
	};
}

// TODO: registration


private {
	Renderer function(RendererBackend, IKDefRegistry)[cstring]	_rendererFactories;
}
