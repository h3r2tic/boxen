module xf.nucleus.renderer.ForwardRenderer;

private {
	import xf.Common;
	import xf.nucleus.Defs;
	import xf.nucleus.Renderable;
	import xf.nucleus.Renderer;
	import xf.nucleus.RenderList;
	import xf.nucleus.KernelParamInterface;
	import Nucleus = xf.nucleus.Nucleus;
	import xf.gfx.Effect;
	import xf.gfx.IRenderer : RendererBackend = IRenderer;
	import xf.gfx.IndexData;
	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.CoordSys;
	import tango.stdc.stdio : sprintf;

	// TMP
	static import xf.utils.Memory;
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

		void** uniforms = _meshEffect.getUniformPtrsDataPtr();
		
		uniforms[_meshEffect.effectUniformParams.getUniformIndex("worldToView")]
			= &worldToView;
		uniforms[_meshEffect.effectUniformParams.getUniformIndex("viewToClip")]
			= &viewToClip;

		worldToView = mat4.translation(vec3(0, 0, -10));

		viewToClip = mat4.perspective(
			65.0f,		// fov
			1.33333f,//cast(float)window.width / window.height,	// aspect
			0.1f,		// near
			100.0f		// far
		);

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

				renderables.structureData[rid].setKernelObjectData(
					KernelParamInterface(
					
						// getVaryingParam
						(cstring name) {
							char[256] fqn;
							sprintf(fqn.ptr, "VertexProgram.input.%.*s", name);

							size_t paramIdx = void;
							if (efInst.getEffect.hasVaryingParam(
									fromStringz(fqn.ptr),
									&paramIdx
							)) {
								return efInst.getVaryingParamDataPtr() + paramIdx;
							} else {
								return cast(VaryingParamData*)null;
							}
						},

						// setIndexData
						(IndexData* id) {
							_renderableIndexData[rid] = id;
						}
				));				

				_renderableEI[rid] = efInst;
				
				this._renderableValid.set(rid);
			}
		}
	}


	override void onRenderableCreated(RenderableId id) {
		super.onRenderableCreated(id);
		xf.utils.Memory.alloc(_renderableEI, id+1);
		xf.utils.Memory.alloc(_renderableIndexData, id+1);
	}

	
	override void render(RenderList* rlist) {
		final rids = rlist.list.renderableId[0..rlist.list.length];
		compileEffectsForRenderables(rids);

		final blist = _backend.createRenderList();
		scope (exit) _backend.disposeRenderList(blist);

		foreach (idx, rid; rids) {
			final ei = _renderableEI[rid];
			final bin = blist.getBin(ei.getEffect);
			final item = bin.add(ei);
			
			item.coordSys		= rlist.list.coordSys[idx]; //CoordSys.identity;
			item.scale			= vec3.one;
			item.indexData		= *_renderableIndexData[rid];
			item.numInstances	= 1;
		}

		_backend.render(blist);
	}


	private {
		// HACK
		EffectInstance[]	_renderableEI;
		IndexData*[]		_renderableIndexData;
		Effect				_meshEffect;

		mat4	worldToView;
		mat4	viewToClip;
	}
}
