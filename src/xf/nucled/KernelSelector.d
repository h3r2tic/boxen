module xf.nucled.KernelSelector;

private {
	import xf.hybrid.Hybrid;
	import xf.hybrid.Common;
	import xf.hybrid.CustomWidget;
	//import xf.hybrid.backend.GL;
	//import xf.dog.Dog;
	
	//import xf.nucleus.CommonDef;
	import xf.nucleus.KernelImpl;
	
	import tango.io.Stdout;		// TMP
}



class KernelSelector : CustomWidget {
	/+EventHandling clickHandler(ClickEvent e) {
		return e.bubbling && !e.handled ? EventHandling.Stop : EventHandling.Continue;
	}
	
	this () {
		addHandler(&clickHandler);
	}+/
	
	mixin MWidget;
}


class KernelBox : CustomWidget {
	mixin(defineProperties("out bool clicked"));
	mixin MWidget;
}


class KernelBoxContainer : CustomWidget {
	mixin MWidget;
}



class KernelSelectorPopup {
	alias KernelImpl MRUItem;

	int delegate(int delegate(ref KernelImpl)) kernels;
	
	MRUItem[] mru;
	const int mruLen = 4;
	
	
	void mruAdd(MRUItem kf) {
		foreach (i, m; mru) {
			if (m == kf) {
				mru = [kf] ~ mru[0..i] ~ mru[i+1..$];
				return;
			}
		}
		
		mru = [kf] ~ mru;
		if (mru.length > mruLen) {
			mru = mru[0..mruLen];
		}
	}
	
	
	bool doGUI(bool delegate(KernelImpl) kernelFilter, out KernelImpl pickedKernel) {
		auto ksel = KernelSelector();
		ksel.layoutAttribs = "vexpand vfill hexpand hfill";
		
		ksel [{
			auto hostTabs = TabView();
			hostTabs.label[0] = "all";
			/+hostTabs.label[1] = "cpu";
			hostTabs.label[2] = "gpu";+/
			
			hostTabs [{
				KernelBoxContainer() [{
					final filter = kernelFilter;
					
					/+switch (hostTabs.activeTab) {
						case 0: {
							filter = (KernelImpl kd) { return kernelFilter(kd); };
						} break;

						case 1: {
							filter = (KernelImpl kd) { return kernelFilter(kd) };
						} break;

						case 2: {
							filter = (KernelImpl kd) { return kernelFilter(kd) && kd.domain == Domain.GPU; };
						} break;
					}+/

					int i = 0;
					foreach (k; kernels) {
						if (filter(k)) {
							MRUItem mi = k;
							if (doKernel(i, k)) {
								pickedKernel = k;
								mruAdd(mi);
							}
						}
						++i;
					}
				}].layoutAttribs = "hexpand hfill vexpand vfill";
			}].layoutAttribs = "hexpand hfill vexpand vfill";
		}];
		
		if (pickedKernel is pickedKernel.init) {
			ksel.open(`mru`);
			foreach (i, kf; mru) {
				if (doKernel(i, kf)) {
					pickedKernel = kf;
					mruAdd(kf);
				}
			}
			gui.close;
		}
		
		return pickedKernel !is pickedKernel.init;
	}
	
	
	bool doKernel(int id, KernelImpl kf) {
		auto kb = KernelBox(id);
		kb [{
			const int fontSize = 10;
			Label().fontSize(fontSize).text = kf.name;
		}];
		
		return kb.clicked;
	}
}
