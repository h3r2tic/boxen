module xf.nucled.ParametersRollout;

private {
	import
		xf.Common;
	import
		xf.nucleus.Param,
		xf.nucleus.Value,
		xf.nucleus.kdef.model.IKDefRegistry,
		xf.nucleus.kdef.Common;
	import
		xf.nucled.DataProvider,
		xf.nucled.Graph : GraphNode;
	import
		xf.hybrid.Hybrid;
	/+import xf.nucleus.model.INucleus;
	import xf.nucleus.model.KernelProvider : KernelRef;
	import xf.nucleus.DataProvider;
	import xf.nucleus.Types;
	import xf.nucleus.CommonDef;
	import +/
}



class ParametersRollout {
	this (IKDefRegistry reg) {
		_reg = reg;
	}
	
	
	void setNode(GraphNode node) {
		_node = node;
	}


	bool changed() {
		return _changed;
	}


	private bool doParamGUI(Param* param, ParamValueInfo* info) {
		if (!param.hasPlainSemantic || !param.hasTypeConstraint) {
			return false;
		}

		// TODO
		/+try {
			normalizedType = normalizeTypeName(param.type);
		} catch (TypeParsingException e) {}+/

		VarDef[] guiAnnots;
		
		if (param.annotation) {
			final annots = *cast(Annotation[]*)param.annotation;
			foreach (annot; annots) {
				if ("gui" == annot.name) {
					guiAnnots = annot.vars;
				}
			}
		}

		cstring provName;
		foreach (v; guiAnnots) {
			if ("widget" == v.name) {
				provName = (cast(IdentifierValue)v.value).value;
				break;
			}
		}

		DataProvider	sourceProvider = info.provider;
		cstring			normalizedType = param.type;

		uword numProviders = 0;
		
		if (sourceProvider is null) {
			foreach (foo, bar; dataProviderRegistry.iterProvidersForType(normalizedType)) {
				++numProviders;
				if (foo == provName || sourceProvider is null) {
					sourceProvider = bar();
				}
			}

			if (0 == numProviders) {
				return false;
			}
		}

		bool fixed = false;
		auto box = HBox() [{
			Label().text = param.type;
			Label().text = param.name;
			
			/+auto check = Check().text("fixed");
			if (!check.initialized) {
				check.checked = sourceProvider !is null;
			}
			fixed = check.checked;+/
			fixed = true;
		}];
		if (!box.initialized) {
			box.icfg(`layout = { spacing = 5; }`);
			box.layoutAttribs = "hexpand hfill";
		}
		
		
		if (fixed) {
			if (numProviders > 1) {
				auto box2 = HBox() [{
					Label().text = "widget: ";
					
					auto pt = Combo();
					if (!pt.initialized) {
						int initTo = -1;
						int numAdded = 0;
						int i; foreach (name, prov_; dataProviderRegistry.iterProvidersForType(normalizedType)) { scope (success) ++i;
							pt.addItem(name);
							++numAdded;
							if (sourceProvider !is null && sourceProvider.name == name) {
								initTo = i;
							}
						}
						
						if (initTo != -1) {
							pt.selectedIdx = initTo;
						} else if (1 == numAdded) {
							pt.selectedIdx = 0;
						}
					}
					
					char[] providerName = pt.selected;
					if (sourceProvider is null || sourceProvider.name != providerName) {
						foreach (name, prov; dataProviderRegistry.iterProvidersForType(normalizedType)) {
							if (name == providerName) {
								sourceProvider = prov();
								break;
							}
						}
					}

					assert (sourceProvider is null || sourceProvider.name == providerName);
				}];

				if (!box2.initialized) {
					box2.layoutAttribs = "hexpand hfill";
				}
			}
			
			if (sourceProvider !is null) {
				if (sourceProvider !is info.provider) {
					sourceProvider.configure(guiAnnots);
					info.provider = sourceProvider;
					if (param.value) {
						info.provider.setValue(param);
					}
				}
				
				sourceProvider.doGUI();
				if (sourceProvider.changed || info.provider !is sourceProvider) {
					updateParamValue(param, sourceProvider);
					_changed = true;
				}
			} else {
				info.provider = null;
			}
		}

		return true;
	}


	private void updateParamValue(Param* param, DataProvider prov) {
		switch (param.type) {
			case "float":
				param.setValue(prov.getValue().get!(float));
				break;
			case "float2":
				param.setValue(prov.getValue().get!(vec2).tuple);
				break;
			case "float3":
				param.setValue(prov.getValue().get!(vec3).tuple);
				break;
			case "float4":
				param.setValue(prov.getValue().get!(vec4).tuple);
				break;
			case "sampler2D":
				param.setValue(prov.getValue().get!(Object));
				break;
			default:
				assert (false, param.type);
		}
	}
	
	
	void doGUI() {
		_changed = false;

		if (_node !is null) {
			Group(`parametersRollout`) [{
				uword i; foreach (ref param, ref valInfo; &iterParams) { scope (success) ++i;
					bool show = false;
				
					auto box = VBox(i) [{
						show = doParamGUI(&param, &valInfo);
					}];
					
					box.widgetEnabled = show;
					
					if (!box.initialized) {
						box.icfg(`layout = { padding = 5 5; spacing = 5; } style.normal = { border = 1 rgba(1, 1, 1, .15); background = solid(rgba(0, 0, 0, 0.1)); }`);
						box.layoutAttribs = "hexpand hfill";
					}
				}
			}];
		}
	}


	private {
		int iterParams(int delegate(ref Param, ref ParamValueInfo) dg) {
			if (_node.isKernelBased) {
				/+auto kr = KernelRef(_node.kernelName, _nucleus);
				if (auto kernel = kr.tryGetKernel) {
					if (auto fun = kernel.getFunction(_node.funcName)) {
						foreach (ref p; &fun.iterParams) {
							if (p.isInput) {
								if (auto r = dg(p)) {
									return r;
								}
							}
						}
					}
				}+/
			} else {
				if (_node.data) {
					foreach (pi, ref p; _node.data.params) {
						if (p.isOutput) {
							if (auto r = dg(p, _node.paramValueInfo[pi])) {
								return r;
							}
						}
					}
				}
			}
			
			return 0;
		}
	}
	
	
	private {
		IKDefRegistry	_reg;
		GraphNode		_node;
		bool			_changed = false;
	}
}
