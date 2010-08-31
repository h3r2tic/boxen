module xf.nucled.DataProvider;

private {
	import
		xf.Common;
	import
		xf.nucleus.Value,
		xf.nucleus.Param,
		xf.nucleus.kdef.Common;
	import
		tango.core.Variant,
		tango.io.stream.Format;
	static import
		xf.utils.Array;
}



struct ParamValueInfo {
	DataProvider provider;
}


template MDataProvider(cstring _type, cstring _name) {
	private import xf.Common;

	static this() {
		dataProviderRegistry.register(_type, _name, function DataProvider() {
			return new typeof(this);
		});
	}
	
	override cstring name() {
		return _name;
	}
	
	override cstring type() {
		return _type;
	}
}



struct dataProviderRegistry {
static:
	void register(cstring type, cstring name, DataProvider function() prov) {
		_providers[type][name] = prov;
	}
	
	ProviderIter iterProvidersForType(cstring type) {
		return ProviderIter(type);
	}
	
	struct ProviderIter {
		cstring type;
		
		int opApply(int delegate(ref cstring, ref DataProvider function()) dg) {
			if (auto foo = type in _providers) {
				foreach (n, p; *foo) {
					if (auto r = dg(n, p)) {
						return r;
					}
				}
			}
			return 0;
		}
	}
	
	
	private {
		DataProvider function()[cstring][cstring] _providers;
	}
}


abstract class DataProvider {
	abstract Variant	getValue();
	abstract void		setValue(Param*);
	abstract void		configure(VarDef[]);
	abstract void		dumpConfig(FormatOutput!(char));
	abstract cstring	name();
	abstract cstring	type();
	
	// to be used by an implementation, mostly
	void invalidate() {
		_changed = true;
	}

	bool changed() {
		return _changed;
	}

	final void doGUI() {
		_changed = false;
		_doGUI();
	}

	protected {
		bool _changed = true;
		abstract void _doGUI();
	}
}
