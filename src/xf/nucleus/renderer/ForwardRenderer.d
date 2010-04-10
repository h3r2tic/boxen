module xf.nucleus.renderer.ForwardRenderer;

private {
	import xf.nucleus.Defs;
	import xf.nucleus.Renderable;
	import xf.nucleus.Renderer;
	import xf.nucleus.RenderList;
	import Nucleus = xf.nucleus.Nucleus;
	import xf.gfx.Effect;
	import xf.gfx.IRenderer : RendererBackend = IRenderer;
}



class ForwardRenderer : Renderer {
	mixin MRenderer!("Foward");

	
	this (RendererBackend backend) {
		super(backend);

		EffectCompilationOptions opts;
		opts.useGeometryProgram = false;
		_meshEffect = _backend.createEffect(
			"meshEffect",
			EffectSource.filePath("meshEffect.cgfx"),
			opts
		);
		
		_meshEffect.compile();
		// TODO: other params
	}


	private void compileEffectsForRenderables(RenderableId[] rids) {
		foreach (idx, rid; rids) {
			if (!this._renderableValid.isSet(rid)) {
				// compile the kernels, create an EffectInstance

				final structureKernel = renderables.structureKernel[rid];
				assert (structureKernel !is null);

				EffectInstance efInst;
				
				// HACK
				switch (structureKernel.name) {
					case "DefaultMeshStructure": {
						efInst = _backend.instantiateEffect(_meshEffect);
					} break;

					default: assert (false, structureKernel.name);
				}

				// TODO: do something with the efInst :P

				_renderableEI[rid] = efInst;
				
				this._renderableValid.set(rid);
			}
		}
	}

	
	override void render(RenderList* rlist) {
		final rids = rlist.list.renderableId[0..rlist.list.length];
		compileEffectsForRenderables(rids);

		final blist = _backend.createRenderList();
		scope (exit) _backend.disposeRenderList(blist);

		foreach (idx, rid; rids) {
			/+final bin = blist.getBin(m.effectInstance.getEffect);
			m.toRenderableData(bin.add(m.effectInstance));+/
		}

		_backend.render(blist);
	}


	private {
		// HACK
		EffectInstance[]	_renderableEI;
		Effect				_meshEffect;
	}
}
