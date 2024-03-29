module xf.nucled.SurfaceBrowser;

private {
	import
		xf.Common;
	import
		xf.nucleus.SurfaceDef,
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



class SurfaceBrowser : IKDefInvalidationObserver {
	this (IKDefRegistry reg, RendererBackend backend) {
		_reg = reg;
		_backend = backend;
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
			// TODO
			/+if (!miniature.surfDef.isValid) {
				invalid ~= mname;
			}+/
		}

		foreach (n; invalid) {
			SurfaceMiniature mm = _miniatures[n];
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
				uword si = uword.max;
				foreach (cstring sname, SurfaceDef surf; &_reg.surfaces) {
					++si;

					final box = MaterialMiniatureBox(si);
					box [{
						if (!(sname in _miniatures)) {
							_miniatures[sname] = new SurfaceMiniature(
								_backend,
								_reg,
								surf,
								_obj
							);
						}

						_miniatures[sname].doGUI();

						Label()
							.fontSize(11)
							.halign(1)
							.text(sname)
							.layoutAttribs("hfill hexpand");
					}];
					
					if (box.clicked) {
						selected = surf;
					}
				}
			}];
			wnd.layoutAttribs = "vexpand vfill hexpand hfill";
		};
	}

	public {
		SurfaceDef	selected;
	}

	private {
		IKDefRegistry 		_reg;
		IStructureData[]	_obj;
		RendererBackend		_backend;

		SurfaceMiniature[cstring]	_miniatures;
	}
}


class SurfaceMiniature {
	void doGUI() {
		auto w = CustomDrawWidget();
		w.layoutAttribs = "hexpand hfill";
		w.renderingHandler = &this.draw;
		w.userSize(vec2(168, 120));
	}


	void draw(vec2i size) {
		/+_backend.framebuffer.settings.clearColorEnabled[0] = false;
		_backend.framebuffer.settings.clearDepthEnabled = true;
		_backend.clearBuffers();

		ViewSettings vs;
		vs.eyeCS = CoordSys(vec3fi[0.14, 1.7, 1.9], quat.xRotation(-30.f));
		vs.verticalFOV = 62.f;		// in Degrees; _not_ half of the FOV
		vs.aspectRatio = cast(float)size.x / size.y;
		vs.nearPlaneDistance = 0.1f;
		vs.farPlaneDistance = 100.0f;
		_renderer.render(vs);+/
	}


	void dispose() {
		// TODO
	}


	this (
		RendererBackend backend,
		IKDefRegistry reg,
		SurfaceDef surf,
		IStructureData[] obj
	) {
		this._backend = backend;

		/+_renderer = new MaterialPreviewRenderer(
			backend,
			reg,
			null, null
		);
		
		_renderer.setObjects(obj);

		_renderer.materialToUse = mat.materialKernel;
		assert (_renderer.materialToUse.isValid);

		_renderer.structureToUse = reg.getKernel("DefaultMeshStructure");
		_renderer.compileEffects();

		_renderer.materialParams = mat.params;
		_renderer.updateMaterialData();
		_renderer.materialParams = ParamList.init;+/
	}
	

	RendererBackend			_backend;
	//MaterialPreviewRenderer _renderer;
}
