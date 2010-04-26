module xf.hybrid.widgets.TreeView;

private {
	import xf.hybrid.Common;
	import xf.hybrid.widgets.HBox;
	import xf.hybrid.widgets.VBox;
	import xf.hybrid.widgets.Check;
	import tango.core.Traits : isStaticArrayType;
}




template Unstatic(T) {
	static if (isStaticArrayType!(T)) {
		alias typeof(T.init)[] Unstatic;
	} else {
		alias T Unstatic;
	}
}


struct TreeContextSettings {
	void delegate()					dg;
	TypeInfo							dgParamType;
	IWidget delegate(int, int)	parentOverride;
	int									numLines;
}


struct TreeContextCache {
	struct TreeCacheKey {
		size_t	foo, bar;
	}
	
	void[][TreeCacheKey]	cacheData;
	TreeContextCache[]		children;
	bool								hasChildren = false;
	
	T cache(T)(size_t k0, size_t k1, T val) {
		auto key = TreeCacheKey(k0, k1);
		
		if (auto x = key in cacheData) {
			return *cast(T*)(*x).ptr;
		} else {
			T foo = val;
			cacheData[key] = cast(void[])([ foo ].dup);
			return foo;
		}
	}
	
	TreeContextCache* child(int i) {
		if (i < children.length) {
			return &children[i];
		} else {
			assert (i == children.length);
			children ~= TreeContextCache(null, null);
			return &children[$-1];
		}
	}
}


class TreeContext {
	void recurse(T_)(T_ key_) {
		assert (settings !is null);
		
		++recCnt;

		alias Unstatic!(T_) T;
		T key = key_;
		
		if (!open) return;
		assert (typeid(T) is settings.dgParamType);
		
		auto prevOverride = gui.parentOverride;
		gui.parentOverride = {
			return settings.parentOverride(settings.numLines, 0);
		};
		scope (exit) {
			gui.parentOverride = prevOverride;
		}
		
		HBox(recCnt) [{
			scope ctx = new TreeContext;
			ctx.settings = this.settings;
			ctx.cacheNode = cacheNode.child(recCnt);
			ctx.open = false;
			ctx.depth = this.depth + 1;
			
			Dummy().userSize = vec2(depth * 20, 0);
			Check chk;
			if (ctx.cacheNode.hasChildren) {
				ctx.open = (chk = Check()).checked;
			}
			
			auto hbox = HBox();
			int widgetIdx = 0;
			gui.parentOverride = {
				if (0 == widgetIdx++) {
					return cast(IWidget)hbox;
				} else {
					return settings.parentOverride(settings.numLines, widgetIdx-1);
				}
			};
			(cast(void delegate(T key, TreeContext))settings.dg)(key, ctx);
			
			ctx.cacheNode.hasChildren = (ctx.recCnt != -1);
			
			if (chk && !chk.initialized) {
				hbox.addHandler(&chk.handleClick);
				hbox.addHandler(&chk.handleMouseEnter);
				hbox.addHandler(&chk.handleMouseLeave);
			}
		}];
		
		++settings.numLines;
	}
	
	T opIndex(T)(lazy T val) {
		size_t retAddr = void;
		size_t curAddr = void;
		asm {
			mov EDX, ESP; mov ESP, EBP; pop EBP; pop EAX;
			push EAX; push EBP; mov EBP, ESP; mov ESP, EDX;
			mov retAddr, EAX;
			
			call GIMMEH_EIP;
			GIMMEH_EIP: pop EDX; mov curAddr, EDX;
		}

		return cacheNode.cache(retAddr, curAddr, val);
	}
	
	TreeContextSettings*	settings;
	TreeContextCache*	cacheNode;
	bool							open;
	int							depth;
	int							recCnt = -1;
}


class TreeView : Widget {
	void doGUI(T_, U)(IWidget delegate(int, int) parentOverride, T_ root_, void delegate(U key, TreeContext) dg) {
		alias Unstatic!(T_) T;
		static assert (is(U == T));
		T root = root_;
		
		settings = TreeContextSettings(
			cast(void delegate())dg,
			typeid(T),
			//(int idx) { return cast(IWidget)(0 == idx ? vbox0 : vbox1); }
			parentOverride
		);
		
		scope ctx = new TreeContext;
		ctx.settings = &settings;
		ctx.cacheNode = &cacheNode;
		ctx.open = true;

		ctx.recurse(root);
	}
	
	TreeContext				context;
	TreeContextSettings	settings;
	TreeContextCache		cacheNode;
	
	mixin MWidget;
}
