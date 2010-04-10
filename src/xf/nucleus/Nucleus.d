module xf.nucleus.Nucleus;

private {
	import xf.Common;
	import xf.nucleus.Renderer;
	import xf.gfx.IRenderer : RendererBackend = IRenderer;
}



Renderer createRenderer(cstring name, RendererBackend back) {
	return _rendererFactories[name](back);
}


void registerRenderer(T)(cstring name) {
	_rendererFactories[name] = function Renderer(RendererBackend backend) {
		return new T(backend);
	};
}

// TODO: registration


private {
	Renderer function(RendererBackend)[cstring]	_rendererFactories;
}
