module xf.nucled.ParametersRollout;

private {
	/+import xf.nucleus.model.INucleus;
	import xf.nucleus.model.KernelProvider : KernelRef;
	import xf.nucleus.DataProvider;
	import xf.nucleus.Types;
	import xf.nucleus.CommonDef;
	import xf.nucled.Graph : GraphNode;+/
	import xf.hybrid.Hybrid;
}



class ParametersRollout {
	/+this (INucleus nucleus) {
		_nucleus = nucleus;
	}
	
	
	void setNode(GraphNode node) {
		_node = node;
	}+/
	
	
	void doGUI() {
		//if (_node !is null) {
			Group(`parametersRollout`) [{/+
				int i; foreach (param; &iterParams) { scope (success) ++i;
					auto box = VBox(i) [{
						char[]	normalizedType = param.type;
						
						try {
							normalizedType = normalizeTypeName(param.type);
						} catch (TypeParsingException e) {}
						
						
						GraphNode			sourceDataNode;
						char[]					sourceOutput;
						DataProviderRef*	sourceProvider;
						if (auto con = _node.hasConnectionToInput(param.name, &sourceOutput)) {
							if (GraphNode.Type.Data == con.from.type) {
								sourceDataNode = con.from;
								if (auto pparam = con.from.data.getParam(sourceOutput)) {
									sourceProvider = pparam.dataProvider;
								}
							}
						}
						
						if (sourceProvider is null) {
							return;
						}						
						
						bool hasProviders = false;
						foreach (foo, bar; dataProviderRegistry.iterProvidersForType(normalizedType)) {
							hasProviders = true;
							break;
						}
						
						
						bool fixed = false;
						auto box = HBox() [{
							Label().text = param.type;
							Label().text = param.name;
							
							if (hasProviders) {
								auto check = Check().text("fixed");
								if (!check.initialized) {
									check.checked = sourceProvider !is null;
								}
								fixed = check.checked;
							}
						}];
						if (!box.initialized) {
							box.cfg(`layout = { spacing = 5; }`);
							box.layoutAttribs = "hexpand hfill";
						}
						
						
						if (fixed) {
							auto box2 = HBox() [{
								Label().text = "provider: ";
								
								auto pt = Combo();
								if (!pt.initialized) {
									int initTo = -1;
									int numAdded = 0;
									int i; foreach (name, prov_; dataProviderRegistry.iterProvidersForType(normalizedType)) { scope (success) ++i;
										pt.addItem(name);
										++numAdded;
										if (sourceProvider.get !is null && sourceProvider.get.name == name) {
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
								if (sourceProvider.get is null || sourceProvider.get.name != providerName) {
									foreach (name, prov; dataProviderRegistry.iterProvidersForType(normalizedType)) {
										if (name == providerName) {
											*sourceProvider = prov();
											break;
										}
									}
								}

								assert (sourceProvider.get is null || sourceProvider.get.name == providerName);
							}];
							if (!box2.initialized) {
								box2.layoutAttribs = "hexpand hfill";
							}

							if (sourceProvider.get !is null) {
								sourceProvider.get.doGUI();
							}
						}
					}];
					
					if (!box.initialized) {
						box.cfg(`layout = { padding = 5 5; spacing = 5; } style.normal = { border = 1 rgba(1, 1, 1, .15); background = solid(rgba(0, 0, 0, 0.1)); }`);
						box.layoutAttribs = "hexpand hfill";
					}
				}+/
			}];
		//}
	}


	/+private {
		int iterParams(int delegate(ref Param) dg) {
			if (_node.isKernelBased) {
				auto kr = KernelRef(_node.kernelName, _nucleus);
				if (auto kernel = kr.tryGetKernel) {
					if (auto fun = kernel.getFunction(_node.funcName)) {
						foreach (p; &fun.iterParams) {
							if (p.isInput) {
								if (auto r = dg(p)) {
									return r;
								}
							}
						}
					}
				}
			} else {
				if (_node.data) {
					foreach (p; &_node.data.iterParams) {
						if (p.isInput) {
							if (auto r = dg(p)) {
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
		INucleus		_nucleus;
		GraphNode	_node;
	}+/
}
