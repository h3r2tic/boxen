module xf.nucleus.renderer.ForwardRenderer;

private {
	import xf.Common;
	import xf.nucleus.Defs;
	import xf.nucleus.Renderable;
	import xf.nucleus.Renderer;
	import xf.nucleus.RenderList;
	import xf.nucleus.KernelParamInterface;
	import xf.nucleus.Log : log = nucleusLog, error = nucleusError;
	import Nucleus = xf.nucleus.Nucleus;
	import xf.gfx.Effect;
	import xf.gfx.IRenderer : RendererBackend = IRenderer;
	import xf.gfx.IndexData;
	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.CoordSys;
	import xf.omg.util.ViewSettings;
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

		void setUniform(cstring name, void* ptr) {
			uniforms[_meshEffect.effectUniformParams.getUniformIndex(name)]
				= ptr;
		}

		setUniform("worldToView", &worldToView);
		setUniform("viewToClip", &viewToClip);

		// TODO: other params
	}


	private void compileEffectsForRenderables(RenderableId[] rids) {
		foreach (idx, rid; rids) {
			if (!this._renderableValid.isSet(rid)) {
				// compile the kernels, create an EffectInstance

				final structureKernel = renderables.structureKernel[rid];

				// TODO
				/+if (structureKernel() is null) {
					error("Structure kernel is null for renderable {}.", rid);
				}+/

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
		xf.utils.Memory.realloc(_renderableEI, id+1);
		xf.utils.Memory.realloc(_renderableIndexData, id+1);
	}

	
	override void render(ViewSettings vs, RenderList* rlist) {
		this.viewToClip = vs.computeProjectionMatrix();
		this.worldToView = vs.computeViewMatrix();

		final rids = rlist.list.renderableId[0..rlist.list.length];
		compileEffectsForRenderables(rids);

		final blist = _backend.createRenderList();
		scope (exit) _backend.disposeRenderList(blist);

		foreach (idx, rid; rids) {
			final ei = _renderableEI[rid];
			final bin = blist.getBin(ei.getEffect);
			final item = bin.add(ei);
			
			item.coordSys		= rlist.list.coordSys[idx];
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
