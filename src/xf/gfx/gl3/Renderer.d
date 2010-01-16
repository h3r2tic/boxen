module xf.gfx.gl3.Renderer;

public {
	import xf.gfx.VertexArray;
	import xf.gfx.VertexBuffer;
}

private {
	import xf.Common;
	
	import xf.gfx.Log : log = gfxLog, error = gfxError;
	import xf.gfx.gl3.CgEffect;
	import xf.gfx.gl3.Cg;
}



class Renderer {
	this() {
		_cgCompiler = new CgCompiler;
	}
	
	
	GPUEffect createEffect(cstring name, EffectSource source) {
		return _cgCompiler.createEffect(name, source);
	}
	
	
	GPUEffectInstance* instantiateEffect(GPUEffect effect) {
		final inst = effect.createRawInstance();
		inst._vertexArray = createVertexArray();
		return inst;
	}
	
	
	VertexArray createVertexArray() {
		error("TODO: createVertexArray");
		return VertexArray.init;
	}
	
	
	VertexBuffer createVertexBuffer() {
		error("TODO: createVertexBuffer");
		return VertexBuffer.init;
	}
	
	
	CgCompiler	_cgCompiler;
}
