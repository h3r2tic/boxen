module xf.nucled.MaterialBrowser;

private {
	import
		xf.Common;
	import
		xf.nucleus.MaterialDef,
		xf.nucleus.kdef.Common,
		xf.nucleus.kdef.model.IKDefRegistry,
		xf.nucleus.kdef.model.KDefInvalidation,
		xf.nucleus.IStructureData,
		xf.nucleus.Param,
		xf.nucleus.KernelImpl,
		xf.gfx.IRenderer : RendererBackend = IRenderer;
	import
		xf.nucled.PreviewRenderer,
		xf.nucled.Widgets,
		xf.nucled.Misc,
		xf.nucled.Graph : Graph, GraphNode;
	import
		xf.hybrid.Hybrid,
		xf.hybrid.Common,
		xf.hybrid.CustomWidget;
	import
		xf.omg.core.LinearAlgebra,
		xf.omg.core.CoordSys,
		xf.omg.util.ViewSettings;
	import
		xf.mem.StackBuffer,
		xf.mem.ScratchAllocator;
}



class MaterialBrowser : IKDefInvalidationObserver {
	this (IKDefRegistry reg, RendererBackend backend) {
		_reg = reg;
		_backend = backend;
		reg.registerObserver(this);
	}


	// implements IKDefInvalidationObserver
	void onKDefInvalidated(KDefInvalidationInfo info) {
		if (info.anyConverters) {
			foreach (mname, miniature; _miniatures) {
				miniature.dispose();
				delete miniature;
			}

			_miniatures = null;
		}

		cstring[] invalid;

		foreach (mname, miniature; _miniatures) {
			if (!miniature._matDef.isValid) {
				invalid ~= mname;
			}
		}

		foreach (n; invalid) {
			MaterialMiniature mm = _miniatures[n];
			mm.dispose();
			delete mm;
			_miniatures.remove(n);
		}
	}


	void setObjectsForPreview(IStructureData[] obj) {
		_obj = obj;
	}


	void doGUI() {
		selected = null;
		
		padded(70) = {
			final wnd = MaterialBrowserWindow() [{
				uword mi = uword.max;
				foreach (cstring mname, MaterialDef mat; &_reg.materials) {
					++mi;

					final box = MaterialMiniatureBox(mi);
					box [{
						if (!(mname in _miniatures)) {
							_miniatures[mname] = new MaterialMiniature(
								_backend,
								_reg,
								mat,
								_obj
							);
						}

						_miniatures[mname].doGUI();

						Label()
							.fontSize(11)
							.halign(1)
							.text(mname)
							.layoutAttribs("hfill hexpand");
					}];
					
					if (box.clicked) {
						selected = mat;
					}
				}
			}];
			wnd.layoutAttribs = "vexpand vfill hexpand hfill";
		};
	}

	public {
		MaterialDef	selected;
	}

	private {
		IKDefRegistry 		_reg;
		IStructureData[]	_obj;
		RendererBackend		_backend;

		MaterialMiniature[cstring]	_miniatures;
	}
}


private class MaterialMiniature {
	void doGUI() {
		auto w = CustomDrawWidget();
		w.layoutAttribs = "hexpand hfill";
		w.renderingHandler = &this.draw;
		w.userSize(vec2(168, 120));
	}


	void draw(vec2i size) {
		_backend.framebuffer.settings.clearColorEnabled[0] = false;
		_backend.framebuffer.settings.clearDepthEnabled = true;
		_backend.clearBuffers();

		ViewSettings vs;
		vs.eyeCS = CoordSys(vec3fi[0.14, 1.7, 1.9], quat.xRotation(-30.f));
		vs.verticalFOV = 62.f;		// in Degrees; _not_ half of the FOV
		vs.aspectRatio = cast(float)size.x / size.y;
		vs.nearPlaneDistance = 0.1f;
		vs.farPlaneDistance = 100.0f;
		_renderer.render(vs);
	}


	this (
		RendererBackend backend,
		IKDefRegistry reg,
		MaterialDef mat,
		IStructureData[] obj
	) {
		_backend = backend;

		_matDef = mat;

		_renderer = new MaterialPreviewRenderer(
			backend,
			reg,
			null, null
		);
		
		_renderer.setObjects(obj);

		_renderer.materialToUse
			= reg.getKernel(mat.materialKernelName);
			
		assert (_renderer.materialToUse.isValid);

		_renderer.structureToUse = reg.getKernel("DefaultMeshStructure");
		_renderer.compileEffects();

		_renderer.materialParams = mat.params;
		_renderer.updateMaterialData();
		_renderer.materialParams = ParamList.init;
	}


	void dispose() {
		_renderer.dispose();
	}
	

	RendererBackend			_backend;
	MaterialPreviewRenderer _renderer;
	MaterialDef				_matDef;
}
